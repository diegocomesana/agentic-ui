defmodule AgenticUi.Business.Widgets.HeroBanner do
  use Phoenix.Component
  alias Phoenix.LiveView.JS
  import AgenticUiWeb.CoreComponents, only: [mat_icon: 1]

  attr :id, :string, required: true
  attr :widget, :map, required: true

  def render(assigns) do
    config = assigns.widget[:config] || %{}
    title = config["title"] || config[:title] || "Welcome"
    subtitle = config["subtitle"] || config[:subtitle] || ""
    cta_text = config["cta_text"] || config[:cta_text]
    image = config["image"] || config[:image]

    assigns =
      assigns
      |> assign(:title, title)
      |> assign(:subtitle, subtitle)
      |> assign(:cta_text, cta_text)
      |> assign(:image, image)

    ~H"""
    <div class="rounded-2xl mb-4 transition-all duration-500 animate-in relative overflow-hidden min-w-0 h-52" phx-remove={JS.add_class("animate-out")}>
      <%!-- Background image --%>
      <img
        :if={@image}
        src={@image}
        alt=""
        class="absolute inset-0 w-full h-full object-cover"
      />
      <%!-- Overlay --%>
      <div class={[
        "absolute inset-0",
        if(@image, do: "bg-gradient-to-r from-black/70 via-black/50 to-black/30", else: "bg-gradient-to-r from-blue-600 to-blue-800")
      ]}></div>
      <%!-- Controls --%>
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
      <%!-- Content --%>
      <div class="relative z-[1] h-full flex flex-col justify-end p-8 text-white">
        <h1 class="text-3xl font-bold mb-1 truncate drop-shadow-lg">{@title}</h1>
        <p :if={@subtitle != ""} class="text-base opacity-90 mb-3 break-words max-w-xl drop-shadow">{@subtitle}</p>
        <div :if={@cta_text}>
          <button
            phx-click="widget_action"
            phx-value-widget-id={@id}
            phx-value-action="cta_click"
            class="px-5 py-2 bg-white/20 hover:bg-white/30 rounded-lg font-medium backdrop-blur-sm transition border border-white/20"
          >
            {@cta_text}
          </button>
        </div>
      </div>
    </div>
    """
  end
end
