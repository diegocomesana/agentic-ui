defmodule AgenticUi.Business.Descriptors.HeroBanner do
  def descriptor do
    %{
      name: "Hero Banner",
      component: AgenticUi.Business.Widgets.HeroBanner,
      description: "Large banner with title, subtitle, and optional CTA. Used for welcome messages or category highlights. Agent fills the content directly.",
      agent_instructions: "You fill hero_banner content directly via config (title, subtitle, etc.) — no tool call is needed for this widget.",
      config_schema: %{
        title: %{type: "string", description: "Main heading"},
        subtitle: %{type: "string", description: "Secondary text"},
        cta_text: %{type: "string", description: "Call-to-action button text (optional)"},
        theme: %{type: "string", description: "Color theme: 'blue', 'green', 'purple', 'dark'", default: "blue"}
      },
      data_source: "agent_filled",
      events: %{
        "cta_click" => %{description: "User clicks the CTA button"}
      }
    }
  end
end
