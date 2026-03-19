defmodule AgenticUi.Business.Widgets.TopProducts do
  use Phoenix.Component
  alias Phoenix.LiveView.JS
  import AgenticUiWeb.CoreComponents, only: [mat_icon: 1]

  attr :id, :string, required: true
  attr :widget, :map, required: true

  def render(assigns) do
    data = assigns.widget[:data] || %{}
    items = data[:items] || data["items"] || []
    loading = assigns.widget[:loading] || false
    config = assigns.widget[:config] || %{}
    category = config["category"] || config[:category]

    assigns =
      assigns
      |> assign(:items, items)
      |> assign(:loading, loading)
      |> assign(:category, category)

    ~H"""
    <div class="rounded-xl border border-base-300 bg-base-100 p-4 mb-4 transition-all duration-500 animate-in overflow-hidden min-w-0" phx-remove={JS.add_class("animate-out")}>
      <div class="flex items-center justify-between mb-3 min-w-0">
        <h2 class="text-lg font-semibold text-base-content truncate min-w-0 flex items-center gap-1.5">
          <.mat_icon name="emoji_events" class="text-lg text-warning" />
          Top Rated
          <span :if={@category} class="text-sm font-normal text-base-content/50">
            in {@category}
          </span>
        </h2>
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

      <%!-- Loading skeleton --%>
      <div :if={@loading} class="space-y-2">
        <div :for={_ <- 1..5} class="flex items-center gap-3 p-2">
          <div class="skeleton-pulse w-6 h-6 rounded-full shrink-0"></div>
          <div class="skeleton-pulse w-10 h-10 rounded-md shrink-0"></div>
          <div class="flex-1 space-y-1">
            <div class="skeleton-pulse h-3 w-3/4"></div>
            <div class="skeleton-pulse h-3 w-1/3"></div>
          </div>
        </div>
      </div>

      <%!-- Empty state --%>
      <div :if={!@loading && @items == []} class="text-center py-8 text-base-content/40">
        No products found.
      </div>

      <%!-- Ranked list --%>
      <div :if={!@loading && @items != []} class="space-y-1">
        <div
          :for={{item, idx} <- Enum.with_index(@items)}
          class="flex items-center gap-3 p-2 rounded-lg hover:bg-base-200/50 transition cursor-pointer group"
          phx-click="widget_action"
          phx-value-widget-id={@id}
          phx-value-action="select_product"
          phx-value-product-id={item.id || item["id"]}
        >
          <%!-- Rank badge --%>
          <div class={[
            "w-6 h-6 rounded-full flex items-center justify-center text-xs font-bold shrink-0",
            rank_class(idx)
          ]}>
            {idx + 1}
          </div>

          <%!-- Thumbnail --%>
          <img
            src={item.image || item["image"]}
            alt={item.name || item["name"]}
            class="w-10 h-10 object-cover rounded-md bg-base-200 shrink-0"
          />

          <%!-- Info --%>
          <div class="flex-1 min-w-0">
            <h3 class="text-sm font-medium text-base-content group-hover:text-primary transition truncate">
              {item.name || item["name"]}
            </h3>
            <div class="flex items-center gap-2 text-xs text-base-content/50">
              <span class="flex items-center gap-0.5">
                <.mat_icon name="star" filled class="text-xs text-warning" />
                {item.rating || item["rating"]}
              </span>
              <span class="text-primary font-semibold">
                ${format_price(item.price || item["price"])}
              </span>
            </div>
          </div>

          <%!-- Cart button --%>
          <button
            phx-click="widget_action"
            phx-value-widget-id={@id}
            phx-value-action="add_to_cart"
            phx-value-product-id={item.id || item["id"]}

            class="shrink-0 p-1.5 rounded-md bg-primary/10 text-primary hover:bg-primary hover:text-primary-content transition"
            title="Add to cart"
          >
            <.mat_icon name="add_shopping_cart" class="text-sm" />
          </button>
        </div>
      </div>
    </div>
    """
  end

  defp rank_class(0), do: "bg-warning/20 text-warning"
  defp rank_class(1), do: "bg-base-content/10 text-base-content/60"
  defp rank_class(2), do: "bg-warning/10 text-warning/70"
  defp rank_class(_), do: "bg-base-200 text-base-content/40"

  defp format_price(nil), do: "0.00"
  defp format_price(p) when is_float(p), do: :erlang.float_to_binary(p, decimals: 2)
  defp format_price(p) when is_integer(p), do: "#{p}.00"
  defp format_price(p), do: "#{p}"
end
