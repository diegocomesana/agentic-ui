defmodule AgenticUiWeb.WorkspaceLive do
  use AgenticUiWeb, :live_view
  require Logger

  alias AgenticUi.{AgentScheduler, Engine, Session, Store}
  alias AgenticUi.Business.DefaultState
  alias AgenticUi.Business.Descriptors.Registry, as: WidgetRegistry
  alias AgenticUi.Business.UiConfig
  alias AgenticUiWeb.Renderer
  alias AgenticUiWeb.HeaderComponents, as: HC

  @theme_order ~w(light dark system)
  @ui UiConfig.config()

  @impl true
  def mount(_params, session, socket) do
    guest_token = session["guest_token"]
    {store, guest_user_id} = load_store(guest_token)

    session_id = "session-#{:erlang.unique_integer([:positive])}"
    Session.load_or_create(session_id, store)

    store = Engine.resolve_initial_data(store, :agent_on)

    categories = AgenticUi.Business.Services.ProductService.categories()

    {:ok,
     assign(socket,
       session_id: session_id,
       guest_user_id: guest_user_id,
       store: store,
       scheduler: AgentScheduler.new(),
       debug: false,
       theme: "system",
       agent_enabled: true,
       page_title: @ui.branding.page_title,
       ui: @ui,
       categories: categories
     ), layout: false}
  end

  defp load_store(guest_token) when is_binary(guest_token) do
    if AgenticUi.Accounts.db_available?() do
      case AgenticUi.Accounts.find_or_create_guest(guest_token) do
        {:ok, guest} ->
          case AgenticUi.Accounts.load_session(guest.id) do
            {:ok, store_data} when store_data != %{} ->
              {Store.from_persistable(store_data), guest.id}

            _ ->
              {DefaultState.build_initial_store(), guest.id}
          end

        {:error, _} ->
          {DefaultState.build_initial_store(), nil}
      end
    else
      {DefaultState.build_initial_store(), nil}
    end
  end

  defp load_store(_), do: {DefaultState.build_initial_store(), nil}


  @impl true
  def render(assigns) do
    ordered = Renderer.ordered_widgets(assigns.store)
    direction = Renderer.layout_direction(assigns.store)
    model = Application.get_env(:agentic_ui, AgenticUi.Agent, []) |> Keyword.get(:model, "gpt-4o-mini")
    debug_json = if assigns.debug, do: Store.debug_serialize(assigns.store) |> Jason.encode!(pretty: true), else: ""

    assigns =
      assigns
      |> assign(:ordered_widgets, ordered)
      |> assign(:direction, direction)
      |> assign(:model, model)
      |> assign(:debug_json, debug_json)
      |> assign(:widget_count, map_size(assigns.store.widgets))
      |> assign(:message_count, length(assigns.store.conversation))

    ~H"""
    <div id="theme-root" class="flex flex-col h-screen bg-base-200" phx-hook="ThemeToggle">
      <%!-- Modals --%>
      <HC.reset_all_modal ui={@ui} />

      <%!-- Flash / toast notifications --%>
      <Layouts.flash_group flash={@flash} />

      <%!-- Global loading indicator --%>
      <div :if={AgentScheduler.busy?(@scheduler)} class="fixed top-0 left-0 right-0 h-0.5 z-50 overflow-hidden bg-primary/20">
        <div class="h-full w-1/3 bg-primary progress-bar-indeterminate"></div>
      </div>

      <%!-- Top bar (fixed) --%>
      <%= if function_exported?(UiConfig, :header, 1) do %>
        <%= apply(UiConfig, :header, [%{agent_enabled: @agent_enabled, theme: @theme, debug: @debug, ui: @ui, __changed__: nil}]) %>
      <% else %>
        <header class="h-12 shrink-0 bg-base-100 border-b border-base-300 flex items-center justify-between px-5">
          <div class="flex items-center gap-3">
            <a :if={@ui.branding[:logo]} href={@ui.branding.logo.link} target="_blank" rel="noopener noreferrer" class="hover:opacity-70 transition">
              <div
                class="h-5 w-[90px] bg-base-content"
                style={"mask-image: url('#{@ui.branding.logo.src}'); mask-size: contain; mask-repeat: no-repeat; -webkit-mask-image: url('#{@ui.branding.logo.src}'); -webkit-mask-size: contain; -webkit-mask-repeat: no-repeat;"}
                role="img"
                aria-label={@ui.branding.logo.alt}
              ></div>
            </a>
            <span class="text-sm font-semibold text-base-content tracking-tight">{@ui.branding.app_name}</span>
          </div>
          <div class="flex items-center gap-3">
            <HC.agent_toggle agent_enabled={@agent_enabled} ui={@ui} />
            <HC.divider :if={@ui.header.show_agent_toggle} />
            <HC.reset_button ui={@ui} />
            <HC.reset_all_button ui={@ui} />
            <HC.divider :if={@ui.header.show_reset_button || @ui.header.show_reset_all_button} />
            <HC.theme_toggle theme={@theme} ui={@ui} />
            <HC.divider :if={@ui.header.show_theme_toggle} />
            <HC.debug_toggle debug={@debug} ui={@ui} />
            <%!-- Powered by --%>
            <%= if @ui.branding[:powered_by] do %>
              <HC.divider />
              <span class="text-xs text-base-content/40">
                {@ui.branding.powered_by.text} <a href={@ui.branding.powered_by.link} target="_blank" rel="noopener noreferrer" class="text-base-content/50 hover:text-base-content/80 transition">{@ui.branding.powered_by.name}</a>
              </span>
            <% end %>
          </div>
        </header>
      <% end %>

      <%!-- Debug panel --%>
      <div :if={@debug} class="shrink-0 bg-gray-900 border-b border-gray-700 px-5 py-3">
        <div class="flex items-center gap-4 text-xs mb-2">
          <span class="text-green-400 font-bold tracking-wider">DEBUG</span>
          <span class="text-gray-400">mode: <span class="text-green-300">{if(@agent_enabled, do: "agent_on", else: "agent_off")}</span></span>
          <span class="text-gray-400">model: <span class="text-green-300">{@model}</span></span>
          <span class="text-gray-400">widgets: <span class="text-green-300">{@widget_count}</span></span>
          <span class="text-gray-400">messages: <span class="text-green-300">{@message_count}</span></span>
        </div>
        <pre class="text-green-400 text-xs font-mono bg-gray-950 rounded p-3 max-h-64 overflow-y-auto whitespace-pre-wrap">{@debug_json}</pre>
      </div>

      <%!-- Main content area --%>
      <div class="flex flex-1 min-h-0">
        <%!-- Chat panel (only when agent is enabled) --%>
        <div :if={@agent_enabled} class="w-[380px] shrink-0 border-r border-base-content/20 flex flex-col bg-base-100">
          <AgenticUiWeb.Widgets.Chat.render
            conversation={@store.conversation}
            thinking={AgentScheduler.busy?(@scheduler)}
            ui_config={@ui}
            chat_widgets={@store[:chat_widgets] || %{}}
          />
        </div>

        <%!-- Widgets area --%>
        <div class="flex-1 overflow-y-auto p-6">
          <div :if={@ordered_widgets == []} class="flex items-center justify-center h-full">
            <%= if function_exported?(UiConfig, :empty_state, 1) do %>
              <%= apply(UiConfig, :empty_state, [%{agent_enabled: @agent_enabled, ui: @ui, __changed__: nil}]) %>
            <% else %>
              <div class="text-center text-base-content/40">
                <.mat_icon name={@ui.empty_state.icon} class="text-6xl" />
                <h2 class="text-xl font-medium mb-2">{@ui.empty_state.heading}</h2>
                <p class="text-sm">
                  {if(@agent_enabled,
                    do: @ui.empty_state.message_agent_on,
                    else: @ui.empty_state.message_agent_off
                  )}
                </p>
              </div>
            <% end %>
          </div>

          <div class={[
            "space-y-4",
            if(@direction == "horizontal", do: "flex gap-4 space-y-0", else: "")
          ]}>
            <%= for {id, widget} <- @ordered_widgets do %>
              <div id={"widget-#{id}"} class={if(@direction == "horizontal", do: "flex-1 min-w-0", else: "")}>
                {render_widget(id, widget, %{categories: @categories, cart: @store[:cart] || [], wishlist: @store[:wishlist] || []})}
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Dynamic widget dispatch via descriptor registry
  defp render_widget(id, widget, extra) do
    assigns = Map.merge(%{id: id, widget: widget, __changed__: nil}, extra)
    type = widget[:widget]

    case WidgetRegistry.component_for(type) do
      nil ->
        ~H"""
        <div class="p-4 bg-yellow-50 border border-yellow-200 rounded-lg text-yellow-700 text-sm">
          Unknown widget type: {assigns.widget[:widget]}
        </div>
        """

      component_mod ->
        component_mod.render(assigns)
    end
  end

  # --- Event handlers ---

  @impl true
  def handle_event("toggle_agent", _params, socket) do
    new_enabled = !socket.assigns.agent_enabled
    mode = if new_enabled, do: :agent_on, else: :agent_off

    store = DefaultState.build_initial_store(mode, socket.assigns.store)
    store = Engine.resolve_initial_data(store, mode)

    Session.push_step(socket.assigns.session_id, store, socket.assigns.guest_user_id)

    {:noreply,
     socket
     |> assign(:agent_enabled, new_enabled)
     |> assign(:store, store)
     |> assign(:scheduler, AgentScheduler.reset(socket.assigns.scheduler))}
  end

  def handle_event("reset_layout", _params, socket) do
    mode = if socket.assigns.agent_enabled, do: :agent_on, else: :agent_off

    store = DefaultState.build_initial_store(mode, socket.assigns.store)
    store = Engine.resolve_initial_data(store, mode)

    Session.push_step(socket.assigns.session_id, store, socket.assigns.guest_user_id)

    {:noreply,
     socket
     |> assign(:store, store)
     |> assign(:scheduler, AgentScheduler.reset(socket.assigns.scheduler))}
  end

  def handle_event("reset_all", _params, socket) do
    mode = if socket.assigns.agent_enabled, do: :agent_on, else: :agent_off

    store = DefaultState.build_initial_store(mode)
    store = Engine.resolve_initial_data(store, mode)

    Session.push_step(socket.assigns.session_id, store, socket.assigns.guest_user_id)

    {:noreply,
     socket
     |> assign(:store, store)
     |> assign(:scheduler, AgentScheduler.reset(socket.assigns.scheduler))}
  end

  def handle_event("toggle_debug", _params, socket) do
    {:noreply, assign(socket, :debug, !socket.assigns.debug)}
  end

  def handle_event("cycle_theme", _params, socket) do
    current = socket.assigns.theme
    idx = Enum.find_index(@theme_order, &(&1 == current)) || 0
    next = Enum.at(@theme_order, rem(idx + 1, length(@theme_order)))
    {:noreply, socket |> assign(:theme, next) |> push_event("set_theme", %{theme: next})}
  end

  def handle_event("sync_theme", %{"theme" => theme}, socket) when theme in ~w(light dark system) do
    {:noreply, assign(socket, :theme, theme)}
  end

  def handle_event("send_message", %{"message" => ""}, socket), do: {:noreply, socket}

  def handle_event("send_message", %{"message" => message}, socket) do
    if not socket.assigns.agent_enabled do
      {:noreply, socket}
    else
      store = socket.assigns.store
      {:invoke_agent, context, store} = Engine.process_chat(message, store)
      log_state("send_message: \"#{String.slice(message, 0, 50)}\"", store)

      case AgentScheduler.request_invocation(socket.assigns.scheduler) do
        {:invoke, scheduler} ->
          {:noreply,
           socket
           |> assign(:store, store)
           |> assign(:scheduler, scheduler)
           |> launch_agent(context)}

        {:queued, scheduler} ->
          Logger.info("[SCHEDULER] queued: message while agent busy")

          {:noreply,
           socket
           |> assign(:store, store)
           |> assign(:scheduler, scheduler)}
      end
    end
  end

  @impl true
  def handle_event("widget_action", params, socket) do
    widget_id = params["widget-id"]
    action = params["action"]

    event_data =
      params
      |> Map.drop(["widget-id", "action"])
      |> Map.new(fn {k, v} -> {String.replace(k, "-", "_"), v} end)

    store = socket.assigns.store

    case Engine.process_widget_event(widget_id, action, event_data, store) do
      {:mechanical, {wid, call}, new_store} ->
        case Engine.execute_service_call(call, new_store) do
          {:ok, data} ->
            new_store = Store.set_widget_data(new_store, wid, data)
            scheduler = AgentScheduler.notify_state_changed(socket.assigns.scheduler)
            Session.push_step(socket.assigns.session_id, new_store, socket.assigns.guest_user_id)
            log_state("mechanical(#{action} on #{widget_id})", new_store)
            {:noreply, socket |> assign(:store, new_store) |> assign(:scheduler, scheduler)}

          {:error, err} ->
            Logger.warning("[STATE] mechanical service call failed: #{inspect(err)}")
            {:noreply, assign(socket, :store, new_store)}
        end

      {:mechanical, nil, new_store} ->
        scheduler = AgentScheduler.notify_state_changed(socket.assigns.scheduler)
        Session.push_step(socket.assigns.session_id, new_store, socket.assigns.guest_user_id)
        log_state("mechanical(#{action} on #{widget_id})", new_store)
        {:noreply, socket |> assign(:store, new_store) |> assign(:scheduler, scheduler)}

      {:semantic, context, new_store} ->
        if socket.assigns.agent_enabled do
          log_state("semantic(#{action} on #{widget_id})", new_store)

          case AgentScheduler.request_invocation(socket.assigns.scheduler) do
            {:invoke, scheduler} ->
              {:noreply,
               socket
               |> assign(:store, new_store)
               |> assign(:scheduler, scheduler)
               |> launch_agent(context)}

            {:queued, scheduler} ->
              Logger.info("[SCHEDULER] queued: semantic event while agent busy")
              {:noreply, socket |> assign(:store, new_store) |> assign(:scheduler, scheduler)}
          end
        else
          Logger.info("[STATE] semantic event ignored (agent off): #{action} on #{widget_id}")
          {:noreply, assign(socket, :store, new_store)}
        end
    end
  end

  @impl true
  def handle_info({ref, {:ok, agent_result}}, socket) when is_reference(ref) do
    Process.demonitor(ref, [:flush])

    Logger.info("[STATE] agent responded: message=#{String.slice(agent_result.message, 0, 80)} widgets=#{length(agent_result.widgets)}")

    case AgentScheduler.task_completed(socket.assigns.scheduler) do
      {:stale, _scheduler} ->
        Logger.info("[SCHEDULER] ignoring orphaned task result (scheduler was reset)")
        {:noreply, socket}

      {:reinvoke, scheduler} ->
        Logger.info("[SCHEDULER] discarding stale result, re-invoking with fresh state")
        store = socket.assigns.store
        context = %{store: store, conversation: store.conversation}

        {:noreply,
         socket
         |> assign(:scheduler, scheduler)
         |> launch_agent(context)}

      {:idle, scheduler} ->
        store = socket.assigns.store

        case Engine.apply_agent_response(store, agent_result) do
          {:ok, new_store} ->
            Session.push_step(socket.assigns.session_id, new_store, socket.assigns.guest_user_id)
            log_state("agent_applied (no data calls)", new_store)
            {:noreply, socket |> assign(:store, new_store) |> assign(:scheduler, scheduler)}

          {:resolve_data, data_calls, new_store} ->
            Logger.info("[STATE] resolving #{length(data_calls)} data call(s)")
            final_store = Engine.resolve_data(new_store, data_calls)
            Session.push_step(socket.assigns.session_id, final_store, socket.assigns.guest_user_id)
            log_state("agent_applied (data resolved)", final_store)
            {:noreply, socket |> assign(:store, final_store) |> assign(:scheduler, scheduler)}
        end
    end
  end

  def handle_info({ref, {:error, reason}}, socket) when is_reference(ref) do
    Process.demonitor(ref, [:flush])
    Logger.error("[STATE] agent error: #{inspect(reason)}")

    case AgentScheduler.task_completed(socket.assigns.scheduler) do
      {:stale, _scheduler} ->
        Logger.info("[SCHEDULER] ignoring orphaned error (scheduler was reset)")
        {:noreply, socket}

      {:reinvoke, _scheduler} ->
        # Don't reinvoke on error — network issues tend to persist.
        # Go idle and let the user retry manually.
        scheduler = AgentScheduler.new()
        Logger.warning("[SCHEDULER] agent error while dirty, going idle instead of re-invoking")

        {:noreply,
         socket
         |> put_flash(:error, friendly_error(reason))
         |> assign(:scheduler, scheduler)}

      {:idle, scheduler} ->
        {:noreply,
         socket
         |> put_flash(:error, friendly_error(reason))
         |> assign(:scheduler, scheduler)}
    end
  end

  def handle_info({:DOWN, _ref, :process, _pid, _reason}, socket) do
    case AgentScheduler.task_completed(socket.assigns.scheduler) do
      {:stale, _scheduler} ->
        {:noreply, socket}

      {:reinvoke, scheduler} ->
        store = socket.assigns.store
        context = %{store: store, conversation: store.conversation}

        {:noreply,
         socket
         |> assign(:scheduler, scheduler)
         |> launch_agent(context)}

      {:idle, scheduler} ->
        {:noreply, assign(socket, :scheduler, scheduler)}
    end
  end

  defp launch_agent(socket, context) do
    task = Task.async(fn -> AgenticUi.Agent.invoke(context) end)
    assign(socket, :agent_task, task)
  end

  defp log_state(label, store) do
    widgets =
      store.widgets
      |> Enum.map(fn {id, w} ->
        type = w[:widget] || "?"
        config = inspect(w[:config] || %{})
        has_data = w[:data] != nil and w[:data] != %{}
        "#{id}(#{type} cfg=#{config} data=#{has_data})"
      end)
      |> Enum.join(", ")

    layout_children =
      case store.layout do
        %{"children" => c} -> Enum.join(c, ", ")
        _ -> "none"
      end

    conv_count = length(store.conversation)

    Logger.info("""
    [STATE] #{label}
      widgets: [#{widgets}]
      layout:  [#{layout_children}]
      conversation: #{conv_count} messages
    """)
  end

  defp friendly_error({:api_error, 429, body}) do
    errors = @ui.errors

    cond do
      String.contains?(body, "insufficient_quota") -> errors.quota_exceeded
      String.contains?(body, "rate_limit") -> errors.rate_limited
      true -> errors.rate_limited_generic
    end
  end

  defp friendly_error({:api_error, code, _body}) when code in [500, 502, 503, 504] do
    @ui.errors.service_unavailable
  end

  defp friendly_error({:api_error, 401, _body}), do: @ui.errors.invalid_api_key
  defp friendly_error({:network_error, _reason}), do: @ui.errors.network_error
  defp friendly_error(:tool_loop_limit), do: @ui.errors.tool_loop_limit
  defp friendly_error(:empty_response), do: @ui.errors.empty_response
  defp friendly_error(_reason), do: @ui.errors.generic
end
