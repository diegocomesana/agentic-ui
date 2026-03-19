defmodule AgenticUi.Business.Descriptors.CategoryBrowser do
  alias AgenticUi.Business.Reducers.Config

  def descriptor do
    %{
      name: "Category Browser",
      component: AgenticUi.Business.Widgets.CategoryBrowser,
      description: "Displays available product categories as clickable cards. When the user clicks a category, a product_grid filtered to that category appears automatically.",
      agent_instructions: "When the user clicks a category in the category_browser, a product_grid appears automatically — do NOT create one yourself in response to that click.",
      config_schema: %{},
      data_source: "product_service.list_categories",
      events: %{
        "filter_categories" => %{
          description: "Filter categories by text input",
          params: ["filter"],
          reducer: {Config, :set_config},
          reducer_opts: %{config_map: %{"filter" => "filter"}}
        }
      },
      spawn_actions: %{
        "select_category" => [
          %{
            widget_type: "product_grid",
            widget_id: "grid-{category}",
            position: :after,
            config_map: %{"category" => "category"},
            config_defaults: %{"page" => 1, "per_page" => 6}
          }
        ]
      }
    }
  end
end
