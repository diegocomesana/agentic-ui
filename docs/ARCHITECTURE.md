# Agentic UI — Architecture

## Vision

An application where the user interface is composed by a conversational agent in real time. The user interacts via chat (text or voice) and the agent dynamically composes the UI using predefined widgets, creating an experience that seamlessly fuses conversation and visual interface.

The UI works fully without the agent. When the agent is on, the same interface gains a conversational layer. Both modes share the same widgets, store, and mechanical events.

---

## Core Principles

1. **The agent does not generate UI, it composes it.** There is a finite catalog of predefined widgets with the brand's aesthetics and branding. The agent can only instantiate them, fill them with data, and position them.

2. **Centralized store as the single source of truth.** A state store contains the complete UI state: widgets, layout, conversation, cart, wishlist. The UI is purely reactive to this store.

3. **Dumb widgets.** Widgets are purely presentational: they receive props from the store, render, and emit events/actions. They know nothing about APIs, nothing about the agent.

4. **The agent is stateless.** Each agent invocation receives a snapshot that the Engine assembles from the store and the conversation history. The agent does not know the store exists. It maintains no state of its own between calls.

5. **Minimal latency.** Mechanical interactions (paginate, sort) do not go through the agent. Only semantic interactions (requiring reasoning) invoke it.

6. **Data is sacred.** Data comes from APIs and is displayed as-is. The agent cannot alter it. It controls configuration and intent, not the data.

7. **A single data function layer.** The agent's tools and the widget data sources are the same functions. There are no two parallel systems doing the same thing.

8. **One descriptor, everything resolved.** Each widget type is defined in a single place — the descriptor. The descriptor specifies which component to render, where the data comes from, how events are handled, and how it is serialized for the agent. The rest of the system reads the descriptor and executes. There is nothing else to configure.

---

## The Descriptor: the Heart of the Framework

The descriptor is **the only thing a developer writes per widget type**. It defines everything the system needs to know for that widget to work end to end.

### Complete descriptor (data-bound widget)

```elixir
%{
  type: "product-grid",
  component: ProductGrid,

  # How to fetch data
  data_source: "product_service.list_products",

  config_schema: %{
    query:    %{type: "string", description: "Search query"},
    page:     %{type: "integer", default: 1},
    per_page: %{type: "integer", default: 6},
    category: %{type: "string"}
  },

  # What events exist — mechanical (reducer) or semantic (agent)
  events: %{
    "next_page" => %{
      reducer: {Config, :increment_config},
      reducer_opts: %{config_key: "page"},
      refetch: true
    },
    "prev_page" => %{
      reducer: {Config, :decrement_config},
      reducer_opts: %{config_key: "page"},
      refetch: true
    },
    "add_to_cart" => %{
      reducer: {Cart, :add_to_cart},
      service_call: "product_service.get_detail",
      params: ["product_id"]
    },
    "select_product" => :spawn_action
  },

  # Auto-spawn other widgets on events
  spawn_actions: %{
    "select_product" => [
      %{
        widget_type: "product_detail",
        widget_id: "detail-{product_id}",
        config_map: %{"product_id" => "product_id"}
      }
    ]
  },

  # How to serialize for the agent
  agent_view: %{
    summary_fields: [:pos, :id, :name, :price, :rating],
    detail_fields:  [:pos, :id, :name, :price, :rating, :brand, :description]
  }
}
```

### Descriptor (agent-filled widget)

```elixir
%{
  type: "hero_banner",
  component: HeroBanner,
  data_source: :agent_provided,
  # Agent fills title, subtitle, gradient, CTA directly
}
```

### What the descriptor resolves

By defining the descriptor above, the following is automatically resolved:

| Capability | Resolved by the descriptor |
|---|---|
| **Rendering** | `component` -> the Renderer knows which HEEx component to render |
| **Data fetching** | `data_source` -> the Engine knows which service to call and how to map config -> params |
| **Mechanical events** | `events` + `reducer` -> the Engine dispatches to the reducer, optionally refetches data |
| **Spawn actions** | `spawn_actions` -> the Engine creates new widgets when events fire |
| **Guard conditions** | `guard` -> the Engine blocks events that fail validation (e.g., empty search) |
| **Semantic conditions** | `semantic_condition` -> the Engine reroutes events to the agent chat based on config flags |
| **Agent context** | `agent_view` -> the Engine serializes the data with the correct fields |
| **Agent catalog** | `type` + `config_schema` -> the Engine generates the catalog and passes it to the agent |
| **Agent tools** | `data_source` service -> same functions exposed as MCP tools |

**No other file needs to be touched.** The descriptor is the single configuration point per widget.

---

## Stack & Implementation

### Phoenix LiveView (Elixir monolith)

The chosen stack is **a single Phoenix app with LiveView**. The separation between layers is **logical** (modules and conventions), not physical (separate repos or deploys).

Reasons:
- LiveView already solves reactivity: assigns change -> the DOM updates with minimal diffs.
- Native WebSocket support for real-time agent-to-UI communication.
- Each user session is an isolated lightweight BEAM process.
- A single deploy, a single language, debuggable end-to-end.

### Two logical layers within the monolith

**1. Visual Layer** — Renderer, LiveView, and HEEx function components.
- The **Renderer** traverses the store, reads descriptors, and maps each widget to its component with its assigns.
- The **widgets** (function components) only receive assigns and render. They have no business logic.
- They emit LiveView events (`phx-click`, `phx-change`, etc.) that the LiveView passes to the Engine.

**2. Core Layer** — Pure Elixir modules.
- Engine, Store, Services, Agent, Tools. All business logic lives here.
- **They do not depend on Phoenix/LiveView.** They are pure Elixir modules testable in isolation.

### Module structure

```
lib/
  agentic_ui/                     # Core Layer (does not depend on Phoenix)
    engine.ex                      # Reads descriptors, processes events, returns commands
    store.ex                       # Centralized state (pure functions)
    agent_scheduler.ex             # Pure state machine: serializes agent invocations
    session.ex                     # GenServer in-memory + async DB persistence + undo history
    repo.ex                        # Ecto.Repo (optional, when DATABASE_URL configured)
    release.ex                     # Migration runner for production
    accounts.ex                    # Guest user + session persistence context
    accounts/                      # Ecto schemas
      guest_user.ex                # UUID token, last_seen_at
      guest_session.ex             # store_data (JSONB), belongs_to guest_user
    agent/                         # LLM invocation
      agent.ex                     # Prompt builder + tool loop + JSON mode
      provider.ex                  # LLM provider behaviour (pluggable)
      providers/
        openai.ex                  # OpenAI HTTP client (HTTPoison + retry)
      prompts/
        system_prompt.eex          # Framework system prompt template
    application.ex                 # OTP supervisor tree

  agentic_ui_web/                  # Visual Layer (Phoenix/LiveView)
    renderer.ex                    # Traverses store, reads descriptors, maps widgets to components
    live/
      workspace_live.ex            # Main LiveView: async agent tasks, event routing
    components/
      widgets/
        chat.ex                    # Chat component (shared, not business-specific)
    plugs/
      guest_plug.ex                # Guest token cookie assignment

business/                          # Business Layer (YOUR code — edit only this)
  ui_config.ex                     # Branding, labels, visibility toggles, state summarizer
  default_state.ex                 # Initial widgets per mode (agent_on / agent_off)
  prompts/
    business_prompt.eex            # Business-specific agent prompt (EEx template)
  descriptors/                     # One file per widget type
    registry.ex                    # Maps type string -> descriptor module
    product_grid.ex
    product_carousel.ex
    product_detail.ex
    comparator.ex
    hero_banner.ex
    hero_carousel.ex
    category_browser.ex
    top_products.ex
    cart.ex
    wishlist.ex
    search_bar.ex
    main_menu.ex
    chat_product_card.ex
    chat_category_button.ex
  widgets/                         # HEEx function components (one per type)
    product_grid.ex
    product_carousel.ex
    product_detail.ex
    comparator.ex
    hero_banner.ex
    hero_carousel.ex
    category_browser.ex
    top_products.ex
    cart.ex
    wishlist.ex
    search_bar.ex
    main_menu.ex
    chat_product_card.ex
    chat_category_button.ex
  reducers/                        # Pluggable state mutations
    cart.ex                        # add_to_cart, increment, decrement, remove_item, clear, select_item
    wishlist.ex                    # add_to_wishlist, remove_item, clear, select_item
    common.ex                      # toggle_pin, close, toggle_config
    config.ex                      # increment_config, decrement_config, set_config, set_config_typed, reset_config
  services/                        # Data layer
    product_service.ex             # list_products, get_detail, by_ids, categories, top
    dummy_json_client.ex           # HTTP client to DummyJSON API + normalization
    product_cache.ex               # ETS cache for product data
  tools/                           # Agent tools (MCP-standard format)
    registry.ex                    # Maps tool name -> module, provides definitions_for_api()
    search_products.ex             # Free-text & category search
    get_product_detail.ex          # Fetch full product details
    get_products_by_ids.ex         # Batch fetch for comparisons
    get_categories.ex              # List available categories
```

Each widget type consists of three files: a **descriptor** (in `descriptors/`), a **visual component** (in `widgets/`), and optionally a **reducer** (in `reducers/`). The Renderer connects them automatically via the descriptor's `component` field.

---

## Component Architecture

### 1. Widget (Visual Component)

- Purely presentational
- Receives props from the store (assigns in LiveView)
- Emits typed actions/events (e.g.: `next_page`, `add_to_cart`)
- Has no business logic, does not fetch data
- Maintains the brand's aesthetics and branding
- Two types:
  - **Data-bound:** filled automatically. The Engine reads the descriptor, calls the service, and puts the data in the store.
  - **Agent-filled:** the agent provides the data directly (e.g.: hero_banner).
- Two contexts:
  - **Workspace widgets** (12): rendered in the main widget area, support pinning/locking.
  - **Chat widgets** (2): rendered inline in chat messages, spawn workspace widgets on interaction.

### 2. Central Store

- Contains the complete state: **widgets** (config + data), **layout** (direction), **conversation** (chat history), **cart**, **wishlist**, **pinned/locked flags**
- It is a module of pure functions `state_in -> state_out`, not a process
- **Only the Engine can mutate it.** No other module writes to the store.
- Supports intermediate states (loading) without losing existing data
- When the store changes, the Renderer maps widgets to components -> LiveView re-renders
- Serializable to JSON for persistence (`to_persistable` / `from_persistable`)

Store structure:

```json
{
  "widgets": {
    "pg-1": {
      "type": "product_grid",
      "config": { "category": "keyboards", "page": 1, "per_page": 6 },
      "data": { "items": [...], "total": 47 },
      "pinned": false,
      "locked": false
    }
  },
  "layout": {
    "direction": "vertical"
  },
  "conversation": [
    { "role": "user", "content": "show me keyboards" },
    { "role": "assistant", "content": "Here are some keyboards!" }
  ],
  "cart": { "items": [{ "product_id": "42", "name": "Keyboard", "price": 29.99, "quantity": 2 }] },
  "wishlist": { "items": [{ "product_id": "15", "name": "Mouse" }] }
}
```

### 3. Engine

The Engine reads descriptors and handles all backend logic: processing events, invoking the agent, resolving data, and generating the new state.

**The Engine is the only one that writes to the store.**

Event processing pipeline:
1. **Guard check** — block event if params fail validation (e.g., empty search)
2. **Semantic condition** — reroute event to agent chat if a config flag is truthy
3. **Spawn actions** — auto-create widgets when events fire (templated IDs, config mapping)
4. **Pluggable reducers** — call descriptor-declared reducer functions
5. **Service call** — fetch data before/after reducer
6. **Refetch** — re-fetch widget data after config mutation

Key functions:

```elixir
Engine.process_chat(message, store) -> {:invoke_agent, context, store}
Engine.apply_agent_response(store, agent_response) -> {:ok, store, data_calls}
Engine.process_widget_event(widget_id, action, event_data, store) -> result
Engine.resolve_data(store, data_calls) -> store
```

### 4. Renderer

The Renderer traverses the store and maps each widget to its component.

```elixir
Renderer.render(store) -> [{component, assigns}, ...]
```

It is a **pure mapping**: `store.widgets[id].type -> descriptor.component -> assigns`.

### 5. Service Layer + Embedded MCP Tools

A single data function layer with **two entry points** reaching the same functions:

```
+--------------------------------------------------+
|            Services (pure functions)               |
|                                                    |
|  ProductService.list_products(params) -> data      |
|  ProductService.get_detail(id) -> detail           |
|  ProductService.categories() -> list               |
+----------+----------------------------+-----------+
           |                            |
     direct call                  tool call via MCP
     (Engine for mechanical       (Agent exploring data,
      and data resolution)         multi-turn reasoning)
```

**Embedded MCP (Model Context Protocol)** — tools are defined in MCP-standard format (`inputSchema`) and the registry converts them to the provider-specific format at the API boundary. Tool definitions are **provider-agnostic** — switching LLM providers doesn't require rewriting tools.

Each tool module has:
- `definition()` — returns the tool schema in MCP format (name, description, inputSchema)
- `execute(args)` — calls the underlying service

Adding a new tool module + registering it makes it **automatically available to the agent** — no other code changes needed.

All service calls go through an **ETS cache** (`ProductCache`) with configurable TTL (default 5 minutes). The cache is shared between Engine calls (widget data resolution) and Agent tool calls.

### 6. Agent

- **Provider-agnostic**: pluggable via `AgenticUi.Agent.Provider` behaviour. Default: OpenAI.
- **JSON mode**: responds with `{message, widgets, layout}`
- **Multi-turn tool calling loop**: up to 20 iterative tool calls per invocation. The agent calls tools, evaluates results, decides whether to call more tools or produce a final response.
- **Stateless**: each request includes all necessary context assembled by the Engine:
  - Conversation history (last 20 messages)
  - Current UI state snapshot (serialized using `agent_view` from each descriptor)
  - Catalog of available widgets (auto-generated from descriptors)
  - Tool definitions (auto-generated from Tools.Registry, converted to provider format)
  - Pinned widgets (which widgets cannot be removed)
  - State context per message (via StateSummarizer)
- Responds with:
  - Conversational message for the user
  - Widget operations (add/update/remove/clear_all)
  - Layout direction

#### Provider Behaviour

```elixir
@callback chat_completion(messages, opts) :: {:ok, map()} | {:error, term()}
@callback format_tools(tools) :: list()
@callback format_response_format(format) :: map()
@callback name() :: String.t()
```

Configurable via `AGENT_PROVIDER` env var. Currently implemented: OpenAI (`providers/openai.ex`).

### 7. AgentScheduler

A pure state machine (`agent_scheduler.ex`) that serializes agent invocations. It lives in the LiveView socket as an assign and guarantees:

- **At most one agent task runs at a time** — prevents parallel `Task.async` with stale snapshots
- **When state changes during execution (new messages, mechanical events), the stale result is discarded** and the agent is re-invoked with the fresh store
- **Multiple events are collapsed** — 3 messages while busy = 1 reinvocation, not 3

States: `:idle` (no agent running) and `:busy` (agent task in flight).
When dirty (state changed during busy), `task_completed/1` returns `{:reinvoke, scheduler}` instead of `{:idle, scheduler}`.

### 8. State Summarizer

When configured, the Engine attaches a compact state snapshot to every conversation message at creation time. The agent sees state evolution across the history:

- Message 12: `[cart(3): Mouse, Keyboard, Hub | screen: grid-keyboards, cart]`
- Message 15: `[cart: empty | screen: grid-keyboards]`

This prevents the agent from hallucinating stale state (e.g., believing items are still in the cart because an old message says "Added X to cart").

Configuration: `business/ui_config.ex` -> `state_summarizer: MyModule`

---

## Layout System

The layout supports two directions:
- `vertical` — widgets stacked top to bottom (default)
- `horizontal` — widgets side by side

The agent declares the layout direction as part of its response. The Renderer applies it.

---

## Agent Declarative Model

### The agent declares state, it does not emit commands

Instead of sending imperative commands (render, update, remove), the agent declares widget operations. The Engine processes each operation:

- `"add"` — create a new widget (or update if it already exists)
- `"update"` — update an existing widget's config
- `"remove"` — remove a widget (unless pinned)
- `"clear_all"` — remove all unpinned widgets

### Agent response format

```json
{
  "message": "Here are some mechanical keyboards!",
  "widgets": [
    {
      "action": "add",
      "type": "product_grid",
      "id": "grid-keyboards",
      "config": {
        "category": "keyboards",
        "page": 1,
        "per_page": 6
      }
    }
  ],
  "layout": {
    "direction": "vertical"
  }
}
```

The agent does not send product data. Only the config. The Engine reads the descriptor, maps the config to service params, calls the service, and puts the data in the store.

---

## Multi-Mode Operation

The app supports two modes, switchable at runtime:

- **Agent on** — full experience with AI chat. Default widgets: hero_carousel, search_bar, categories, top_products.
- **Agent off** — manual widget browsing, direct search, no agent. Default widgets: search_bar, categories, top_products.

Mode switch preserves cart, wishlist, and conversation. Each mode has its own default widget set defined in `business/default_state.ex`.

---

## Interaction Types

### Mechanical Interactions
- Paginate, sort, filter, close, toggle pin, add to cart
- Predictable, do not require reasoning
- Widget emits event -> Engine reads descriptor -> finds reducer -> applies state change -> optionally refetches data
- **Do not go through the agent**
- Defined in the descriptor's `events` with a `reducer` key

### Semantic Interactions
- "Compare these two", "Find something similar but cheaper"
- Require agent reasoning
- Routed to the agent with full context
- The search bar in "semantic mode" is an example (controlled by `semantic_condition` in the descriptor)

### Conversational Interactions
- The user writes or speaks directly to the agent via chat
- Always go through the agent
- The agent responds with message + widgets + layout

---

## Reducer System

Reducers are pluggable state mutations declared in descriptors. When a mechanical event fires:

1. Engine looks up the event in the descriptor
2. Finds the `reducer: {Module, :function}` declaration
3. Calls the reducer with `(widget, event_data, store, opts)`
4. The reducer returns the updated store

Four reducer modules:
- **Cart** (6 fns) — add_to_cart, increment, decrement, remove_item, clear, select_item
- **Wishlist** (4 fns) — add_to_wishlist, remove_item, clear, select_item
- **Config** (5 fns) — increment_config, decrement_config, set_config, set_config_typed, reset_config
- **Common** (3 fns) — toggle_pin, close, toggle_config

Universal actions (`toggle_pin`, `close`) work on any widget without needing descriptor declarations.

---

## Persistence

### Dual storage mode

The app works in two modes depending on whether `DATABASE_URL` is configured:

**Without DATABASE_URL (in-memory):**
- Session state lives in a GenServer with undo history
- State is lost on server restart
- Useful for development and quick testing

**With DATABASE_URL (PostgreSQL):**
- Same GenServer for in-memory state + undo history
- Async background persistence to PostgreSQL (non-blocking)
- Guest users identified by UUID cookie
- Session state (store as JSONB) persists across restarts
- Schema:

```
guest_users
  - token (UUID, unique)
  - last_seen_at

sessions
  - guest_user_id (FK -> guest_users, unique)
  - store_data (JSONB)
```

---

## Complete Flows

### Conversational interaction
```
User: "show me cheap mechanical keyboards"
  -> handle_event("send_message", ...)
  -> Engine.process_chat(message, store) -> {:invoke_agent, context, store}
  -> AgentScheduler.request_invocation(scheduler)
     -> {:invoke, scheduler} -> LiveView spawns Agent task (Task.async)
     -> {:queued, scheduler} -> store updated but no new task (dirty=true)
  -> Agent sends tools + context to LLM provider
  -> Provider makes tool calls: search_products("mechanical keyboards")
  -> Tools.Registry.execute("search_products", args) -> ProductService
  -> Tool results returned to provider as tool messages
  -> Provider responds with final JSON: {message, widgets, layout}
  -> AgentScheduler.task_completed(scheduler)
     -> {:idle, scheduler} -> Engine.apply_agent_response, resolve_data, re-render
     -> {:reinvoke, scheduler} -> discard stale result, re-invoke with fresh store
```

### Mechanical interaction
```
User: clicks "Next page" on product_grid
  -> handle_event("widget_action", %{widget_id: "pg-1", action: "next_page"})
  -> Engine.process_widget_event("pg-1", "next_page", %{}, store)
    -> reads product_grid descriptor
    -> events["next_page"] -> reducer: Config.increment_config, refetch: true
    -> reducer increments config.page from 1 to 2
    -> Engine refetches data: ProductService.list_products(page: 2, ...)
    -> returns updated store
  -> assign(socket, store: new_store) -> UI updates
  -> Agent was NOT invoked (instant)
```

### Spawn action
```
User: clicks a product in the grid
  -> Engine.process_widget_event("pg-1", "select_product", %{product_id: "42"}, store)
  -> Descriptor has spawn_actions for "select_product"
  -> Engine creates a new product_detail widget with id "detail-42", config: %{product_id: "42"}
  -> Engine resolves data: ProductService.get_detail("42")
  -> Store updated with new widget + data
  -> UI renders grid + detail
```

---

## Contracts Between Modules

```elixir
# Engine: reads descriptors, processes events, returns commands.
Engine.process_chat(message, store) -> {:invoke_agent, context, store}
Engine.apply_agent_response(store, result) -> {:ok, store, data_calls}
Engine.process_widget_event(widget_id, action, event_data, store) -> {:ok, store} | {:invoke_agent, context, store}
Engine.resolve_data(store, data_calls) -> store

# Renderer: traverses store, maps widgets to components.
Renderer.render(store) -> [{component, assigns}]

# Store: pure functions state -> state.
Store.put_widget(store, id, widget) -> store
Store.set_widget_data(store, widget_id, data) -> store
Store.set_loading(store, widget_id, bool) -> store
Store.add_message(store, message) -> store
Store.set_layout(store, layout) -> store
Store.clear_unpinned_widgets(store) -> store
Store.toggle_pin(store, widget_id) -> store
Store.add_to_cart(store, product) -> store
Store.add_to_wishlist(store, product) -> store
Store.put_chat_widget(store, message_index, widget) -> store
Store.to_persistable(store) -> map
Store.from_persistable(data) -> store

# AgentScheduler: serializes agent invocations (pure state machine).
AgentScheduler.new() -> scheduler
AgentScheduler.request_invocation(scheduler) -> {:invoke, scheduler} | {:queued, scheduler}
AgentScheduler.notify_state_changed(scheduler) -> scheduler
AgentScheduler.task_completed(scheduler) -> {:reinvoke, scheduler} | {:idle, scheduler}
AgentScheduler.busy?(scheduler) -> boolean

# Agent: invokes LLM, returns result.
Agent.invoke(context) -> {:ok, response} | {:error, reason}

# Provider behaviour (pluggable LLM backend).
Provider.chat_completion(messages, opts) -> {:ok, map()} | {:error, term()}
Provider.format_tools(tools) -> list()
Provider.format_response_format(format) -> map()
Provider.name() -> String.t()

# Tools: embedded MCP (provider-agnostic definitions + execution).
Tools.Registry.definitions() -> [mcp_tool_definitions]
Tools.Registry.definitions_for_api() -> [provider_tool_definitions]
Tools.Registry.execute(name, args) -> {:ok, result} | {:error, reason}

# Services: data functions.
ProductService.list_products(params) -> list
ProductService.get_detail(id) -> map
ProductService.get_products_by_ids(ids) -> list
ProductService.categories() -> list
```

None of these modules import `Phoenix.LiveView`. They are testable with pure ExUnit.

---

## What's Implemented

### Widgets (14)
12 workspace widgets: product_grid, product_carousel, product_detail, comparator, hero_banner, hero_carousel, category_browser, top_products, cart, wishlist, search_bar, main_menu.
2 chat widgets: chat_product_card, chat_category_button (inline in messages, spawn workspace widgets on click).

### Agent Tools (4 — MCP-standard)
search_products, get_product_detail, get_products_by_ids, get_categories.
Multi-turn tool calling (up to 20 rounds per invocation). ETS cache shared between Engine and Agent calls.

### Reducers (4 modules, 18 functions)
Cart (6), Wishlist (4), Config (5), Common (3).

### Framework
- Descriptor-driven widget system (config + data_source + events + reducers + spawn_actions + guards + semantic conditions)
- Mechanical vs semantic event dispatch
- Spawn actions with templated IDs and config mapping
- Widget pinning (survives agent clear) and locking (non-removable)
- Universal close/pin actions on all widgets
- Multi-mode operation (agent on/off with different default widgets)
- AgentScheduler state machine (serializes invocations, discards stale, auto-reinvokes)
- State Summarizer (compact state context per message)
- Provider-agnostic agent (behaviour + OpenAI implementation)
- Renderer with layout support (vertical/horizontal)

### Persistence
- In-memory GenServer with undo history
- Optional PostgreSQL via Ecto (guest users + sessions with JSONB store)
- Async background persistence (non-blocking)
- Guest user identification via UUID cookie

### UI/UX
- Split layout: widgets + chat
- Speech-to-text input
- Theme toggle (light/dark/system via daisyUI)
- Debug panel (real-time state, model name, widget/message count)
- Loading skeletons on all data-bound widgets
- Widget enter/exit animations
- Auto-scroll chat

### Business Layer
- `business/` directory with all custom code
- `ui_config.ex` for branding, labels, visibility, error messages
- `default_state.ex` for initial widgets per mode
- `business_prompt.eex` for business-specific agent prompt
- DummyJSON API client with ETS cache and normalization
