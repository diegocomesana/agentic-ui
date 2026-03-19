# AgentScheduler — Serialización de Invocaciones del Agente

## Problema

Cuando el usuario envía mensajes rápidamente o realiza acciones mecánicas mientras el agente está procesando, se producen condiciones de carrera:

1. El segundo mensaje lanza un `Task.async` con un **snapshot stale** del store
2. El primer agente termina y aplica su resultado al store
3. El segundo agente termina con un resultado basado en estado desactualizado
4. Resultados se sobreescriben entre sí — operaciones se pierden

## Solución: AgentScheduler (State Machine Puro)

`AgentScheduler` es una state machine pura (sin side effects) que garantiza:

- **Como máximo un agente corre a la vez**
- **Si el estado cambia durante la ejecución, el resultado stale se descarta**
- **Se re-invoca automáticamente con estado fresco**

### Estados y Transiciones

```
:idle + request_invocation    → :busy    → {:invoke, scheduler}
:busy + request_invocation    → :busy    → {:queued, scheduler}   (dirty=true)
:busy + notify_state_changed  → :busy    → scheduler              (dirty=true)
:busy + task_completed        → depende:
  dirty=true  → :busy  → {:reinvoke, scheduler}   (descarta resultado, re-invoca)
  dirty=false → :idle  → {:idle, scheduler}        (aplica resultado)
reset                         → :idle    → scheduler
```

### Diagrama de Flujo

```
Usuario envía msg1          Usuario envía msg2 (300ms después)
       │                              │
       ▼                              ▼
  request_invocation()         request_invocation()
  → {:invoke, sched}           → {:queued, sched}
       │                         (dirty = true)
       ▼
  Task.async(Agent.invoke)
       │
       ▼
  Agent completa msg1
       │
       ▼
  task_completed()
  dirty=true → {:reinvoke, sched}
       │
       ▼  ← DESCARTA resultado stale
  Task.async(Agent.invoke)   ← re-invoca con store FRESCO
       │                       (tiene msg1 + msg2 en conversation)
       ▼
  Agent completa
       │
       ▼
  task_completed()
  dirty=false → {:idle, sched}
       │
       ▼  ← APLICA resultado al store
```

### API Pública

```elixir
AgentScheduler.new()                    # → %AgentScheduler{status: :idle, dirty: false}
AgentScheduler.request_invocation(s)    # → {:invoke, s} | {:queued, s}
AgentScheduler.notify_state_changed(s)  # → s (con dirty=true si busy)
AgentScheduler.task_completed(s)        # → {:reinvoke, s} | {:idle, s}
AgentScheduler.reset(s)                 # → %AgentScheduler{status: :idle, dirty: false}
AgentScheduler.busy?(s)                 # → boolean
```

## Integración en WorkspaceLive

### Mount
```elixir
assign(socket, scheduler: AgentScheduler.new())
```

### send_message / semantic events
```elixir
case AgentScheduler.request_invocation(socket.assigns.scheduler) do
  {:invoke, scheduler} ->
    # Lanzar Task.async con Agent.invoke
  {:queued, scheduler} ->
    # Solo actualizar store (mensaje ya está en conversation)
    # El agente lo procesará en la re-invocación
end
```

### Eventos mecánicos (pagination, close, etc.)
```elixir
scheduler = AgentScheduler.notify_state_changed(socket.assigns.scheduler)
# → marca dirty si hay agente corriendo
```

### Agent completa (handle_info)
```elixir
case AgentScheduler.task_completed(socket.assigns.scheduler) do
  {:reinvoke, scheduler} ->
    # DESCARTAR resultado → re-invocar con store fresco
  {:idle, scheduler} ->
    # Aplicar resultado normalmente
end
```

## Verificación en Logs

Cuando el scheduler interviene, aparecen estos logs:

```
[SCHEDULER] queued: message while agent busy      ← msg encolado
[SCHEDULER] discarding stale result, re-invoking   ← resultado descartado
```

## Tests

- **18 tests unitarios** en `test/agentic_ui/agent_scheduler_test.exs`
- Cubren todas las transiciones y escenarios completos:
  - Ciclo simple: idle → invoke → complete → idle
  - Mensaje durante busy: invoke → queued → reinvoke → complete
  - Evento mecánico durante busy: state_changed → reinvoke
  - Múltiples eventos colapsados en un solo reinvoke
  - Cadena de reinvokes (dirty durante reinvocación)

## Archivos

| Archivo | Cambio |
|---------|--------|
| `lib/agentic_ui/agent_scheduler.ex` | **NUEVO** — state machine pura |
| `test/agentic_ui/agent_scheduler_test.exs` | **NUEVO** — 18 tests unitarios |
| `lib/agentic_ui_web/live/workspace_live.ex` | Reemplazado `thinking`/`block_chat_on_thinking` por `scheduler` |
| `lib/agentic_ui_web/components/widgets/chat.ex` | Removido `block_on_thinking`, botón siempre habilitado |
| `config/runtime.exs` | Removido config `block_chat_on_thinking` |
