defmodule AgenticUi.Business.Descriptors.ChatProductCard do
  def descriptor do
    %{
      name: "Chat Product Card",
      description: "Compact inline product card in chat messages. Shows thumbnail, name and price. When clicked, spawns a product_detail widget.",
      component: AgenticUi.Business.Widgets.ChatProductCard,
      config_schema: %{
        product_id: %{type: "string", description: "Product ID"},
        name: %{type: "string", description: "Product name"},
        price: %{type: "number", description: "Product price"},
        image: %{type: "string", description: "Product thumbnail URL"}
      },
      events: %{
        "view_detail" => %{
          description: "User clicks the product card"
        }
      },
      spawn_actions: %{
        "view_detail" => [
          %{
            widget_type: "product_detail",
            widget_id: "detail-{product_id}",
            position: :top,
            config_map: %{"product_id" => "product_id"},
            config_defaults: %{}
          }
        ]
      }
    }
  end
end
