defmodule AgenticUi.Business.Reducers.Cart do
  @moduledoc """
  Reducers for cart widget events.
  Each function: reduce(store, ctx) :: store
  """

  alias AgenticUi.Store

  def add_to_cart(store, ctx) do
    product_data =
      case ctx.service_result do
        {:ok, data} -> data
        _ -> ctx.widget[:data] || %{}
      end

    store = Store.add_to_cart(store, product_data)
    ensure_cart_widget(store)
  end

  def increment(store, ctx) do
    Store.update_cart_qty(store, ctx.event_data["product_id"], 1)
  end

  def decrement(store, ctx) do
    Store.update_cart_qty(store, ctx.event_data["product_id"], -1)
  end

  def remove_item(store, ctx) do
    Store.remove_from_cart(store, ctx.event_data["product_id"])
  end

  def clear(store, _ctx), do: Store.clear_cart(store)

  def select_item(store, ctx) do
    product_id = ctx.event_data["product_id"]
    detail_id = "detail-#{product_id}"

    store =
      Store.put_widget(store, detail_id, %{
        widget: "product_detail",
        config: %{"product_id" => product_id},
        data: %{}
      })

    # Layout insertion is handled by the engine after service_call resolves
    store
  end

  defp ensure_cart_widget(store) do
    if get_in(store, [:widgets, "cart"]) do
      store
    else
      store = Store.put_widget(store, "cart", %{widget: "cart", config: %{}, data: %{}})
      Store.add_to_layout(store, "cart")
    end
  end
end
