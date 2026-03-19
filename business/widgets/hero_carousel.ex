defmodule AgenticUi.Business.Widgets.HeroCarousel do
  use Phoenix.Component
  alias Phoenix.LiveView.JS
  import AgenticUiWeb.CoreComponents, only: [mat_icon: 1]

  attr :id, :string, required: true
  attr :widget, :map, required: true

  def render(assigns) do
    data = assigns.widget[:data] || %{}
    products = data[:items] || data["items"] || data[:products] || data["products"] || []
    config = assigns.widget[:config] || %{}
    interval = config["interval"] || config[:interval] || 5000
    loading = assigns.widget[:loading] || false

    assigns =
      assigns
      |> assign(:products, products)
      |> assign(:interval, interval)
      |> assign(:loading, loading)
      |> assign(:count, length(products))

    ~H"""
    <div
      class="rounded-2xl mb-4 transition-all duration-500 animate-in relative overflow-hidden min-w-0 h-56"
      phx-remove={JS.add_class("animate-out")}
      id={"carousel-#{@id}"}
      phx-hook="HeroCarousel"
      data-interval={@interval}
    >
      <%!-- Controls (top-right) --%>
      <div class="absolute top-3 right-3 flex items-center gap-1 z-10">
        <%= if @widget[:locked] do %>
          <span class="w-7 h-7 flex items-center justify-center rounded-full bg-white/20 text-white/50" title="Locked">
            <.mat_icon name="lock" class="text-sm" />
          </span>
        <% else %>
          <button
            phx-click="widget_action"
            phx-value-widget-id={@id}
            phx-value-action="toggle_pin"
            class={[
              "w-7 h-7 flex items-center justify-center rounded-full transition",
              if(@widget[:pinned], do: "bg-white/30 text-white", else: "bg-white/20 text-white/50 hover:bg-white/30 hover:text-white/80")
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
            class="w-7 h-7 flex items-center justify-center rounded-full bg-white/20 hover:bg-white/40 text-white/70 hover:text-white transition"
          >
            <.mat_icon name="close" class="text-base" />
          </button>
        <% end %>
      </div>

      <%!-- Loading state --%>
      <div :if={@loading} class="absolute inset-0 skeleton-pulse rounded-2xl"></div>

      <%!-- Slides --%>
      <div :if={!@loading && @products != []} class="carousel-track flex h-full transition-transform duration-700 ease-in-out">
        <div
          :for={product <- @products}
          class="carousel-slide flex-shrink-0 w-full h-full relative cursor-pointer"
          phx-click="widget_action"
          phx-value-widget-id={@id}
          phx-value-action="select_product"
          phx-value-product-id={product[:id] || product["id"]}
        >
          <img
            src={product[:image] || product["image"]}
            alt={product[:name] || product["name"]}
            class="absolute inset-0 w-full h-full object-cover"
          />
          <div class="absolute inset-0 bg-gradient-to-r from-black/70 via-black/40 to-transparent"></div>
          <div class="relative z-[1] h-full flex flex-col justify-end p-8 text-white">
            <span class="text-xs uppercase tracking-wider opacity-70 mb-1">
              {product[:category] || product["category"]}
            </span>
            <h2 class="text-2xl font-bold mb-1 drop-shadow-lg truncate">
              {product[:name] || product["name"]}
            </h2>
            <div class="flex items-center gap-3">
              <span class="text-xl font-bold drop-shadow">
                ${format_price(product[:price] || product["price"])}
              </span>
              <span class="flex items-center gap-1 text-sm opacity-80">
                <.mat_icon name="star" filled class="text-sm text-warning" />
                {product[:rating] || product["rating"]}
              </span>
            </div>
          </div>
        </div>
      </div>

      <%!-- Empty --%>
      <div :if={!@loading && @products == []} class="flex items-center justify-center h-full bg-base-300 text-base-content/40">
        No products to showcase.
      </div>

      <%!-- Navigation arrows --%>
      <button
        :if={@count > 1}
        class="absolute left-3 top-1/2 -translate-y-1/2 z-10 w-8 h-8 flex items-center justify-center rounded-full bg-black/30 hover:bg-black/50 text-white transition"
        phx-click={JS.dispatch("carousel:prev", to: "#carousel-#{@id}")}
      >
        <.mat_icon name="chevron_left" class="text-lg" />
      </button>
      <button
        :if={@count > 1}
        class="absolute right-3 top-1/2 -translate-y-1/2 z-10 w-8 h-8 flex items-center justify-center rounded-full bg-black/30 hover:bg-black/50 text-white transition"
        phx-click={JS.dispatch("carousel:next", to: "#carousel-#{@id}")}
      >
        <.mat_icon name="chevron_right" class="text-lg" />
      </button>

      <%!-- Dots indicator --%>
      <div :if={@count > 1} class="absolute bottom-3 left-1/2 -translate-x-1/2 z-10 flex gap-1.5">
        <div :for={_ <- @products} class="carousel-dot w-2 h-2 rounded-full bg-white/40 transition-all"></div>
      </div>
    </div>
    """
  end

  defp format_price(nil), do: "0.00"
  defp format_price(p) when is_float(p), do: :erlang.float_to_binary(p, decimals: 2)
  defp format_price(p) when is_integer(p), do: "#{p}.00"
  defp format_price(p), do: "#{p}"
end
