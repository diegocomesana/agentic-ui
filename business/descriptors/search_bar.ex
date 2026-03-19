defmodule AgenticUi.Business.Descriptors.SearchBar do
  def descriptor do
    %{
      name: "Search Bar",
      description: "Prominent search input for finding products. Submitting a search spawns a product_grid directly, or sends the query to the agent chat when agent_mode is enabled.",
      component: AgenticUi.Business.Widgets.SearchBar,
      config_schema: %{
        placeholder: %{type: "string", description: "Placeholder text", default: "Search products..."},
        agent_mode: %{type: "boolean", description: "When false (default), search spawns a product_grid directly. When true, sends the query to the agent chat.", default: false}
      },
      data_source: nil,
      events: %{
        "submit_search" => %{
          description: "User submits a search query",
          params: ["query"],
          guard: %{non_empty: ["query"]},
          semantic_condition: "agent_mode",
          semantic_message: "Search for: {query}"
        },
        "toggle_mode" => %{
          description: "Toggle between direct grid results and agent chat mode",
          params: [],
          reducer: {AgenticUi.Business.Reducers.Common, :toggle_config},
          reducer_opts: %{config_key: "agent_mode"}
        }
      },
      spawn_actions: %{
        "submit_search" => [
          %{
            widget_type: "product_grid",
            widget_id: "grid-search",
            position: :before,
            config_map: %{"query" => "query"},
            config_defaults: %{"page" => 1, "per_page" => 6}
          }
        ]
      }
    }
  end
end
