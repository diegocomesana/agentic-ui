defmodule AgenticUi.Business.Services.ProductCache do
  @moduledoc """
  ETS-backed cache with TTL for product data.
  Runs periodic cleanup every 60 seconds.
  """
  use GenServer

  @table :product_cache
  @default_ttl :timer.minutes(5)
  @cleanup_interval :timer.seconds(60)

  # Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def get(key) do
    case :ets.lookup(@table, key) do
      [{^key, value, expires_at}] ->
        if System.monotonic_time(:millisecond) < expires_at do
          {:ok, value}
        else
          :ets.delete(@table, key)
          :miss
        end

      [] ->
        :miss
    end
  end

  def put(key, value, ttl \\ @default_ttl) do
    expires_at = System.monotonic_time(:millisecond) + ttl
    :ets.insert(@table, {key, value, expires_at})
    :ok
  end

  # Server callbacks

  @impl true
  def init(_) do
    :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
    schedule_cleanup()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:cleanup, state) do
    now = System.monotonic_time(:millisecond)

    :ets.select_delete(@table, [
      {{:_, :_, :"$1"}, [{:<, :"$1", now}], [true]}
    ])

    schedule_cleanup()
    {:noreply, state}
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @cleanup_interval)
  end
end
