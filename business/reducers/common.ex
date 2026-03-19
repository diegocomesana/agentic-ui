defmodule AgenticUi.Business.Reducers.Common do
  @moduledoc """
  Generic reducers reusable across widget types.
  Each function: reduce(store, ctx) :: store
  """

  alias AgenticUi.Store

  def toggle_pin(store, ctx) do
    Store.toggle_pin(store, ctx.widget_id)
  end

  def close(store, ctx) do
    if Store.pinned?(store, ctx.widget_id) do
      store
    else
      store = Store.remove_widget(store, ctx.widget_id)
      Store.remove_from_layout(store, ctx.widget_id)
    end
  end

  def toggle_config(store, ctx) do
    key = ctx.event_data["config_key"] || (ctx.reducer_opts && ctx.reducer_opts[:config_key])
    current = get_in(store, [:widgets, ctx.widget_id, :config, key]) == true
    put_in(store, [:widgets, ctx.widget_id, :config, key], !current)
  end
end
