defmodule AgenticUi.Business.Widgets.ChatProductCard do
  use Phoenix.Component

  attr :widget_id, :string, required: true
  attr :config, :map, required: true

  def render(assigns) do
    name = assigns.config["name"] || "Product"
    price = assigns.config["price"]
    image = assigns.config["image"]
    product_id = assigns.config["product_id"] || ""
    assigns = assign(assigns, name: name, price: price, image: image, product_id: product_id)

    ~H"""
    <button
      phx-click="widget_action"
      phx-value-widget-id={@widget_id}
      phx-value-action="view_detail"
      phx-value-product_id={@product_id}
      class="inline-flex items-center gap-1.5 pl-0.5 pr-2.5 py-1 rounded-full text-xs font-medium bg-base-300/50 text-base-content hover:bg-base-300 border border-base-content/10 transition cursor-pointer leading-tight max-w-[200px]"
    >
      <img :if={@image} src={@image} alt={@name} class="w-6 h-6 rounded-full object-cover shrink-0" />
      <span class="truncate">{@name}</span>
      <span :if={@price} class="text-primary shrink-0">${format_price(@price)}</span>
    </button>
    """
  end

  defp format_price(price) when is_number(price), do: :erlang.float_to_binary(price / 1, decimals: 2)
  defp format_price(price) when is_binary(price), do: price
  defp format_price(_), do: "0.00"
end
