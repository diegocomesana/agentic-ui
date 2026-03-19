defmodule AgenticUi.AgentScheduler do
  @moduledoc """
  Pure state machine that serializes agent invocations.

  Guarantees: at most one agent runs at a time.
  When state changes during execution (new messages, mechanical events),
  the stale result is discarded and the agent re-invokes with fresh state.

  ## States

      :idle + request_invocation → :busy  → {:invoke, scheduler}
      :busy + request_invocation → :busy  → {:queued, scheduler}  (dirty=true)
      :busy + notify_state_changed → :busy (dirty=true)
      :busy + task_completed (dirty)  → :busy  → {:reinvoke, scheduler}
      :busy + task_completed (clean)  → :idle  → {:idle, scheduler}
      :idle + task_completed           → :idle  → {:stale, scheduler}  (orphaned task after reset)
  """

  defstruct status: :idle, dirty: false

  @type t :: %__MODULE__{status: :idle | :busy, dirty: boolean()}

  @spec new() :: t()
  def new, do: %__MODULE__{}

  @spec request_invocation(t()) :: {:invoke, t()} | {:queued, t()}
  def request_invocation(%__MODULE__{status: :idle} = s) do
    {:invoke, %{s | status: :busy, dirty: false}}
  end

  def request_invocation(%__MODULE__{status: :busy} = s) do
    {:queued, %{s | dirty: true}}
  end

  @spec notify_state_changed(t()) :: t()
  def notify_state_changed(%__MODULE__{status: :busy} = s), do: %{s | dirty: true}
  def notify_state_changed(%__MODULE__{status: :idle} = s), do: s

  @spec task_completed(t()) :: {:reinvoke, t()} | {:idle, t()} | {:stale, t()}
  def task_completed(%__MODULE__{status: :idle} = s) do
    {:stale, s}
  end

  def task_completed(%__MODULE__{status: :busy, dirty: true} = s) do
    {:reinvoke, %{s | dirty: false}}
  end

  def task_completed(%__MODULE__{status: :busy, dirty: false} = s) do
    {:idle, %{s | status: :idle}}
  end

  @spec reset(t()) :: t()
  def reset(%__MODULE__{}), do: new()

  @spec busy?(t()) :: boolean()
  def busy?(%__MODULE__{status: :busy}), do: true
  def busy?(%__MODULE__{status: :idle}), do: false
end
