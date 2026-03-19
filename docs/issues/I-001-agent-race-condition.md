# I-001: Race condition en invocaciones paralelas del agente

**Severidad:** Critical
**Estado:** Open
**Detectado:** 2026-02-24
**Archivo principal:** `lib/agentic_ui_web/live/workspace_live.ex`

## Descripcion

Cuando el usuario envia multiples mensajes rapido (antes de que el agente responda al primero), se lanzan multiples `Task.async` en paralelo. Cada task captura un snapshot del store al momento del envio, por lo que los agentes posteriores trabajan con state desactualizado. Los resultados llegan en orden arbitrario y se sobreescriben mutuamente.

## Causa raiz

En `workspace_live.ex:254-278`, `handle_event("send_message")` no serializa las invocaciones al agente:

```elixir
# Cada mensaje crea un Task.async independiente
store = socket.assigns.store
{:invoke_agent, context, store} = Engine.process_chat(message, store)
task = Task.async(fn -> AgenticUi.Agent.invoke(context) end)
{:noreply, assign(socket, :agent_task, task)}
```

- `block_chat_on_thinking` es `false` por defecto, asi que mensajes nuevos no se bloquean
- Cada `Task.async` recibe el `context` del momento del envio (snapshot stale)
- `handle_info({ref, {:ok, result}}, socket)` matchea ANY reference, asi que todos los tasks se procesan
- El assign `:agent_task` se sobreescribe pero el task anterior sigue corriendo

## Evidencia del log (2026-02-24 12:35)

Conversacion: usuario agrega items al carrito secuencialmente.

```
12:35:04  "3 huevos"  → Agent A arranca (cart=[Beef x2])
12:35:08  "un limon"  → Agent B arranca (cart=[Beef x2]) ← MISMO state stale
12:35:15  Agent A termina → widgets=0, cart sigue [Beef x2]
12:35:17  "mostrame el cart arriba" → Agent C arranca
12:35:18  Agent B termina → cart sigue [Beef x2]
12:35:20  Agent C termina → cart sigue [Beef x2]
```

Tres agentes corrieron en paralelo. Ninguno logro agregar huevos ni limon al cart. Los DB saves muestran consistentemente `cart=[Beef x2]` a traves de todas las ejecuciones.

Cuando el usuario reclamó, el agente finalmente agrego eggs con `qty=6` en vez de `qty=3` (doble, por intentos acumulados).

## Impacto

- Operaciones de cart se pierden silenciosamente
- El agente dice "He agregado X" pero no se refleja en el state
- Duplicacion de items cuando se reintentan las operaciones
- Estado inconsistente entre lo que el agente "cree" y lo que realmente esta en el store

## Solucion propuesta

Serializar invocaciones del agente sin bloquear la UI:

1. Aceptar mensajes del usuario siempre (se agregan al store y chat inmediatamente)
2. Si el agente esta corriendo (`thinking=true`), marcar `pending_agent_call=true` en vez de lanzar un nuevo Task
3. Cuando el agente termina, si hay pending: re-invocar con el store ACTUAL (que ya tiene todos los mensajes del usuario y los cambios del agente anterior)
4. Multiples mensajes pendientes se coalescen en una sola invocacion — el agente los ve todos en la conversacion

Esto elimina la race condition porque:
- Solo un agente corre a la vez
- Cada agente siempre ve el state mas reciente
- Los mensajes del usuario nunca se pierden ni se bloquean

## Archivos afectados

- `lib/agentic_ui_web/live/workspace_live.ex` — logica principal de serializacion
- `lib/agentic_ui_web/components/widgets/chat.ex` — remover `block_on_thinking`
- `config/runtime.exs` — remover config `block_chat_on_thinking`
