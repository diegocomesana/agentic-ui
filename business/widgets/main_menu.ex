defmodule AgenticUi.Business.Widgets.MainMenu do
  use Phoenix.Component
  import AgenticUiWeb.CoreComponents, only: [mat_icon: 1]

  attr :id, :string, required: true
  attr :widget, :map, required: true

  @buttons [
    %{action: "open_search", icon: "search", label: "Search"},
    %{action: "open_categories", icon: "category", label: "Categories"},
    %{action: "open_cart", icon: "shopping_cart", label: "Cart"},
    %{action: "open_wishlist", icon: "favorite", label: "Wishlist"}
  ]

  def render(assigns) do
    assigns = assign(assigns, :buttons, @buttons)

    ~H"""
    <div class="rounded-xl border border-base-300 bg-base-100 mb-4 overflow-hidden min-w-0">
      <div class="flex items-center justify-between px-3 py-2">
        <nav class="flex items-center gap-1">
          <button
            :for={btn <- @buttons}
            phx-click="widget_action"
            phx-value-widget-id={@id}
            phx-value-action={btn.action}
            class="btn btn-ghost btn-sm gap-1.5 text-base-content/70 hover:text-base-content"
          >
            <.mat_icon name={btn.icon} class="text-lg" />
            <span class="text-xs font-medium hidden sm:inline">{btn.label}</span>
          </button>
        </nav>

        <div class="flex items-center gap-1 shrink-0">
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
    </div>
    """
  end
end
