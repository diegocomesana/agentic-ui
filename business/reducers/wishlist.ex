defmodule AgenticUi.Business.Reducers.Wishlist do
  @moduledoc """
  Reducers for wishlist widget events.
  Each function: reduce(store, ctx) :: store
  """

  alias AgenticUi.Store

  def add_to_wishlist(store, ctx) do
    product_data =
      case ctx.service_result do
        {:ok, data} -> data
        _ -> ctx.widget[:data] || %{}
      end

    store = Store.add_to_wishlist(store, product_data)
    ensure_wishlist_widget(store)
  end

  def remove_item(store, ctx) do
    Store.remove_from_wishlist(store, ctx.event_data["product_id"])
  end

  def clear(store, _ctx), do: Store.clear_wishlist(store)

  def select_item(store, ctx) do
    product_id = ctx.event_data["product_id"]
    detail_id = "detail-#{product_id}"

    Store.put_widget(store, detail_id, %{
      widget: "product_detail",
      config: %{"product_id" => product_id},
      data: %{}
    })
  end

  defp ensure_wishlist_widget(store) do
    if get_in(store, [:widgets, "wishlist"]) do
      store
    else
      store = Store.put_widget(store, "wishlist", %{widget: "wishlist", config: %{}, data: %{}})
      Store.add_to_layout(store, "wishlist")
    end
  end
end
