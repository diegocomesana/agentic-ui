defmodule AgenticUi.Business.Widgets.ProductDetail do
  use Phoenix.Component
  alias Phoenix.LiveView.JS
  import AgenticUiWeb.CoreComponents, only: [mat_icon: 1]

  attr :id, :string, required: true
  attr :widget, :map, required: true

  def render(assigns) do
    data = assigns.widget[:data] || %{}
    loading = assigns.widget[:loading] || false

    product_id = to_string(data[:id] || data["id"] || "")
    wishlist = assigns[:wishlist] || []
    in_wishlist = Enum.any?(wishlist, fn item -> item.product_id == product_id end)

    assigns =
      assigns
      |> assign(:product, data)
      |> assign(:loading, loading)
      |> assign(:has_data, data != %{})
      |> assign(:in_wishlist, in_wishlist)

    ~H"""
    <div class="rounded-xl border border-base-300 bg-base-100 p-4 mb-4 transition-all duration-500 animate-in overflow-hidden min-w-0" phx-remove={JS.add_class("animate-out")}>
      <div class="flex items-center justify-between mb-3 min-w-0">
        <h2 class="text-lg font-semibold text-base-content truncate">Product Detail</h2>
        <div class="flex items-center gap-1">
          <%= if @widget[:locked] do %>
            <span class="text-base-content/30" title="Locked">
              <.mat_icon name="lock" class="text-base" />
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
              <.mat_icon name="push_pin" filled={@widget[:pinned] == true} class="text-base" />
            </button>
            <button
              :if={!@widget[:pinned]}
              phx-click="widget_action"
              phx-value-widget-id={@id}
              phx-value-action="close"
              class="text-base-content/40 hover:text-base-content/60 transition"
            >
              <.mat_icon name="close" class="text-lg" />
            </button>
          <% end %>
        </div>
      </div>

      <div :if={@loading} class="flex gap-4 min-w-0">
        <div class="skeleton-pulse w-48 h-36 rounded-lg shrink-0"></div>
        <div class="flex-1 min-w-0 space-y-3">
          <div class="skeleton-pulse h-6 w-2/3"></div>
          <div class="skeleton-pulse h-8 w-24"></div>
          <div class="skeleton-pulse h-4 w-full"></div>
          <div class="skeleton-pulse h-4 w-4/5"></div>
          <div class="grid grid-cols-2 gap-2 mt-3">
            <div :for={_ <- 1..4} class="skeleton-pulse h-3 w-full"></div>
          </div>
        </div>
      </div>

      <div :if={!@loading && @has_data} class="flex gap-4 min-w-0 overflow-hidden">
        <img
          src={get_field(@product, :image)}
          alt={get_field(@product, :name)}
          class="w-48 h-36 object-cover rounded-lg bg-base-200 shrink-0"
        />
        <div class="flex-1 min-w-0 overflow-hidden">
          <h3 class="text-xl font-bold text-base-content truncate">{get_field(@product, :name)}</h3>
          <p class="text-2xl font-bold text-primary mt-1">${format_price(get_field(@product, :price))}</p>
          <p class="text-sm text-base-content/50 mt-2 line-clamp-3 break-words">{get_field(@product, :description)}</p>
          <div class="flex items-center gap-1 mt-2">
            <.mat_icon name="star" filled class="text-sm text-warning" />
            <span class="text-sm font-medium text-base-content">{get_field(@product, :rating)}</span>
            <span class="text-xs text-base-content/40 ml-2 truncate">{get_field(@product, :category)}</span>
          </div>
          <div :if={get_field(@product, :specs)} class="mt-3 grid grid-cols-2 gap-2 overflow-hidden">
            <div :for={{k, v} <- specs_list(@product)} class="text-xs min-w-0 overflow-hidden">
              <span class="text-base-content/40">{format_key(k)}</span>
              <span class="text-base-content/70 font-medium ml-1 truncate">{v}</span>
            </div>
          </div>
          <div class="flex items-center gap-2 mt-3">
            <button
              phx-click="widget_action"
              phx-value-widget-id={@id}
              phx-value-action="add_to_cart"
              class="btn btn-primary btn-sm gap-1"
            >
              <.mat_icon name="add_shopping_cart" class="text-sm" />
              Add to cart
            </button>
            <button
              phx-click="widget_action"
              phx-value-widget-id={@id}
              phx-value-action="add_to_wishlist"
              class={[
                "btn btn-sm btn-ghost gap-1",
                if(@in_wishlist, do: "text-secondary", else: "text-base-content/40")
              ]}
              title={if(@in_wishlist, do: "Saved to wishlist", else: "Save to wishlist")}
            >
              <.mat_icon name="bookmark" filled={@in_wishlist} class="text-sm" />
              {if(@in_wishlist, do: "Saved", else: "Save")}
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp get_field(data, key) do
    Map.get(data, key) || Map.get(data, to_string(key))
  end

  defp specs_list(product) do
    specs = get_field(product, :specs) || %{}

    Enum.map(specs, fn {k, v} -> {k, v} end)
  end

  defp format_key(k) when is_atom(k), do: k |> to_string() |> format_key()

  defp format_key(k) when is_binary(k) do
    k |> String.replace("_", " ") |> String.capitalize()
  end

  defp format_price(nil), do: "0.00"
  defp format_price(p) when is_float(p), do: :erlang.float_to_binary(p, decimals: 2)
  defp format_price(p), do: "#{p}"
end
