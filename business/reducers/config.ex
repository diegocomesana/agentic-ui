defmodule AgenticUi.Business.Reducers.Config do
  @moduledoc """
  Generic config mutation reducers for widget events.
  Each function: reduce(store, ctx) :: store

  Used by descriptors to declare mechanical config changes
  (pagination, search, filters) without hardcoding in engine.ex.
  """

  def increment_config(store, ctx) do
    key = ctx.reducer_opts[:config_key] || "page"
    current = get_in(store, [:widgets, ctx.widget_id, :config, key]) || 1
    put_in(store, [:widgets, ctx.widget_id, :config, key], current + 1)
  end

  def decrement_config(store, ctx) do
    key = ctx.reducer_opts[:config_key] || "page"
    current = get_in(store, [:widgets, ctx.widget_id, :config, key]) || 1
    put_in(store, [:widgets, ctx.widget_id, :config, key], max(current - 1, 1))
  end

  def set_config(store, ctx) do
    config_map = ctx.reducer_opts[:config_map] || %{}
    resets = ctx.reducer_opts[:resets] || %{}

    store =
      Enum.reduce(config_map, store, fn {config_key, event_key}, acc ->
        value = Map.get(ctx.event_data, event_key, "")
        put_in(acc, [:widgets, ctx.widget_id, :config, config_key], value)
      end)

    Enum.reduce(resets, store, fn {config_key, default_val}, acc ->
      put_in(acc, [:widgets, ctx.widget_id, :config, config_key], default_val)
    end)
  end

  def set_config_typed(store, ctx) do
    config_map = ctx.reducer_opts[:config_map] || %{}
    resets = ctx.reducer_opts[:resets] || %{}
    types = ctx.reducer_opts[:types] || %{}

    store =
      Enum.reduce(config_map, store, fn {config_key, event_key}, acc ->
        raw = Map.get(ctx.event_data, event_key)
        type = Map.get(types, config_key, :string)
        value = coerce(raw, type, Map.get(ctx.reducer_opts[:defaults] || %{}, config_key))
        put_in(acc, [:widgets, ctx.widget_id, :config, config_key], value)
      end)

    Enum.reduce(resets, store, fn {config_key, default_val}, acc ->
      put_in(acc, [:widgets, ctx.widget_id, :config, config_key], default_val)
    end)
  end

  def reset_config(store, ctx) do
    defaults = ctx.reducer_opts[:defaults] || %{}

    Enum.reduce(defaults, store, fn {config_key, default_val}, acc ->
      put_in(acc, [:widgets, ctx.widget_id, :config, config_key], default_val)
    end)
  end

  defp coerce(nil, :number, default), do: default || 0
  defp coerce(val, :number, _default) when is_number(val), do: val

  defp coerce(val, :number, default) when is_binary(val) do
    case Integer.parse(val) do
      {n, ""} -> n
      _ ->
        case Float.parse(val) do
          {n, _} -> n
          :error -> default || 0
        end
    end
  end

  defp coerce(nil, :string, default), do: default || ""
  defp coerce(val, :string, _default), do: val
  defp coerce(val, _, _default), do: val
end
