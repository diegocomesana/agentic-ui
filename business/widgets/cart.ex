defmodule AgenticUi.Business.Widgets.Cart do
  use Phoenix.Component
  alias Phoenix.LiveView.JS
  import AgenticUiWeb.CoreComponents, only: [mat_icon: 1]

  attr :id, :string, required: true
  attr :widget, :map, required: true
  attr :cart, :list, default: []

  def render(assigns) do
    cart = assigns[:cart] || []
    total = Enum.reduce(cart, 0.0, fn item, acc -> acc + (item.price || 0) * item.qty end)
    item_count = Enum.reduce(cart, 0, fn item, acc -> acc + item.qty end)

    assigns =
      assigns
      |> assign(:items, cart)
      |> assign(:total, total)
      |> assign(:item_count, item_count)

    ~H"""
    <div class="rounded-xl border border-base-300 bg-base-100 p-4 mb-4 transition-all duration-500 animate-in overflow-hidden min-w-0" phx-remove={JS.add_class("animate-out")}>
      <div class="flex items-center justify-between mb-3 min-w-0">
        <h2 class="text-sm font-semibold text-base-content truncate flex items-center gap-1.5">
          <.mat_icon name="shopping_cart" class="text-base text-base-content/40" />
          Cart
          <span :if={@item_count > 0} class="text-xs font-normal text-primary">
            ({@item_count})
          </span>
        </h2>
        <div class="flex items-center gap-1">
          <button
            :if={@items != []}
            phx-click="widget_action"
            phx-value-widget-id={@id}
            phx-value-action="clear_cart"
            class="text-xs text-base-content/40 hover:text-error transition"
            title="Clear cart"
          >
            Clear
          </button>
          <%= if @widget[:locked] do %>
            <span class="text-base-content/30" title="Locked">
              <.mat_icon name="lock" class="text-sm" />
            </span>
          <% else %>
            <button
              phx-click="widget_action"
              phx-value-widget-id={@id}
              phx-value-action="toggle_pin"
              class={[
                "transition",
                if(@widget[:pinned], do: "text-primary", else: "text-base-content/30 hover:text-base-content/50")
              ]}
              title={if(@widget[:pinned], do: "Unpin", else: "Pin")}
            >
              <.mat_icon name="push_pin" filled={@widget[:pinned] == true} class="text-sm" />
            </button>
            <button
              :if={!@widget[:pinned]}
              phx-click="widget_action"
              phx-value-widget-id={@id}
              phx-value-action="close"
              class="text-base-content/40 hover:text-base-content/60 transition"
            >
              <.mat_icon name="close" class="text-base" />
            </button>
          <% end %>
        </div>
      </div>

      <%!-- Empty state --%>
      <div :if={@items == []} class="text-center py-6 text-base-content/40 text-sm">
        <.mat_icon name="remove_shopping_cart" class="text-3xl mb-1" />
        <p>Your cart is empty</p>
      </div>

      <%!-- Items --%>
      <div :if={@items != []} class="space-y-2">
        <div :for={item <- @items} class="flex items-center gap-2 p-2 rounded-lg bg-base-200/30">
          <button
            phx-click="widget_action"
            phx-value-widget-id={@id}
            phx-value-action="select_item"
            phx-value-product-id={item.product_id}
            class="flex items-center gap-2 flex-1 min-w-0 text-left hover:opacity-70 transition cursor-pointer"
          >
            <img
              :if={item.image}
              src={item.image}
              alt={item.name}
              class="w-10 h-10 rounded-md object-cover bg-base-200 shrink-0"
            />
            <div class="flex-1 min-w-0">
              <p class="text-xs font-medium text-base-content truncate">{item.name}</p>
              <p class="text-xs text-primary font-semibold">${format_price(item.price)}</p>
            </div>
          </button>
          <div class="flex items-center gap-1 shrink-0">
            <button
              phx-click="widget_action"
              phx-value-widget-id={@id}
              phx-value-action="decrement"
              phx-value-product-id={item.product_id}
              class="w-6 h-6 flex items-center justify-center rounded bg-base-200 hover:bg-base-300 transition text-xs"
            >
              -
            </button>
            <span class="w-6 text-center text-xs font-medium">{item.qty}</span>
            <button
              phx-click="widget_action"
              phx-value-widget-id={@id}
              phx-value-action="increment"
              phx-value-product-id={item.product_id}
              class="w-6 h-6 flex items-center justify-center rounded bg-base-200 hover:bg-base-300 transition text-xs"
            >
              +
            </button>
            <button
              phx-click="widget_action"
              phx-value-widget-id={@id}
              phx-value-action="remove_item"
              phx-value-product-id={item.product_id}
              class="w-6 h-6 flex items-center justify-center rounded hover:bg-error/10 hover:text-error transition text-base-content/30 text-xs ml-1"
            >
              <.mat_icon name="close" class="text-sm" />
            </button>
          </div>
        </div>

        <%!-- Total --%>
        <div class="flex items-center justify-between pt-2 border-t border-base-300">
          <span class="text-sm font-semibold text-base-content">Total</span>
          <span class="text-sm font-bold text-primary">${format_price(@total)}</span>
        </div>
      </div>
    </div>
    """
  end

  defp format_price(nil), do: "0.00"
  defp format_price(p) when is_float(p), do: :erlang.float_to_binary(p, decimals: 2)
  defp format_price(p) when is_integer(p), do: "#{p}.00"
  defp format_price(p), do: "#{p}"
end
