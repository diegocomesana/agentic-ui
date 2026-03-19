# business/ — Your Customization Zone

Everything in this directory is yours to modify. The framework reads from here but never writes to it.

## Quick Reference

### Change branding and labels
Edit `ui_config.ex` — app name, chat text, error messages, visibility toggles for header buttons.

### Change initial widgets
Edit `default_state.ex` — what widgets appear when the page loads.

### Change the agent prompt
Edit `prompts/business_prompt.eex` — EEx template with auto-injected variables (`<%= @catalog %>`, `<%= @widget_types %>`, etc.).

### Customize the State Summarizer

The state summarizer generates a compact snapshot of the current state and attaches it
to every conversation message. The agent uses these to track state evolution.

Edit `state_summarizer.ex`:

```elixir
defmodule AgenticUi.Business.StateSummarizer do
  def summarize(store) do
    # Return a compact one-line string
    # Available: store[:cart], store[:wishlist], store.widgets, store.layout
    "[cart: #{length(store[:cart] || [])} items | ...]"
  end
end
```

Register in `ui_config.ex`:
```elixir
state_summarizer: AgenticUi.Business.StateSummarizer
```

Set to `nil` to disable. The framework works normally without it.

### Create a new widget (3 files + 2 registrations)

#### 1. Descriptor — `descriptors/my_widget.ex`

```elixir
defmodule AgenticUi.Business.Descriptors.MyWidget do
  def descriptor do
    %{
      name: "My Widget",
      description: "What this widget shows (used in agent catalog).",
      component: AgenticUi.Business.Widgets.MyWidget,
      config_schema: %{
        some_param: %{type: "string", description: "A config field"}
      },
      data_source: "product_service.list_products",   # or :agent_provided
      events: %{
        "my_action" => %{
          description: "What happens",
          reducer: {AgenticUi.Business.Reducers.Config, :set_config},
          reducer_opts: %{config_map: %{"some_param" => "value"}},
          refetch: true
        }
      }
    }
  end
end
```

#### 2. Component — `widgets/my_widget.ex`

```elixir
defmodule AgenticUi.Business.Widgets.MyWidget do
  use Phoenix.Component

  def render(assigns) do
    ~H"""
    <div class="p-4">
      <h2>{@config["some_param"]}</h2>
      <div :for={item <- @data["items"] || []}>
        {item["name"]}
      </div>
    </div>
    """
  end
end
```

The component receives these assigns:
- `@widget_id` — unique widget instance ID
- `@config` — widget config (string keys)
- `@data` — resolved data from service (string keys)
- `@loading` — boolean, true while data is being fetched
- `@pinned` — boolean, whether the widget is pinned

#### 3. Register in `descriptors/registry.ex`

Add one line to the `@descriptors` map:

```elixir
@descriptors %{
  # ... existing widgets ...
  "my_widget" => AgenticUi.Business.Descriptors.MyWidget
}
```

That's it. The agent will see your widget in its catalog and can create it.

### Add a reducer

Create in `reducers/`, for example `reducers/my_reducer.ex`:

```elixir
defmodule AgenticUi.Business.Reducers.MyReducer do
  def my_action(widget, event_data, store, _opts) do
    # widget = %{"config" => ..., "data" => ...}
    # Return updated store
    store
  end
end
```

Then reference it from a descriptor event:

```elixir
"my_action" => %{
  reducer: {AgenticUi.Business.Reducers.MyReducer, :my_action}
}
```

### Add an agent tool (embedded MCP)

Tools use **MCP-standard format** (`inputSchema`). The configured LLM provider converts to its native format automatically.

Create in `tools/`, for example `tools/my_tool.ex`:

```elixir
defmodule AgenticUi.Business.Tools.MyTool do
  def definition do
    %{
      "name" => "my_tool",
      "description" => "What this tool does (the agent reads this to decide when to call it).",
      "inputSchema" => %{
        "type" => "object",
        "properties" => %{
          "query" => %{"type" => "string", "description" => "Search query"}
        },
        "required" => ["query"]
      }
    }
  end

  def execute(args) do
    # Call your service
    result = AgenticUi.Business.Services.MyService.search(args["query"])
    {:ok, result}
  end
end
```

Register in `tools/registry.ex`:

```elixir
@tools %{
  # ... existing tools ...
  "my_tool" => AgenticUi.Business.Tools.MyTool
}
```

That's it — the agent will automatically discover and use the new tool. The configured LLM provider converts `inputSchema` to its native format (OpenAI `parameters`, Anthropic `input_schema`, etc.) automatically.

### Add a service

Create in `services/`. Services are plain Elixir modules — no special interface required. Call them from tools and/or reference them as `data_source` in descriptors.

The Engine resolves `data_source` strings like `"product_service.list_products"` by calling `Engine.execute_service_call/2`. To add a new service, you need to add a clause in the Engine's `build_service_call_from_config/2` and `execute_service_call/2` functions.

## File Overview

| File | What it does | When to edit |
|------|-------------|--------------|
| `ui_config.ex` | Branding, labels, visibility toggles, component overrides | Changing look & feel |
| `default_state.ex` | Widgets shown on page load | Changing initial experience |
| `prompts/business_prompt.eex` | Business-specific agent prompt | Changing agent behavior |
| `descriptors/registry.ex` | Type string -> descriptor module | Adding/removing widget types |
| `descriptors/*.ex` | Widget definitions (config, events, data, agent view) | Creating/modifying widgets |
| `widgets/*.ex` | HEEx components | Creating/modifying widget UI |
| `reducers/*.ex` | State mutations for mechanical events | Adding event handlers |
| `services/*.ex` | Data layer (HTTP clients, caches) | Changing data sources |
| `tools/registry.ex` | Tool name -> module | Adding/removing agent tools |
| `tools/*.ex` | OpenAI function-calling definitions + execution | Adding agent capabilities |

## Descriptor Events Reference

Events can have these keys:

| Key | Type | Description |
|-----|------|-------------|
| `description` | string | What the event does (documentation) |
| `params` | list | Event data keys to extract from the UI event |
| `reducer` | `{Module, :function}` | Reducer to call for state mutation |
| `reducer_opts` | map | Options passed to the reducer |
| `refetch` | boolean | Re-fetch data from service after reducer runs |
| `service_call` | string | Service to call before reducer (e.g. fetch product detail) |
| `params_map` | map | Maps event data keys to service call params |

## Spawn Actions

Descriptors can auto-create widgets when events fire:

```elixir
spawn_actions: %{
  "select_product" => [
    %{
      widget_type: "product_detail",
      widget_id: "detail-{product_id}",    # template with event data
      config_map: %{"product_id" => "product_id"}
    }
  ]
}
```

When `select_product` fires with `%{"product_id" => "42"}`, the Engine creates a `product_detail` widget with ID `"detail-42"` and config `%{"product_id" => "42"}`.
