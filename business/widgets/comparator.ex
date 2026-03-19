defmodule AgenticUi.Business.Widgets.Comparator do
  use Phoenix.Component
  alias Phoenix.LiveView.JS
  import AgenticUiWeb.CoreComponents, only: [mat_icon: 1]

  attr :id, :string, required: true
  attr :widget, :map, required: true

  def render(assigns) do
    data = assigns.widget[:data] || %{}
    products = data["products"] || data[:products] || []

    assigns = assign(assigns, :products, products)

    ~H"""
    <div class="rounded-xl border border-base-300 bg-base-100 p-4 mb-4 transition-all duration-500 animate-in overflow-hidden min-w-0" phx-remove={JS.add_class("animate-out")}>
      <div class="flex items-center justify-between mb-4 min-w-0">
        <h2 class="text-lg font-semibold text-base-content truncate">Product Comparison</h2>
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

      <div :if={@products == []} class="text-center py-8 text-base-content/40">
        No products to compare.
      </div>

      <div :if={@products != []} class="overflow-x-auto">
        <table class="w-full text-sm">
          <thead>
            <tr>
              <th class="text-left p-2 text-base-content/50 font-medium"></th>
              <th :for={p <- @products} class="p-2 text-center min-w-[160px]">
                <img
                  src={p["image"] || p[:image]}
                  alt={p["name"] || p[:name]}
                  class="w-24 h-16 object-cover rounded-md mx-auto mb-2 bg-base-200"
                />
                <div class="font-semibold text-base-content">{p["name"] || p[:name]}</div>
              </th>
            </tr>
          </thead>
          <tbody>
            <tr class="border-t border-base-300">
              <td class="p-2 text-base-content/50 font-medium">Price</td>
              <td :for={p <- @products} class="p-2 text-center font-bold text-primary">
                ${format_price(p["price"] || p[:price])}
              </td>
            </tr>
            <tr class="border-t border-base-300 bg-base-200">
              <td class="p-2 text-base-content/50 font-medium">Rating</td>
              <td :for={p <- @products} class="p-2 text-center text-base-content">
                <.mat_icon name="star" filled class="text-sm text-warning" /> {p["rating"] || p[:rating]}
              </td>
            </tr>
            <tr class="border-t border-base-300">
              <td class="p-2 text-base-content/50 font-medium">Category</td>
              <td :for={p <- @products} class="p-2 text-center text-base-content/60">
                {p["category"] || p[:category]}
              </td>
            </tr>
            <%= for spec_key <- spec_keys(@products) do %>
              <tr class="border-t border-base-300">
                <td class="p-2 text-base-content/50 font-medium">{format_key(spec_key)}</td>
                <td :for={p <- @products} class="p-2 text-center text-base-content/70">
                  {get_spec(p, spec_key)}
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  defp spec_keys(products) do
    products
    |> Enum.flat_map(fn p ->
      specs = p["specs"] || p[:specs] || %{}
      Map.keys(specs)
    end)
    |> Enum.uniq()
  end

  defp get_spec(product, key) do
    specs = product["specs"] || product[:specs] || %{}
    Map.get(specs, key) || Map.get(specs, to_string(key)) || "-"
  end

  defp format_key(k) when is_atom(k), do: k |> to_string() |> format_key()

  defp format_key(k) when is_binary(k) do
    k |> String.replace("_", " ") |> String.capitalize()
  end

  defp format_price(nil), do: "0.00"
  defp format_price(p) when is_float(p), do: :erlang.float_to_binary(p, decimals: 2)
  defp format_price(p), do: "#{p}"
end
