defmodule AgenticUi.Session do
  @moduledoc """
  In-memory session persistence via GenServer.
  Stores a history of store snapshots per session for undo support.
  """
  use GenServer

  # Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def load_or_create(session_id, initial_store \\ nil) do
    GenServer.call(__MODULE__, {:load_or_create, session_id, initial_store})
  end

  def push_step(session_id, store, guest_user_id \\ nil) do
    GenServer.call(__MODULE__, {:push_step, session_id, store})
    persist_async(guest_user_id, store)
    :ok
  end

  def go_back(session_id) do
    GenServer.call(__MODULE__, {:go_back, session_id})
  end

  def get_current(session_id) do
    GenServer.call(__MODULE__, {:get_current, session_id})
  end

  # Server Callbacks

  @impl true
  def init(_) do
    {:ok, %{}}
  end

  @impl true
  def handle_call({:load_or_create, session_id, initial_store}, _from, state) do
    case Map.get(state, session_id) do
      nil ->
        store = initial_store || AgenticUi.Business.DefaultState.build_initial_store()
        {:reply, {:ok, store}, Map.put(state, session_id, [store])}

      [current | _] ->
        {:reply, {:ok, current}, state}
    end
  end

  @impl true
  def handle_call({:push_step, session_id, store}, _from, state) do
    history = Map.get(state, session_id, [])
    {:reply, :ok, Map.put(state, session_id, [store | history])}
  end

  @impl true
  def handle_call({:go_back, session_id}, _from, state) do
    case Map.get(state, session_id, []) do
      [_current, prev | rest] ->
        {:reply, {:ok, prev}, Map.put(state, session_id, [prev | rest])}

      _ ->
        {:reply, {:error, :no_history}, state}
    end
  end

  @impl true
  def handle_call({:get_current, session_id}, _from, state) do
    case Map.get(state, session_id, []) do
      [current | _] -> {:reply, {:ok, current}, state}
      [] -> {:reply, {:error, :not_found}, state}
    end
  end

  # Private — async DB persistence

  defp persist_async(nil, _store), do: :ok

  defp persist_async(guest_user_id, store) do
    if AgenticUi.Accounts.db_available?() do
      store_data = AgenticUi.Store.to_persistable(store)

      Task.start(fn ->
        case AgenticUi.Accounts.save_session(guest_user_id, store_data) do
          {:ok, _} -> :ok
          {:error, reason} ->
            require Logger
            Logger.warning("[Session] failed to persist store: #{inspect(reason)}")
        end
      end)
    end

    :ok
  end
end
