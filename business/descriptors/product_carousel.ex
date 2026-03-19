defmodule AgenticUi.Business.Descriptors.ProductCarousel do
  alias AgenticUi.Business.Reducers.Config
  alias AgenticUi.Business.Reducers.Common

  def descriptor do
    %{
      name: "Product Carousel",
      description: "Horizontal carousel of product cards with left/right navigation. Same functionality as product_grid but displayed as a horizontal carousel.",
      component: AgenticUi.Business.Widgets.ProductCarousel,
      config_schema: %{
        category: %{type: "string", description: "Filter by category"},
        query: %{type: "string", description: "Search query"},
        page: %{type: "integer", description: "Page number", default: 1},
        per_page: %{type: "integer", description: "Items per page", default: 8, enum: [4, 8, 12]}
      },
      data_source: "product_service.list_products",
      events: %{
        "select_product" => %{description: "User clicks a product card", params: ["product_id"]},
        "add_to_cart" => %{
          description: "Add product to cart",
          params: ["product_id"],
          reducer: {AgenticUi.Business.Reducers.Cart, :add_to_cart},
          service_call: "product_service.get_detail",
          params_map: %{"product_id" => "product_id"}
        },
        "next_page" => %{
          description: "Go to next page",
          reducer: {Config, :increment_config},
          reducer_opts: %{config_key: "page"},
          refetch: true
        },
        "prev_page" => %{
          description: "Go to previous page",
          reducer: {Config, :decrement_config},
          reducer_opts: %{config_key: "page"},
          refetch: true
        },
        "search" => %{
          description: "Search products",
          params: ["query"],
          reducer: {Config, :set_config},
          reducer_opts: %{config_map: %{"query" => "query"}, resets: %{"page" => 1}},
          refetch: true
        },
        "change_category" => %{
          description: "Change category filter",
          params: ["category"],
          reducer: {Config, :set_config},
          reducer_opts: %{config_map: %{"category" => "category"}, resets: %{"query" => "", "page" => 1}},
          refetch: true
        },
        "apply_filters" => %{
          description: "Apply price/rating/sort filters",
          params: ["filter_min_price", "filter_max_price", "filter_min_rating", "filter_sort_by", "filter_sort_order"],
          reducer: {Config, :set_config_typed},
          reducer_opts: %{
            config_map: %{
              "min_price" => "filter_min_price",
              "max_price" => "filter_max_price",
              "min_rating" => "filter_min_rating",
              "sort_by" => "filter_sort_by",
              "sort_order" => "filter_sort_order"
            },
            types: %{"min_price" => :number, "max_price" => :number, "min_rating" => :number},
            defaults: %{"min_price" => 0, "max_price" => 10000, "min_rating" => 0, "sort_by" => "rating", "sort_order" => "desc"},
            resets: %{"page" => 1}
          },
          refetch: true
        },
        "reset_filters" => %{
          description: "Reset all filters to defaults",
          reducer: {Config, :reset_config},
          reducer_opts: %{
            defaults: %{
              "min_price" => 0,
              "max_price" => 10000,
              "min_rating" => 0,
              "sort_by" => "rating",
              "sort_order" => "desc",
              "page" => 1
            }
          },
          refetch: true
        },
        "toggle_filters" => %{
          description: "Toggle filter panel visibility",
          reducer: {Common, :toggle_config},
          reducer_opts: %{config_key: "filters_open"}
        },
        "update_filter_preview" => %{
          description: "Live update of range slider value without refetching",
          params: ["filter_min_rating"],
          reducer: {Config, :set_config_typed},
          reducer_opts: %{
            config_map: %{"min_rating" => "filter_min_rating"},
            types: %{"min_rating" => :number},
            defaults: %{"min_rating" => 0}
          }
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
