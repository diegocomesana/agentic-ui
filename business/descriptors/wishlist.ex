defmodule AgenticUi.Business.Descriptors.Wishlist do
  def descriptor do
    %{
      name: "Wishlist",
      description: "Saved products list (no quantities). Products are saved from product_detail widgets via the bookmark button.",
      component: AgenticUi.Business.Widgets.Wishlist,
      config_schema: %{},
      data_source: nil,
      events: %{
        "remove_item" => %{
          description: "Remove item from wishlist",
          params: ["product_id"],
          reducer: {AgenticUi.Business.Reducers.Wishlist, :remove_item}
        },
        "clear_wishlist" => %{
          description: "Remove all items from wishlist",
          reducer: {AgenticUi.Business.Reducers.Wishlist, :clear}
        },
        "select_item" => %{
          description: "Click a wishlist item to view its product detail",
          params: ["product_id"],
          reducer: {AgenticUi.Business.Reducers.Wishlist, :select_item},
          service_call: "product_service.get_detail",
          params_map: %{"product_id" => "product_id"},
          service_target: "detail-{product_id}"
        }
      }
    }
  end
end
