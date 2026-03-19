defmodule AgenticUiWeb.Widgets.Chat do
  use Phoenix.Component
  import AgenticUiWeb.CoreComponents, only: [mat_icon: 1]

  alias AgenticUi.Business.Descriptors.Registry

  attr :conversation, :list, required: true
  attr :thinking, :boolean, default: false
  attr :ui_config, :map, required: true
  attr :chat_widgets, :map, default: %{}

  def render(assigns) do
    ~H"""
    <div class="flex flex-col h-full bg-base-200">
      <div class="px-4 py-3 border-b border-base-300 bg-base-100">
        <h2 class="font-semibold text-base-content">{@ui_config.chat.title}</h2>
        <p class="text-xs text-base-content/40">{@ui_config.chat.help_text}</p>
      </div>

      <div id="chat-messages" class="flex-1 overflow-y-auto p-4 space-y-3" phx-hook="ScrollBottom">
        <div
          :for={msg <- @conversation}
          class={[
            if(msg.role == :user || msg.role == "user",
              do: "ml-auto max-w-[85%]",
              else: "mr-auto max-w-[85%]"
            )
          ]}
        >
          <div class={[
            "rounded-2xl px-4 py-2 text-sm",
            if(msg.role == :user || msg.role == "user",
              do: "bg-primary text-primary-content",
              else: "bg-base-100 text-base-content border border-base-300"
            )
          ]}>
            <.message_content content={msg.content} chat_widgets={@chat_widgets} />
            <div class={[
              "text-[10px] mt-1 flex items-center",
              if(msg.role == :user || msg.role == "user",
                do: "text-primary-content/50 justify-end gap-1.5",
                else: "text-base-content/30"
              )
            ]}>
              <button
                :if={msg.role == :user || msg.role == "user"}
                phx-click="send_message"
                phx-value-message={msg.content}
                class="text-primary-content/30 hover:text-primary-content/70 transition leading-none scale-[0.68]"
                title="Resend this message"
              >
                <.mat_icon name="replay" class="text-[10px]" />
              </button>
              <span>{format_timestamp(msg[:timestamp])}</span>
            </div>
          </div>
        </div>

        <div :if={@thinking} class="mr-auto bg-base-100 text-base-content/40 border border-base-300 rounded-2xl px-4 py-2 text-sm">
          <div class="flex items-center gap-2">
            <div class="flex gap-1">
              <div class="w-2 h-2 rounded-full bg-base-content/30 animate-bounce [animation-delay:-0.3s]"></div>
              <div class="w-2 h-2 rounded-full bg-base-content/30 animate-bounce [animation-delay:-0.15s]"></div>
              <div class="w-2 h-2 rounded-full bg-base-content/30 animate-bounce"></div>
            </div>
            <span>{@ui_config.chat.thinking_text}</span>
          </div>
        </div>
      </div>

      <form phx-submit="send_message" class="p-4 border-t border-base-300 bg-base-100">
        <div class="flex gap-2 items-stretch">
          <textarea
            name="message"
            placeholder={@ui_config.chat.placeholder}
            autocomplete="off"
            rows="3"
            phx-hook="ChatInput"
            id="chat-input"
            class="flex-1 px-4 py-3 rounded-xl border border-base-300 focus:border-primary focus:ring-1 focus:ring-primary outline-none text-sm text-base-content bg-base-100 resize-none"
          />
          <div class="flex flex-col gap-1.5 w-14">
            <button
              type="button"
              id="voice-btn"
              phx-hook="SpeechToText"
              class="flex-1 flex items-center justify-center rounded-xl border border-base-300 text-base-content/40 hover:text-primary hover:border-primary transition cursor-pointer"
              title={@ui_config.chat.voice_label}
            >
              <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" class="w-5 h-5">
                <path d="M12 14a3 3 0 0 0 3-3V5a3 3 0 0 0-6 0v6a3 3 0 0 0 3 3Z" />
                <path d="M19 11a1 1 0 1 0-2 0 5 5 0 0 1-10 0 1 1 0 1 0-2 0 7 7 0 0 0 6 6.93V21H8a1 1 0 1 0 0 2h8a1 1 0 1 0 0-2h-3v-3.07A7 7 0 0 0 19 11Z" />
              </svg>
            </button>
            <button
              type="submit"
              class="flex-1 flex items-center justify-center text-primary-content rounded-xl transition text-sm font-medium bg-primary hover:brightness-110 cursor-pointer"
            >
              {@ui_config.chat.send_label}
            </button>
          </div>
        </div>
      </form>
    </div>
    """
  end

  # --- Chat widget inline rendering ---

  attr :content, :string, required: true
  attr :chat_widgets, :map, required: true

  defp message_content(assigns) do
    parts =
      assigns.content
      |> parse_message_parts(assigns.chat_widgets)
      |> Enum.reject(fn {:text, t} -> String.trim(t) == ""; _ -> false end)
      |> Enum.map(fn {:text, t} -> {:text, String.trim_trailing(t)}; other -> other end)
      |> break_before_widgets()

    assigns = assign(assigns, :parts, parts)

    ~H"""
    <div><%= for part <- @parts do %><%= case part do %><% {:text, text} -> %><span class="whitespace-pre-wrap"><%= text %></span><% :break -> %><div class="h-1"></div><% {:chat_widget, wid, mod, cfg} -> %><span class="inline-block mr-1.5 mb-1.5"><%= mod.render(%{widget_id: wid, config: cfg, __changed__: nil}) %></span><% end %><% end %></div>
    """
  end

  # Insert a :break between text → widget transitions so pills always start on a new line
  defp break_before_widgets([{:text, _} = t, {:chat_widget, _, _, _} = w | rest]),
    do: [t, :break | break_before_widgets([w | rest])]
  defp break_before_widgets([h | rest]), do: [h | break_before_widgets(rest)]
  defp break_before_widgets([]), do: []

  defp parse_message_parts(content, chat_widgets) when is_binary(content) do
    regex = ~r/\{\{chat_widget:([\w-]+)\}\}/

    Regex.split(regex, content, include_captures: true)
    |> Enum.map(fn part ->
      case Regex.run(~r/^\{\{chat_widget:([\w-]+)\}\}$/, part) do
        [_, widget_id] ->
          case Map.get(chat_widgets, widget_id) do
            nil ->
              {:text, part}

            spec ->
              type = spec[:widget] || spec["widget"]
              config = spec[:config] || spec["config"] || %{}
              component_mod = Registry.chat_widget_component_for(type)

              if component_mod do
                {:chat_widget, widget_id, component_mod, config}
              else
                {:text, part}
              end
          end

        nil ->
          {:text, part}
      end
    end)
  end

  defp parse_message_parts(_, _), do: [{:text, ""}]

  defp format_timestamp(nil), do: ""

  defp format_timestamp(%DateTime{} = dt) do
    dt
    |> DateTime.shift_zone!("Etc/UTC")
    |> Calendar.strftime("%I:%M %p")
  end

  defp format_timestamp(_), do: ""
end
