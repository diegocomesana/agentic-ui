defmodule AgenticUi.Business.UiConfig do
  @moduledoc """
  UI configuration for the Agentic UI framework.

  Edit the values below to customize branding, labels, and messages
  without touching any framework files.

  For full structural overrides, uncomment and implement the component
  functions at the bottom (header/1, empty_state/1).
  """
  use Phoenix.Component

  def config do
    %{
      branding: %{
        app_name: "Agentic UI",
        page_title: "Agentic UI",
        logo: nil,
        powered_by: %{
          text: "by",
          name: "Argentic",
          link: "https://argentic.net"
        }
      },
      header: %{
        show_agent_toggle: true,
        show_reset_button: true,
        show_theme_toggle: true,
        show_debug_toggle: true,
        agent_online_label: "Agent online",
        agent_offline_label: "Manual mode",
        agent_enable_tooltip: "Click to enable agent",
        agent_disable_tooltip: "Click to disable agent",
        reset_tooltip: "Reset layout",
        show_reset_all_button: true,
        reset_all_tooltip: "Clear everything and start fresh"
      },
      chat: %{
        title: "Chat",
        help_text: "Ask me to show products, compare items, or explore categories",
        placeholder: "Type a message...",
        thinking_text: "Thinking...",
        send_label: "Send",
        voice_label: "Voice input"
      },
      empty_state: %{
        icon: "shopping_bag",
        heading: "Welcome to Agentic UI",
        message_agent_on:
          "Start chatting to explore products and see dynamic widgets appear here.",
        message_agent_off:
          "Browse products using the widgets below. Enable the agent for AI-powered assistance."
      },
      state_summarizer: AgenticUi.Business.StateSummarizer,
      errors: %{
        quota_exceeded:
          "OpenAI API quota exceeded. Please check your billing at platform.openai.com.",
        rate_limited: "Too many requests. Please wait a moment and try again.",
        rate_limited_generic:
          "The AI service is temporarily unavailable (rate limited). Please try again shortly.",
        service_unavailable:
          "The AI service is temporarily unavailable. Please try again in a moment.",
        invalid_api_key: "Invalid API key. Please check your OpenAI configuration.",
        network_error:
          "Network error connecting to the AI service. Please check your internet connection.",
        tool_loop_limit:
          "The agent took too many steps processing your request. Please try a simpler query.",
        empty_response: "The AI service returned an empty response. Please try again.",
        generic: "Something went wrong. Please try again."
      }
    }
  end

  # --- Component overrides (optional) ---
  #
  # Uncomment to fully replace the default header with your own layout.
  # Receives assigns: agent_enabled, theme, debug, ui (config map).
  #
  # Use HeaderComponents to keep framework functionality:
  #   <HC.agent_toggle />  — agent on/off with status dot
  #   <HC.reset_button />  — reset layout button
  #   <HC.theme_toggle />  — light/dark/system cycle
  #   <HC.debug_toggle />  — debug panel toggle
  #   <HC.divider />       — vertical separator line
  #
  # Each component uses phx-click events handled by the framework,
  # so they work automatically in any layout you design.
  #
  # def header(assigns) do
  #   alias AgenticUiWeb.HeaderComponents, as: HC
  #
  #   ~H"""
  #   <header class="h-14 shrink-0 bg-neutral text-neutral-content flex items-center justify-between px-6">
  #     <div class="flex items-center gap-3">
  #       <img src="/images/my-logo.png" class="h-6" />
  #       <span class="font-bold">My Store</span>
  #     </div>
  #     <div class="flex items-center gap-3">
  #       <HC.agent_toggle agent_enabled={@agent_enabled} ui={@ui} />
  #       <HC.divider />
  #       <HC.theme_toggle theme={@theme} ui={@ui} />
  #       <HC.debug_toggle debug={@debug} ui={@ui} />
  #       <HC.reset_button ui={@ui} />
  #     </div>
  #   </header>
  #   """
  # end
  #
  # Uncomment to fully replace the empty state.
  # Receives: agent_enabled, ui (config map).
  #
  # def empty_state(assigns) do
  #   ~H"""
  #   <div class="text-center p-8">
  #     <h2>Custom empty state</h2>
  #   </div>
  #   """
  # end
end
