defmodule AgenticUi.Business.Descriptors.MainMenu do
  def descriptor do
    %{
      name: "Main Menu",
      description: "Horizontal navigation bar with quick-access buttons for search, categories, cart and wishlist. Always at the top.",
      component: AgenticUi.Business.Widgets.MainMenu,
      config_schema: %{},
      data_source: nil,
      events: %{
        "open_search" => %{
          description: "Open the search bar",
          params: []
        },
        "open_categories" => %{
          description: "Open the category browser",
          params: []
        },
        "open_cart" => %{
          description: "Open the shopping cart",
          params: []
        },
        "open_wishlist" => %{
          description: "Open the wishlist",
          params: []
        }
      },
      spawn_actions: %{
        "open_search" => [
          %{
            widget_type: "search_bar",
            widget_id: "search-bar",
            position: :after,
            config_map: %{},
            config_defaults: %{"placeholder" => "Search products..."}
          }
        ],
        "open_categories" => [
          %{
            widget_type: "category_browser",
            widget_id: "categories",
            position: :after,
            config_map: %{},
            config_defaults: %{}
          }
        ],
        "open_cart" => [
          %{
            widget_type: "cart",
            widget_id: "cart",
            position: :after,
            config_map: %{},
            config_defaults: %{}
          }
        ],
        "open_wishlist" => [
          %{
            widget_type: "wishlist",
            widget_id: "wishlist",
            position: :after,
            config_map: %{},
            config_defaults: %{}
          }
        ]
      },
      agent_instructions: "The main_menu is a fixed navigation bar — do NOT create or remove it. Users use it to open search, categories, cart and wishlist."
    }
  end
end
