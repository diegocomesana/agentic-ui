# E2E Test Suite — Agentic UI Framework

Suite de tests end-to-end para ejecutar con Playwright MCP.
Cada test tiene un ID estable para trackear resultados entre sesiones.

---

## Pre-requisitos

1. Server corriendo en `http://localhost:4000`
2. Playwright MCP activo (`claude mcp list` debe listarlo)

---

## T1 — Smoke: Layout y Chat

### T1.1 Layout inicial
- Navegar a `http://localhost:4000`
- Verificar header con "Agentic UI" y "Agent online"
- Verificar layout split: area de widgets (derecha) + chat panel (izquierda, 380px)
- Area de widgets muestra estado vacio con emoji y texto "Welcome to Agentic UI"
- Input de chat presente con placeholder

### T1.2 Enviar mensaje basico
- Escribir "hola" en el chat y enviar
- Verificar que el mensaje del usuario aparece en el chat
- Verificar animacion "Thinking..." (loading bar superior)
- Esperar respuesta del agente
- Verificar que la respuesta del asistente aparece en el chat

---

## T2 — Widgets via Agente

### T2.1 product_grid
- Enviar "mostrame teclados mecanicos"
- Verificar que aparece un product_grid con titulo "Products (keyboards)"
- Verificar que las cards muestran: imagen, nombre, precio ($), rating
- Verificar indicador de pagina (ej: "1/2")
- Verificar boton de close (X) presente

### T2.2 product_detail (via click en grid)
- Con un product_grid visible, click en cualquier producto
- Verificar que aparece product_detail debajo
- Verificar que muestra: imagen, nombre, precio, descripcion, specs
- Verificar boton de close (X) presente

### T2.3 product_detail (via agente)
- Enviar "mostrame el detalle del Keychron K8 Pro"
- Verificar que aparece product_detail con los datos correctos

### T2.4 comparator
- Enviar "compara el Keychron K8 Pro con el NuPhy Air75 V2"
- Verificar que aparece tabla comparativa
- Verificar columnas por producto con: imagen, nombre, precio, rating, specs
- Verificar boton de close (X) presente

### T2.5 hero_banner
- Enviar "pone un banner de bienvenida"
- Verificar que aparece hero_banner con titulo, subtitulo, gradiente
- Verificar boton de close (X) presente

### T2.6 category_browser
- Enviar "mostrame las categorias"
- Verificar que aparece category_browser con cards por categoria
- Verificar iconos y nombres de categorias (keyboards, mice, monitors, headphones, chargers, storage)

---

## T3 — Eventos Mecanicos

### T3.1 Paginacion
- Con un product_grid visible, click en boton "Next" (triangulo derecho)
- Verificar que cambia de pagina SIN "Thinking..." (instantaneo)
- Verificar que indicador de pagina se actualiza
- Click en "Prev" (triangulo izquierdo) para volver

### T3.2 Cambio de categoria (dropdown)
- Con un product_grid visible, cambiar el dropdown de categoria
- Verificar que los productos cambian instantaneamente (sin agente)

### T3.3 Cambio de per_page
- Con un product_grid visible, cambiar el dropdown "Show" (3/6/9/12)
- Verificar que la cantidad de cards cambia instantaneamente

### T3.4 Close widget (mecanico)
- Con un product_detail visible, click en X
- Verificar que desaparece instantaneamente (sin "Thinking...")

### T3.5 Select product desde grid
- Con un product_grid visible, click en un producto
- Verificar que aparece product_detail instantaneamente (sin agente)

### T3.6 Select categoria desde category_browser
- Con un category_browser visible, click en una categoria
- Verificar que aparece product_grid para esa categoria instantaneamente

---

## T4 — Clear y Remove

### T4.1 Clear all
- Tener 2+ widgets visibles
- Enviar "limpia todo"
- Verificar que TODOS los widgets desaparecen
- Verificar que vuelve al estado vacio con emoji

### T4.2 Remove individual
- Tener 2+ widgets visibles
- Enviar "saca el grid" (o similar para un widget especifico)
- Verificar que solo ese widget desaparece, los demas permanecen

### T4.3 Clear all EXCEPT (preservar widget especifico)
- Tener 3+ widgets visibles (ej: product_grid + hero_banner + comparator)
- Enviar "borra todo menos el grid" (o "clear everything except the grid")
- Verificar que el grid PERMANECE visible
- Verificar que los otros widgets desaparecen
- Verificar que el agente NO uso "clear_all" (el grid no debe desaparecer y reaparecer)

### T4.4 Re-creacion de widget usa config original (category slug)
- Enviar "mostrame laptops" → verificar que aparece grid con productos
- Enviar "borra todo"
- Enviar "mostrame las computadoras de nuevo"
- Verificar que el grid aparece con productos (NO vacio)
- Verificar en logs que `category` es `"laptops"` (slug en ingles, no "computadoras")

---

## T5 — Pinning

### T5.1 Widget pineado no tiene boton close
- Configurar un default widget con `pinned: true` en `default_state.ex`
- Recompilar y recargar
- Verificar que el widget pineado muestra icono de pin en vez de X

### T5.2 Clear all preserva pineados
- Tener widgets pineados + no pineados visibles
- Enviar "limpia todo"
- Verificar que los pineados sobreviven
- Verificar que los no pineados desaparecen

### T5.3 Remove de widget pineado (agente)
- Enviar "saca el [widget pineado]"
- Verificar que el widget pineado NO se remueve
- Verificar que el agente responde (no se rompe)

### T5.4 Close mecanico bloqueado en pineado
- Si un widget pineado tuviera boton X (edge case), click no lo remueve

---

## T6 — Default State

### T6.1 Widgets default aparecen al cargar
- Configurar `@default_widgets` en `default_state.ex` con al menos 1 widget
- Recompilar y navegar a `http://localhost:4000`
- Verificar que los widgets default aparecen con datos resueltos
- Verificar que el chat esta vacio (no hay mensajes previos)

### T6.2 Default state vacio (backward compatible)
- Configurar `@default_widgets []` en `default_state.ex`
- Recompilar y navegar a `http://localhost:4000`
- Verificar que aparece el estado vacio con emoji (comportamiento original)

### T6.3 Interaccion normal despues de defaults
- Con widgets default cargados, enviar un mensaje al agente
- Verificar que el agente puede agregar nuevos widgets junto a los defaults
- Verificar que la interaccion funciona normalmente

---

## T7 — Layout

### T7.1 Layout vertical (default)
- Pedir 2 widgets al agente
- Verificar que se apilan verticalmente

### T7.2 Layout horizontal
- Enviar "mostrame dos productos lado a lado"
- Verificar que los widgets se muestran en fila horizontal

---

## T8 — UI General

### T8.1 Theme toggle
- Click en el icono de tema en el header
- Verificar que cicla entre light / dark / system

### T8.2 Debug panel
- Click en el icono de debug (tag) en el header
- Verificar que aparece panel con JSON del estado actual
- Verificar que muestra: model, widgets count, messages count

---

## T9 — Filtros (Reducers: Config)

Estos tests validan que los filtros usan el sistema pluggable de reducers (Config module)
en vez de codigo hardcodeado en engine.ex. Todos son mecanicos (instantaneos).

### T9.1 Toggle filtros (product_grid)
- Con un product_grid visible, click en el boton de filtros (icono "tune")
- Verificar que el panel de filtros se abre (inputs de precio, rating, sort visibles)
- Click de nuevo en el boton de filtros
- Verificar que el panel se cierra

### T9.2 Apply filtros
- Con un product_grid y panel de filtros abierto:
  - Cambiar min_price a 50
  - Cambiar sort_by a "price"
  - Click en "Apply"
- Verificar que los productos cambian instantaneamente (sin "Thinking...")
- Verificar que la pagina se resetea a 1

### T9.3 Reset filtros
- Con filtros aplicados en T9.2, click en "Reset"
- Verificar que los valores vuelven a defaults (min_price=0, max_price=10000, sort_by=rating)
- Verificar que los productos se recargan instantaneamente

### T9.4 Update filter preview (range slider)
- Con panel de filtros abierto, mover el slider de rating
- Verificar que el valor del slider se actualiza en la UI
- Verificar que NO se refetchean los productos (solo preview visual)

### T9.5 Filtros en carousel
- Pedir al agente un carousel, abrir filtros, aplicar, resetear
- Verificar mismo comportamiento que grid (T9.1-T9.3)

---

## T10 — Search Bar: Guard + Semantic Condition

### T10.1 Guard: query vacio
- Con un search_bar visible, click en el boton de buscar sin escribir nada
- Verificar que NO pasa nada (guard bloquea el evento)
- No debe aparecer "Thinking..." ni un grid nuevo

### T10.2 Busqueda directa (mechanical spawn)
- Con search_bar en modo directo (icono grid_view)
- Escribir "keyboards" y enviar
- Verificar que aparece un product_grid con id "grid-search" instantaneamente
- Verificar que muestra productos filtrados por "keyboards"
- Verificar que NO hay "Thinking..." (es mecanico, no pasa por agente)

### T10.3 Toggle mode
- Con search_bar visible, click en el boton de toggle mode (icono grid/chat)
- Verificar que el icono cambia (grid_view ↔ chat)
- Verificar que es instantaneo (sin agente)

### T10.4 Busqueda semantica (agent mode)
- Con search_bar en modo agente (icono chat, agent_mode=true):
- Escribir "what are the best keyboards?" y enviar
- Verificar que aparece "Thinking..." (se rutea al agente)
- Verificar que el agente responde con widgets y/o mensaje

---

## T11 — Spawn Actions (select_product, select_category)

### T11.1 Select product desde grid → product_detail
- Con un product_grid visible, click en una card de producto
- Verificar que aparece un product_detail DEBAJO del grid (position: :after)
- Verificar que el detail muestra el producto correcto (mismo nombre/precio)
- Verificar que es instantaneo (spawn_action, sin agente)
- Verificar que el detail tiene datos cargados (data_source auto-resolved)

### T11.2 Select product desde carousel → product_detail
- Con un product_carousel visible, click en una card
- Verificar que aparece product_detail debajo del carousel
- Verificar datos correctos

### T11.3 Select category → product_grid
- Con category_browser visible, click en "keyboards"
- Verificar que aparece product_grid con id "grid-keyboards" en posicion :top
- Verificar que muestra solo productos de keyboards
- Click en otra categoria (ej: "mice")
- Verificar que aparece otro grid con id "grid-mice"

### T11.4 Re-spawn mismo producto
- Click en el mismo producto dos veces desde el grid
- Verificar que el detail se actualiza (no duplica — id es "detail-{product_id}")

---

## T12 — Cart via Reducer Chain

### T12.1 Add to cart desde grid
- Con product_grid visible, click en boton "Add to cart" de un producto
- Verificar que aparece widget cart (si no existia)
- Verificar que el producto aparece en el cart con cantidad 1

### T12.2 Add to cart desde carousel
- Con product_carousel visible, click en "Add to cart"
- Verificar que el producto se agrega al cart

### T12.3 Increment/decrement en cart
- Con cart visible con al menos 1 item:
- Click en boton "+" → verificar cantidad sube a 2
- Click en boton "-" → verificar cantidad baja a 1

### T12.4 Remove item del cart
- Con cart visible, click en boton remove (trash) de un item
- Verificar que el item desaparece del cart

### T12.5 Clear cart
- Con cart con 2+ items, click en "Clear cart"
- Verificar que el cart queda vacio

---

## T13 — Paginacion via Reducers (refetch)

Valida que paginacion funciona correctamente a traves del sistema reducer + refetch.

### T13.1 Next/prev en grid
- Con product_grid mostrando page 1 (ej: "1/4"):
- Click Next → verificar pagina "2/4", productos distintos, instantaneo
- Click Next → verificar pagina "3/4"
- Click Prev → verificar pagina "2/4"
- Click Prev → verificar pagina "1/4"
- Verificar que boton Prev no aparece en pagina 1

### T13.2 Next/prev en carousel
- Con product_carousel, mismo flujo que T13.1
- Verificar que las cards del carousel cambian

### T13.3 Cambio de categoria resetea pagina
- Con product_grid en pagina 3, cambiar categoria dropdown
- Verificar que pagina se resetea a 1
- Verificar que productos son de la nueva categoria

### T13.4 Cambio de per_page resetea pagina
- Con product_grid en pagina 2, cambiar dropdown "Show" a 3
- Verificar que pagina se resetea a 1
- Verificar que se muestran 3 cards

### T13.5 Search resetea pagina
- Con product_grid en pagina 2, escribir en search bar del grid
- Verificar que pagina se resetea a 1
- Verificar que resultados se filtran por query

---

## T14 — Category Browser: filter_categories

### T14.1 Filtro de categorias por texto
- Con category_browser visible, escribir "key" en el input de filtro
- Verificar que solo se muestra "keyboards" (filtro instantaneo)
- Borrar el texto
- Verificar que vuelven todas las categorias (6 total)

### T14.2 Filtro no encuentra nada
- Escribir "xyz123" en el input de filtro
- Verificar que no se muestra ninguna categoria
- Verificar que no hay error ni crash

---

## T15 — Wishlist

### T15.1 Add to wishlist desde product_detail
- Con product_detail visible (via grid click o agente), verificar que existe boton "Save" con icono bookmark
- Click en boton "Save"
- Verificar que aparece widget wishlist con el producto
- Verificar que el boton cambia a "Saved" (filled icon, color secondary)
- Verificar que es instantaneo (mecanico, sin "Thinking...")

### T15.2 Wishlist muestra items correctamente
- Con wishlist visible con al menos 1 item:
- Verificar que muestra: imagen, nombre, precio (sin cantidad)
- Verificar header "Wishlist (N)" con contador
- Verificar boton Clear y boton Close presentes

### T15.3 Remove item de wishlist
- Con wishlist con al menos 1 item, click en boton remove (X) de un item
- Verificar que el item desaparece de la wishlist
- Verificar que es instantaneo

### T15.4 Clear wishlist
- Con wishlist con 2+ items, click en "Clear"
- Verificar que la wishlist queda vacia (muestra empty state con icono bookmark)

### T15.5 Click item en wishlist abre product_detail
- Con wishlist con al menos 1 item, click en el item (nombre/imagen)
- Verificar que aparece product_detail debajo de la wishlist
- Verificar que muestra el producto correcto

### T15.6 Add idempotente
- Con un producto ya en la wishlist, ir a su product_detail
- Verificar que el boton dice "Saved" (ya esta en wishlist)
- Click en "Saved" de nuevo
- Verificar que NO se duplica el item en la wishlist (sigue siendo 1)

### T15.7 Wishlist persiste en mode switch
- Con items en la wishlist, toggle Agent OFF/ON via header
- Verificar que la wishlist y sus items persisten despues del switch
- Verificar que el widget wishlist aparece automaticamente si tenia items

---

## T16 — AgentScheduler (Serialización de Invocaciones)

Valida que mensajes rápidos no causan condiciones de carrera.

### T16.1 Mensajes rápidos — ambos procesados
- Reset layout (estado limpio)
- Enviar "show me smartphones" y 300ms después "also show me laptops"
- Verificar en logs: `[SCHEDULER] queued: message while agent busy`
- Verificar en logs: `[SCHEDULER] discarding stale result, re-invoking`
- Esperar a que "Thinking..." desaparezca
- Verificar que ambos grids aparecen: "Products (smartphones)" y "Products (laptops)"
- Verificar que la respuesta del agente menciona ambas categorías

### T16.2 Evento mecánico durante invocación
- Enviar un mensaje al agente ("show me keyboards")
- Mientras "Thinking..." está activo, realizar paginación en otro widget (ej: Top Rated)
- Verificar en logs: `notify_state_changed` marca dirty
- Verificar que el resultado final es correcto y no hay estado inconsistente

### T16.3 Indicador de thinking correcto
- Enviar mensajes rápidos
- Verificar que la barra de progreso superior aparece durante todo el proceso
- Verificar que desaparece al final (no se queda pegada)
- Verificar que el botón Send siempre está habilitado (no se deshabilita)

### T16.4 Reset durante busy
- Enviar mensaje al agente
- Mientras "Thinking...", click en "Reset layout"
- Verificar que el scheduler se resetea a idle
- Verificar que la UI vuelve al estado default sin errores

---

## T17 — Chat Category Buttons (inline)

Valida que el agente sugiere categorías como botones clickeables inline en el chat,
usando slugs reales de `get_categories`.

### T17.1 Sugerir categorías con botones inline
- Navegar a `http://localhost:4000` (sesión limpia)
- Enviar "qué categorías me recomendás para regalar?"
- Esperar respuesta del agente
- Verificar en logs: `executing tool=get_categories` (el agente debe consultar categorías reales)
- Verificar que el mensaje del agente contiene botones inline (no texto plano)
- Verificar que aparecen entre 3 y 6 botones con icono "category" y label legible
- Verificar que los botones son compactos (pills, no bloques grandes)

### T17.2 Slugs reales — click abre grid con productos
- Con botones de T17.1 visibles, click en cualquier botón de categoría
- Verificar que aparece un product_grid con productos (NO vacío, 0 resultados)
- Verificar que el grid muestra la categoría correcta en el dropdown
- Verificar que es instantáneo (spawn_action mecánico, sin "Thinking...")

### T17.3 No inventa categorías
- Verificar que todos los slugs usados en los botones existen en el category_browser (las 24 categorías de DummyJSON)
- Si algún botón usa un slug inventado (ej: "gifts", "decor", "home"), el test FALLA

---

## T18 — Chat Product Cards (inline)

Valida que el agente muestra mini-cards de producto inline en el chat,
con thumbnail, nombre y precio, y que al clickear abren product_detail.

### T18.1 Recomendar productos con cards inline
- Navegar a `http://localhost:4000` (sesión limpia)
- Enviar "busca laptops y recomendame las 3 mejores"
- Esperar respuesta del agente (usa search_products + get_product_detail)
- Verificar que el mensaje contiene product cards inline (no texto plano con nombres y precios)
- Verificar que cada card muestra: thumbnail (imagen circular), nombre (truncado), precio con $
- Verificar que aparecen exactamente 3 cards

### T18.2 Click en product card abre detail
- Con product cards de T18.1 visibles, click en cualquier card
- Verificar que aparece un product_detail widget en el área de widgets
- Verificar que el detail muestra el producto correcto (mismo nombre que la card)
- Verificar que es instantáneo (spawn_action mecánico, sin "Thinking...")

### T18.3 Datos reales de search
- Verificar que los productos mostrados en las cards son reales (existen en DummyJSON)
- Verificar que los precios coinciden con los datos del producto
- Verificar que las imágenes cargan correctamente (no broken)

---

## T19 — Formato del mensaje (no-markdown)

Valida que el agente responde en texto plano sin formateo markdown.

### T19.1 Sin markdown en respuestas normales
- Enviar "busca perfumes y recomendame los 3 mejores"
- Esperar respuesta del agente
- Verificar que el mensaje NO contiene `**texto**` (bold markdown)
- Verificar que el mensaje NO contiene `*texto*` (italic markdown)
- Verificar que el mensaje NO contiene `# heading` ni `` `code` ``
- Verificar que el mensaje es texto plano conversacional

### T19.2 Sin markdown cuando sugiere alternativas
- Enviar algo que no encuentra resultados (ej: "tenés zapatos de cristal?")
- Esperar respuesta del agente
- Verificar que la sugerencia de alternativas es texto plano (no `**Fragancias**` ni listas con `-`)

---

## Notas de ejecucion

- Los tests T2.x y T4.x requieren llamada al agente OpenAI (pueden tardar 3-10s). T4.3 y T4.4 son especialmente importantes — validan bugs reales en produccion
- Los tests T3.x, T9.x, T10.1-T10.3, T11.x, T12.x, T13.x, T14.x son instantaneos (eventos mecanicos via reducers)
- Los tests T10.4 requiere agente
- Los tests T5.x y T6.x requieren modificar `default_state.ex` y recompilar
- Los tests T17.x y T18.x requieren agente (search_products, get_categories). T17.2 y T18.2 son mecánicos (spawn_action)
- Los tests T19.x requieren agente — verificar visualmente que no hay markdown en el texto del mensaje
- Cuando un test falla, loguear: test ID, resultado esperado, resultado obtenido
- El server loguea a `/tmp/phx-server.log` — revisar ante errores
