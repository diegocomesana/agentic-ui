defmodule AgenticUi.Business.Widgets.ChatCategoryButton do
  use Phoenix.Component
  import AgenticUiWeb.CoreComponents, only: [mat_icon: 1]

  attr :widget_id, :string, required: true
  attr :config, :map, required: true

  def render(assigns) do
    label = assigns.config["label"] || assigns.config["category"] || "Browse"
    category = assigns.config["category"] || ""
    assigns = assign(assigns, label: label, category: category)

    ~H"""
    <button
      phx-click="widget_action"
      phx-value-widget-id={@widget_id}
      phx-value-action="select_category"
      phx-value-category={@category}
      class="inline-flex items-center gap-0.5 px-2 py-0.5 rounded-full text-[11px] font-medium bg-primary/15 text-primary hover:bg-primary/25 border border-primary/30 transition cursor-pointer leading-tight"
    >
      <.mat_icon name="category" class="text-[10px]" />
      {@label}
    </button>
    """
  end
end
