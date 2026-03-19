defmodule AgenticUiWeb.Renderer do
  @moduledoc """
  Converts store layout + widgets into ordered widget list for rendering.
  """

  def ordered_widgets(store) do
    layout = store.layout
    widgets = store.widgets

    case layout do
      %{"children" => children} when is_list(children) ->
        children
        |> Enum.filter(&Map.has_key?(widgets, &1))
        |> Enum.map(fn id -> {id, Map.get(widgets, id)} end)

      _ ->
        Enum.to_list(widgets)
    end
  end

  def layout_direction(store) do
    case store.layout do
      %{"direction" => dir} -> dir
      _ -> "vertical"
    end
  end
end
