defmodule AgenticUi.Business.Widgets.SearchBar do
  use Phoenix.Component
  alias Phoenix.LiveView.JS
  import AgenticUiWeb.CoreComponents, only: [mat_icon: 1]

  attr :id, :string, required: true
  attr :widget, :map, required: true

  def render(assigns) do
    config = assigns.widget[:config] || %{}
    placeholder = config["placeholder"] || config[:placeholder] || "Search products..."
    agent_mode = config["agent_mode"] == true

    assigns =
      assigns
      |> assign(:placeholder, placeholder)
      |> assign(:agent_mode, agent_mode)

    ~H"""
    <div class="rounded-xl border border-base-300 bg-base-100 p-3 mb-4 transition-all duration-500 animate-in overflow-hidden min-w-0" phx-remove={JS.add_class("animate-out")}>
      <div class="flex items-center gap-2 min-w-0">
        <form
          phx-submit="widget_action"
          phx-value-widget-id={@id}
          phx-value-action="submit_search"
          class="flex-1 flex items-center gap-2"
        >
          <div class="relative flex-1">
            <.mat_icon name="search" class="absolute left-3 top-1/2 -translate-y-1/2 text-lg text-base-content/30" />
            <input
              type="text"
              name="query"
              placeholder={@placeholder}
              autocomplete="off"
              class="w-full pl-10 pr-3 py-2.5 rounded-lg border border-base-300 focus:border-primary focus:ring-1 focus:ring-primary outline-none text-sm text-base-content bg-base-100"
            />
          </div>
          <button
            type="button"
            phx-click="widget_action"
            phx-value-widget-id={@id}
            phx-value-action="toggle_mode"
            class={[
              "btn btn-sm btn-square btn-ghost transition",
              if(@agent_mode, do: "text-primary", else: "text-base-content/40 hover:text-base-content/60")
            ]}
            title={if(@agent_mode, do: "Agent mode — click for direct results", else: "Direct results — click for agent mode")}
          >
            <.mat_icon name={if(@agent_mode, do: "chat", else: "grid_view")} class="text-lg" />
          </button>
          <button type="submit" class="btn btn-primary btn-sm">
            Search
          </button>
        </form>
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
