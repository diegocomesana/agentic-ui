defmodule AgenticUiWeb.HeaderComponents do
  @moduledoc """
  Reusable header building blocks.

  Use these in a custom `header/1` inside `business/ui_config.ex` to keep
  framework functionality (agent toggle, theme, debug, reset) while fully
  controlling layout and styling.

  ## Example — custom header

      def header(assigns) do
        import AgenticUiWeb.HeaderComponents

        ~H\"\"\"
        <header class="h-14 bg-black text-white flex items-center justify-between px-6">
          <div class="flex items-center gap-4">
            <img src="/images/my-logo.png" class="h-6" />
            <span class="font-bold">My Store</span>
          </div>
          <div class="flex items-center gap-3">
            <.agent_toggle agent_enabled={@agent_enabled} ui={@ui} />
            <.theme_toggle theme={@theme} ui={@ui} />
            <.debug_toggle debug={@debug} ui={@ui} />
            <.reset_button ui={@ui} />
          </div>
        </header>
        \"\"\"
      end
  """
  use Phoenix.Component
  import AgenticUiWeb.CoreComponents, only: [mat_icon: 1]

  @doc "Agent on/off toggle with status indicator dot."
  attr :agent_enabled, :boolean, required: true
  attr :ui, :map, required: true

  def agent_toggle(assigns) do
    ~H"""
    <button
      :if={@ui.header.show_agent_toggle}
      phx-click="toggle_agent"
      class="flex items-center gap-1.5 cursor-pointer hover:opacity-80 transition-opacity"
      title={if(@agent_enabled, do: @ui.header.agent_disable_tooltip, else: @ui.header.agent_enable_tooltip)}
    >
      <span class="relative flex h-2 w-2">
        <%= if @agent_enabled do %>
          <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-success opacity-75"></span>
          <span class="relative inline-flex rounded-full h-2 w-2 bg-success"></span>
        <% else %>
          <span class="relative inline-flex rounded-full h-2 w-2 bg-warning"></span>
        <% end %>
      </span>
      <span class={[
        "text-xs",
        if(@agent_enabled, do: "text-base-content/50", else: "text-warning")
      ]}>
        {if(@agent_enabled, do: @ui.header.agent_online_label, else: @ui.header.agent_offline_label)}
      </span>
    </button>
    """
  end

  @doc "Reset layout button."
  attr :ui, :map, required: true

  def reset_button(assigns) do
    ~H"""
    <button
      :if={@ui.header.show_reset_button}
      phx-click="reset_layout"
      class="w-7 h-7 flex items-center justify-center rounded text-base-content/40 hover:text-base-content/60 hover:bg-base-200 transition-colors"
      title={@ui.header.reset_tooltip}
    >
      <.mat_icon name="restart_alt" class="text-base" />
    </button>
    """
  end

  @doc "Full state reset button — opens confirmation modal."
  attr :ui, :map, required: true

  def reset_all_button(assigns) do
    ~H"""
    <button
      :if={@ui.header.show_reset_all_button}
      onclick="var d=document.getElementById('reset-all-modal');d.setAttribute('data-theme',document.documentElement.getAttribute('data-theme'));d.showModal()"
      class="w-7 h-7 flex items-center justify-center rounded text-base-content/40 hover:text-primary hover:bg-primary/10 transition-colors"
      title={@ui.header.reset_all_tooltip}
    >
      <.mat_icon name="delete_sweep" class="text-base" />
    </button>
    """
  end

  @doc "Confirmation modal for full state reset."
  attr :ui, :map, required: true

  def reset_all_modal(assigns) do
    ~H"""
    <dialog id="reset-all-modal" class="modal">
      <div class="modal-box max-w-sm bg-base-100 text-base-content">
        <h3 class="text-lg font-bold">Start fresh?</h3>
        <p class="py-4 text-sm text-base-content/70">
          This will clear your cart, wishlist, conversation and all widgets.
        </p>
        <div class="modal-action">
          <form method="dialog">
            <button class="btn btn-sm btn-ghost">Cancel</button>
          </form>
          <button
            phx-click="reset_all"
            onclick="document.getElementById('reset-all-modal').close()"
            class="btn btn-sm btn-primary"
          >
            Clear everything
          </button>
        </div>
      </div>
      <form method="dialog" class="modal-backdrop">
        <button>close</button>
      </form>
    </dialog>
    """
  end

  @doc "Theme cycle button (light/dark/system)."
  attr :theme, :string, required: true
  attr :ui, :map, required: true

  def theme_toggle(assigns) do
    ~H"""
    <button
      :if={@ui.header.show_theme_toggle}
      phx-click="cycle_theme"
      class="w-7 h-7 flex items-center justify-center rounded text-base-content/50 hover:text-base-content/80 hover:bg-base-200 transition-colors"
      title={"Theme: #{@theme}"}
    >
      <%= case @theme do %>
        <% "light" -> %>
          <.mat_icon name="light_mode" class="text-base" />
        <% "dark" -> %>
          <.mat_icon name="dark_mode" class="text-base" />
        <% _ -> %>
          <.mat_icon name="desktop_windows" class="text-base" />
      <% end %>
    </button>
    """
  end

  @doc "Debug panel toggle button."
  attr :debug, :boolean, required: true
  attr :ui, :map, required: true

  def debug_toggle(assigns) do
    ~H"""
    <button
      :if={@ui.header.show_debug_toggle}
      phx-click="toggle_debug"
      class={[
        "w-7 h-7 flex items-center justify-center rounded text-sm transition-colors",
        if(@debug, do: "bg-warning/20 text-warning", else: "text-base-content/40 hover:text-base-content/60 hover:bg-base-200")
      ]}
      title="Toggle debug panel"
    >
      <.mat_icon name="bug_report" class="text-base" />
    </button>
    """
  end

  @doc "Vertical divider line for separating header items."
  def divider(assigns) do
    ~H"""
    <div class="h-4 w-px bg-base-300"></div>
    """
  end
end
