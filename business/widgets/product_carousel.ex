defmodule AgenticUi.Business.Widgets.ProductCarousel do
  use Phoenix.Component
  alias Phoenix.LiveView.JS
  import AgenticUiWeb.CoreComponents, only: [mat_icon: 1]

  attr :id, :string, required: true
  attr :widget, :map, required: true

  def render(assigns) do
    data = assigns.widget[:data] || %{}
    items = data[:items] || data["items"] || []
    page = data[:page] || data["page"] || 1
    total_pages = data[:total_pages] || data["total_pages"] || 1
    loading = assigns.widget[:loading] || false
    config = assigns.widget[:config] || %{}
    category = config["category"] || config[:category] || "all"
    query = config["query"] || config[:query] || ""
    filters_open = config["filters_open"] == true

    min_price = get_num(config, "min_price", 0)
    max_price = get_num(config, "max_price", 10000)
    min_rating = get_num(config, "min_rating", 0)
    sort_by = config["sort_by"] || "rating"
    sort_order = config["sort_order"] || "desc"
    filter_count = active_filter_count(config)

    assigns =
      assigns
      |> assign(:items, items)
      |> assign(:page, page)
      |> assign(:total_pages, total_pages)
      |> assign(:loading, loading)
      |> assign(:category, category)
      |> assign(:query, query)
      |> assign(:filters_open, filters_open)
      |> assign(:min_price, min_price)
      |> assign(:max_price, max_price)
      |> assign(:min_rating, min_rating)
      |> assign(:sort_by, sort_by)
      |> assign(:sort_order, sort_order)
      |> assign(:filter_count, filter_count)

    ~H"""
    <div class="rounded-xl border border-base-300 bg-base-100 p-4 mb-4 transition-all duration-500 animate-in overflow-hidden min-w-0" phx-remove={JS.add_class("animate-out")}>
      <div class="flex items-center justify-between mb-3 min-w-0">
        <h2 class="text-lg font-semibold text-base-content truncate min-w-0">
          <.mat_icon name="view_carousel" class="text-lg text-base-content/40 mr-1" />
          Products
          <span :if={@query != ""} class="text-sm font-normal text-base-content/50 ml-2">
            — "{@query}"
          </span>
          <span :if={@query == "" && @category != "all"} class="text-sm font-normal text-base-content/50 ml-2">
            ({@category})
          </span>
        </h2>
        <div class="flex items-center gap-1">
          <%!-- Filters toggle --%>
          <button
            phx-click="widget_action"
            phx-value-widget-id={@id}
            phx-value-action="toggle_filters"
            class={[
              "flex items-center gap-1 px-2 py-0.5 rounded transition text-xs",
              if(@filters_open || @filter_count > 0, do: "text-primary", else: "text-base-content/40 hover:text-base-content/60")
            ]}
          >
            <.mat_icon name="tune" class="text-sm" />
            <span :if={@filter_count > 0 && !@filters_open} class="bg-primary text-primary-content text-[10px] px-1.5 rounded-full font-bold">
              {@filter_count}
            </span>
          </button>

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

      <%!-- Collapsible filters panel --%>
      <form :if={@filters_open} phx-submit="widget_action" phx-value-widget-id={@id} phx-value-action="apply_filters" class="mb-3 px-3 py-3 bg-base-200/30 border border-base-300 rounded-lg">
        <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
          <%!-- Price range --%>
          <div>
            <label class="text-xs text-base-content/50 mb-1.5 block">Price range</label>
            <div class="flex items-center gap-2">
              <input
                type="number"
                name="filter_min_price"
                value={@min_price}
                min="0"
                step="10"
                class="w-full px-2 py-1.5 rounded-md border border-base-300 text-xs text-base-content bg-base-100 focus:border-primary outline-none"
                placeholder="Min"
              />
              <span class="text-xs text-base-content/30">—</span>
              <input
                type="number"
                name="filter_max_price"
                value={@max_price}
                min="0"
                step="10"
                class="w-full px-2 py-1.5 rounded-md border border-base-300 text-xs text-base-content bg-base-100 focus:border-primary outline-none"
                placeholder="Max"
              />
            </div>
          </div>

          <%!-- Min rating --%>
          <div>
            <label class="text-xs text-base-content/50 mb-1.5 block">
              Min rating: <span class="font-medium text-base-content">{@min_rating}</span>
            </label>
            <input
              type="range"
              name="filter_min_rating"
              value={@min_rating}
              min="0"
              max="5"
              step="0.5"
              class="range range-xs range-primary w-full"
              phx-change="widget_action"
              phx-value-widget-id={@id}
              phx-value-action="update_filter_preview"
            />
            <div class="flex justify-between text-[10px] text-base-content/30 px-0.5">
              <span>0</span><span>1</span><span>2</span><span>3</span><span>4</span><span>5</span>
            </div>
          </div>

          <%!-- Sort --%>
          <div>
            <label class="text-xs text-base-content/50 mb-1.5 block">Sort by</label>
            <div class="flex gap-2">
              <select name="filter_sort_by" class="select select-xs bg-base-100 flex-1 min-w-0">
                <option value="rating" selected={@sort_by == "rating"}>Rating</option>
                <option value="price" selected={@sort_by == "price"}>Price</option>
                <option value="title" selected={@sort_by == "title"}>Name</option>
              </select>
              <select name="filter_sort_order" class="select select-xs bg-base-100 w-20">
                <option value="desc" selected={@sort_order == "desc"}>Desc</option>
                <option value="asc" selected={@sort_order == "asc"}>Asc</option>
              </select>
            </div>
          </div>
        </div>

        <%!-- Apply / Reset buttons --%>
        <div class="flex gap-2 mt-3 justify-end">
          <button
            type="button"
            phx-click="widget_action"
            phx-value-widget-id={@id}
            phx-value-action="reset_filters"
            class="btn btn-ghost btn-xs"
          >
            Reset
          </button>
          <button type="submit" class="btn btn-primary btn-xs">
            <.mat_icon name="filter_list" class="text-sm" />
            Apply
          </button>
        </div>
      </form>

      <%!-- Loading skeleton --%>
      <div :if={@loading} class="flex gap-3 overflow-hidden">
        <div :for={_ <- 1..4} class="flex-shrink-0 w-44">
          <div class="skeleton-pulse w-full h-28 rounded-md mb-2"></div>
          <div class="skeleton-pulse h-3 w-3/4 mb-1"></div>
          <div class="skeleton-pulse h-3 w-16"></div>
        </div>
      </div>

      <%!-- Empty state --%>
      <div :if={!@loading && @items == []} class="text-center py-8 text-base-content/40">
        No products found.
      </div>

      <%!-- Carousel --%>
      <div :if={!@loading && @items != []} class="relative group">
        <%!-- Prev arrow --%>
        <button
          :if={@page > 1}
          phx-click="widget_action"
          phx-value-widget-id={@id}
          phx-value-action="prev_page"
          class="absolute left-0 top-1/2 -translate-y-1/2 z-10 w-8 h-8 flex items-center justify-center rounded-full bg-base-100/90 border border-base-300 shadow-md hover:bg-base-200 transition opacity-0 group-hover:opacity-100"
        >
          <.mat_icon name="chevron_left" class="text-lg" />
        </button>

        <%!-- Scrollable track --%>
        <div class="flex gap-3 overflow-x-auto scrollbar-hide pb-2 scroll-smooth">
          <div
            :for={item <- @items}
            class="flex-shrink-0 w-44 border border-base-300 rounded-lg p-2.5 hover:shadow-md transition cursor-pointer group/card"
            phx-click="widget_action"
            phx-value-widget-id={@id}
            phx-value-action="select_product"
            phx-value-product-id={item.id || item["id"]}
          >
            <img
              src={item.image || item["image"]}
              alt={item.name || item["name"]}
              class="w-full h-28 object-cover rounded-md mb-2 bg-base-200"
            />
            <h3 class="font-medium text-xs text-base-content group-hover/card:text-primary transition truncate">
              {item.name || item["name"]}
            </h3>
            <div class="flex items-center justify-between mt-1">
              <span class="text-primary font-bold text-sm">
                ${format_price(item.price || item["price"])}
              </span>
              <span class="text-xs text-base-content/40 flex items-center gap-0.5">
                <.mat_icon name="star" filled class="text-xs text-warning" />
                {item.rating || item["rating"]}
              </span>
            </div>
            <button
              phx-click="widget_action"
              phx-value-widget-id={@id}
              phx-value-action="add_to_cart"
              phx-value-product-id={item.id || item["id"]}

              class="w-full mt-1.5 py-0.5 text-[10px] font-medium rounded bg-primary/10 text-primary hover:bg-primary hover:text-primary-content transition flex items-center justify-center gap-0.5"
            >
              <.mat_icon name="add_shopping_cart" class="text-xs" />
              Add
            </button>
          </div>
        </div>

        <%!-- Next arrow --%>
        <button
          :if={@page < @total_pages}
          phx-click="widget_action"
          phx-value-widget-id={@id}
          phx-value-action="next_page"
          class="absolute right-0 top-1/2 -translate-y-1/2 z-10 w-8 h-8 flex items-center justify-center rounded-full bg-base-100/90 border border-base-300 shadow-md hover:bg-base-200 transition opacity-0 group-hover:opacity-100"
        >
          <.mat_icon name="chevron_right" class="text-lg" />
        </button>
      </div>

      <%!-- Page indicator --%>
      <div :if={@total_pages > 1} class="flex justify-center items-center gap-2 mt-2 text-xs text-base-content/40">
        <span>{@page}/{@total_pages}</span>
      </div>
    </div>
    """
  end

  defp format_price(nil), do: "0.00"
  defp format_price(p) when is_float(p), do: :erlang.float_to_binary(p, decimals: 2)
  defp format_price(p) when is_integer(p), do: "#{p}.00"
  defp format_price(p), do: "#{p}"

  defp get_num(config, key, default) do
    val = config[key]
    case val do
      nil -> default
      v when is_number(v) -> v
      v when is_binary(v) ->
        case Float.parse(v) do
          {n, _} -> n
          :error -> default
        end
      _ -> default
    end
  end

  defp active_filter_count(config) do
    count = 0
    count = if get_num(config, "min_price", 0) > 0, do: count + 1, else: count
    count = if get_num(config, "max_price", 10000) < 10000, do: count + 1, else: count
    count = if get_num(config, "min_rating", 0) > 0, do: count + 1, else: count
    count = if (config["sort_by"] || "rating") != "rating", do: count + 1, else: count
    count = if (config["sort_order"] || "desc") != "desc", do: count + 1, else: count
    count
  end
end
