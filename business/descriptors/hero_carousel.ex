defmodule AgenticUi.Business.Descriptors.HeroCarousel do
  def descriptor do
    %{
      name: "Hero Carousel",
      description: "Animated carousel banner showcasing top-rated products. Auto-rotates. Supports category filter and limit, same config as top_products.",
      component: AgenticUi.Business.Widgets.HeroCarousel,
      config_schema: %{
        category: %{type: "string", description: "Filter by category (e.g. 'keyboards', 'mice'). Use 'all' or omit for all categories."},
        limit: %{type: "integer", description: "Number of products to show", default: 5},
        interval: %{type: "integer", description: "Auto-rotation interval in milliseconds", default: 5000}
      },
      data_source: "product_service.top_products",
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
      },
      events: %{
        "select_product" => %{description: "User clicks a product slide", params: ["product_id"]},
        "prev_slide" => %{description: "Go to previous slide"},
        "next_slide" => %{description: "Go to next slide"}
      }
    }
  end
end
