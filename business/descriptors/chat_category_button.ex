defmodule AgenticUi.Business.Descriptors.ChatCategoryButton do
  def descriptor do
    %{
      name: "Chat Category Button",
      description: "Inline button in chat messages. When clicked, spawns a product_grid for the specified category.",
      component: AgenticUi.Business.Widgets.ChatCategoryButton,
      config_schema: %{
        category: %{type: "string", description: "Category slug (English)"},
        label: %{type: "string", description: "Button text shown to the user"}
      },
      events: %{
        "select_category" => %{
          description: "User clicks the category button"
        }
      },
      spawn_actions: %{
        "select_category" => [
          %{
            widget_type: "product_grid",
            widget_id: "grid-{category}",
            position: :top,
            config_map: %{"category" => "category"},
            config_defaults: %{"page" => 1, "per_page" => 6}
          }
        ]
      }
    }
  end
end
