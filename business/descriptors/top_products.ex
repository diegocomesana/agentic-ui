defmodule AgenticUi.Business.Descriptors.TopProducts do
  def descriptor do
    %{
      name: "Top Products",
      description: "Ranked list of top-rated products, optionally filtered by category. Shows up to 5 products sorted by rating.",
      component: AgenticUi.Business.Widgets.TopProducts,
      config_schema: %{
        category: %{type: "string", description: "Filter by category (optional, shows all if omitted)"},
        limit: %{type: "integer", description: "Number of products to show", default: 5}
      },
      data_source: "product_service.top_products",
      events: %{
        "select_product" => %{description: "User clicks a product", params: ["product_id"]},
        "add_to_cart" => %{
          description: "Add product to cart",
          params: ["product_id"],
          reducer: {AgenticUi.Business.Reducers.Cart, :add_to_cart},
          service_call: "product_service.get_detail",
          params_map: %{"product_id" => "product_id"}
        }
      },
      spawn_actions: %{
        "select_product" => [
          %{
            widget_type: "product_detail",
            widget_id: "detail-{product_id}",
            position: :before,
            config_map: %{"product_id" => "product_id"},
            config_defaults: %{}
          }
        ]
      }
    }
  end
end
