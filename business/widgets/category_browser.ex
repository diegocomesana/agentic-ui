defmodule AgenticUi.Business.Widgets.CategoryBrowser do
  use Phoenix.Component
  alias Phoenix.LiveView.JS
  import AgenticUiWeb.CoreComponents, only: [mat_icon: 1]

  attr :id, :string, required: true
  attr :widget, :map, required: true

  def render(assigns) do
    data = assigns.widget[:data] || %{}
    categories = data[:categories] || data["categories"] || []
    loading = assigns.widget[:loading] || false
    config = assigns.widget[:config] || %{}
    filter = config["filter"] || ""

    filtered =
      if filter == "" do
        categories
      else
        down = String.downcase(filter)
        Enum.filter(categories, &String.contains?(String.downcase(&1), down))
      end

    assigns =
      assigns
      |> assign(:categories, filtered)
      |> assign(:all_count, length(categories))
      |> assign(:loading, loading)
      |> assign(:filter, filter)

    ~H"""
    <div class="rounded-xl border border-base-300 bg-base-100 p-3 mb-4 transition-all duration-500 animate-in overflow-hidden min-w-0" phx-remove={JS.add_class("animate-out")}>
      <div class="flex items-center justify-between mb-2 min-w-0">
        <h2 class="text-sm font-semibold text-base-content truncate flex items-center gap-1.5">
          <.mat_icon name="category" class="text-base text-base-content/40" />
          Categories
          <span class="text-xs font-normal text-base-content/40">({@all_count})</span>
        </h2>
        <div class="flex items-center gap-1">
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

      <%!-- Search filter --%>
      <form phx-change="widget_action" phx-value-widget-id={@id} phx-value-action="filter_categories" class="mb-2">
        <div class="relative">
          <.mat_icon name="search" class="absolute left-2 top-1/2 -translate-y-1/2 text-sm text-base-content/30" />
          <input
            type="text"
            name="filter"
            value={@filter}
            placeholder="Filter categories..."
            autocomplete="off"
            phx-debounce="150"
            class="w-full pl-7 pr-2 py-1 rounded-md border border-base-300 focus:border-primary focus:ring-1 focus:ring-primary outline-none text-xs text-base-content bg-base-100"
          />
        </div>
      </form>

      <div :if={@loading} class="flex justify-center py-4">
        <div class="skeleton-pulse h-6 w-full rounded"></div>
      </div>

      <div :if={!@loading && @categories == []} class="text-center py-3 text-base-content/40 text-xs">
        No categories match.
      </div>

      <div :if={!@loading && @categories != []} class="flex flex-wrap gap-1.5">
        <button
          :for={cat <- @categories}
          phx-click="widget_action"
          phx-value-widget-id={@id}
          phx-value-action="select_category"
          phx-value-category={cat}
          class="px-2.5 py-1 rounded-md border border-base-300 hover:border-primary hover:bg-primary/5 transition-all cursor-pointer group text-xs"
        >
          <span class="font-medium text-base-content group-hover:text-primary transition capitalize">
            {cat}
          </span>
        </button>
      </div>
    </div>
    """
  end
end
