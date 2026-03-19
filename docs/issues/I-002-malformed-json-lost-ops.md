# I-002: JSON malformado del agente pierde operaciones en parsing

**Severidad:** High
**Estado:** Open
**Detectado:** 2026-02-24
**Archivo principal:** `lib/agentic_ui/agent/agent.ex`

## Descripcion

El agente (OpenAI gpt-4.1-mini) a veces retorna JSON concatenado o malformado en vez de un unico objeto JSON valido. El parser de recuperacion (`extract_best_json`) intenta mergear multiples objetos JSON, pero en el proceso puede perder operaciones de widgets (add_to_cart, add, update, etc.).

## Causa raiz

En `agent.ex:197-243`, cuando `Jason.decode` falla en el response, se invoca `extract_best_json/1` que:

1. Split la string en objetos JSON individuales via `split_json_objects/1` (tracking de depth de braces)
2. Parsea cada objeto independientemente
3. Mergea los resultados: widgets de todos los objetos, message del mas largo, layout del ultimo

```elixir
all_widgets = Enum.flat_map(objects, fn obj -> obj["widgets"] || [] end)
all_actions = Enum.flat_map(objects, fn obj -> obj["actions"] || [] end)
```

El problema: si el agente emite la respuesta como dos objetos JSON concatenados donde:
- Objeto 1: `{"message": "He agregado...", "widgets": []}` (mensaje sin ops)
- Objeto 2: `{"message": "", "layout": {...}}` (layout sin ops)

El merge resulta en `0 total ops` — las operaciones de cart que el agente "penso" que estaba emitiendo se pierden.

## Evidencia del log

Ocurre repetidamente en la sesion del 2026-02-24:

```
[AGENT] extract_best_json: merging 2 JSON objects
[AGENT] extract_best_json: merged result has 0 total ops    ← operaciones perdidas
[AGENT] recovered JSON from concatenated response
[STATE] agent responded: message=He agregado 3 huevos... widgets=0  ← dice que agrego pero 0 ops
```

El agente ejecuto `get_product_detail` para product 23 (eggs) exitosamente, pero su respuesta final no incluyo la operacion `add_to_cart` en ningun objeto JSON parseable.

## Relacion con I-001

Este bug se potencia con la race condition (I-001):
- La race condition genera contextos confusos para el agente (mensajes superpuestos, estado inconsistente)
- Contextos confusos producen respuestas JSON mas propensas a ser malformadas
- El parser pierde las operaciones, completando el ciclo de falla

Resolver I-001 (serializar invocaciones) deberia reducir la frecuencia de este bug al darle al agente contextos mas limpios. Pero el bug puede ocurrir independientemente.

## Escenarios donde se pierde informacion

1. **Widgets en key no reconocido:** El agente pone operaciones bajo un key distinto a `"widgets"` o `"actions"`
2. **Ops dentro del message:** El agente describe la operacion en el message text pero no en el array de widgets
3. **JSON split incorrecto:** La operacion queda partida entre dos objetos JSON (ej: el `{` de un widget op se interpreta como inicio de nuevo objeto top-level)
4. **Objetos vacios:** Ambos objetos tienen `"widgets": []` o no tienen el key

## Impacto

- add_to_cart se pierde silenciosamente — el agente dice "He agregado X" pero el cart no cambia
- El usuario ve el mensaje de confirmacion pero el widget no refleja el cambio
- Perdida de confianza del usuario en el agente

## Posibles soluciones

### Opcion A: Mejorar el parsing de recuperacion
- Loguear el raw content cuando `total ops == 0` y el message menciona "agregado/added/removed"
- Detectar discrepancia entre message y ops (heuristica)
- Intentar re-parsear con regex mas agresivo para extraer ops

### Opcion B: Retry con contexto de error
- Cuando `merged result has 0 total ops` pero el message indica acciones, reenviar al agente con un prompt de correccion que incluya el JSON malformado y pida solo las operaciones

### Opcion C: Validacion post-parsing
- Despues de parsear, analizar el message text para detectar intenciones no reflejadas en ops
- Si el message dice "agregado al carrito" pero widgets no tiene add_to_cart, loguear warning

### Opcion D: Prompt engineering
- Reforzar en el system prompt que TODAS las operaciones deben estar en el array `widgets`
- Agregar ejemplos de respuestas correctas con add_to_cart
- Penalizar en el prompt las respuestas que confirman acciones sin emitir operaciones

## Archivos afectados

- `lib/agentic_ui/agent/agent.ex` — `extract_best_json/1`, `validate_response/2`
- `lib/agentic_ui/agent/prompts/system_prompt.eex` — si se opta por prompt engineering
