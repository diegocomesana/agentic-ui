defmodule AgenticUi.Business.Descriptors.Cart do
  def descriptor do
    %{
      name: "Shopping Cart",
      description: "Shopping cart showing added products with quantities and total. Products are added from product_detail widgets.",
      component: AgenticUi.Business.Widgets.Cart,
      config_schema: %{},
      data_source: nil,
      events: %{
        "increment" => %{
          description: "Increase item quantity",
          params: ["product_id"],
          reducer: {AgenticUi.Business.Reducers.Cart, :increment}
        },
        "decrement" => %{
          description: "Decrease item quantity",
          params: ["product_id"],
          reducer: {AgenticUi.Business.Reducers.Cart, :decrement}
        },
        "remove_item" => %{
          description: "Remove item from cart",
          params: ["product_id"],
          reducer: {AgenticUi.Business.Reducers.Cart, :remove_item}
        },
        "clear_cart" => %{
          description: "Remove all items from cart",
          reducer: {AgenticUi.Business.Reducers.Cart, :clear}
        },
        "select_item" => %{
          description: "Click a cart item to view its product detail",
          params: ["product_id"],
          reducer: {AgenticUi.Business.Reducers.Cart, :select_item},
          service_call: "product_service.get_detail",
          params_map: %{"product_id" => "product_id"},
          service_target: "detail-{product_id}"
        }
      }
    }
  end
end
