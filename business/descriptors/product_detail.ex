defmodule AgenticUi.Business.Descriptors.ProductDetail do
  def descriptor do
    %{
      name: "Product Detail",
      component: AgenticUi.Business.Widgets.ProductDetail,
      description: "Expanded card showing full product details: image, name, price, description, specs, rating.",
      config_schema: %{
        product_id: %{type: "string", description: "ID of the product to show", required: true}
      },
      data_source: "product_service.get_detail",
      events: %{
        "close" => %{
          description: "Close the detail view",
          reducer: {AgenticUi.Business.Reducers.Common, :close}
        },
        "add_to_cart" => %{
          description: "Add product to shopping cart",
          reducer: {AgenticUi.Business.Reducers.Cart, :add_to_cart}
        },
        "add_to_wishlist" => %{
          description: "Save product to wishlist",
          reducer: {AgenticUi.Business.Reducers.Wishlist, :add_to_wishlist}
        },
        "add_to_compare" => %{description: "Add product to comparison", params: ["product_id"]}
      }
    }
  end
end
