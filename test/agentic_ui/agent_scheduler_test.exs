defmodule AgenticUi.AgentSchedulerTest do
  use ExUnit.Case, async: true

  alias AgenticUi.AgentScheduler

  describe "new/0" do
    test "creates scheduler in idle state" do
      s = AgentScheduler.new()
      assert s.status == :idle
      assert s.dirty == false
    end
  end

  describe "request_invocation/1" do
    test "idle → busy, returns {:invoke, _}" do
      s = AgentScheduler.new()
      {:invoke, s} = AgentScheduler.request_invocation(s)
      assert s.status == :busy
      assert s.dirty == false
    end

    test "busy → stays busy, marks dirty, returns {:queued, _}" do
      {:invoke, s} = AgentScheduler.request_invocation(AgentScheduler.new())
      {:queued, s} = AgentScheduler.request_invocation(s)
      assert s.status == :busy
      assert s.dirty == true
    end

    test "multiple queued requests keep dirty=true" do
      {:invoke, s} = AgentScheduler.request_invocation(AgentScheduler.new())
      {:queued, s} = AgentScheduler.request_invocation(s)
      {:queued, s} = AgentScheduler.request_invocation(s)
      {:queued, s} = AgentScheduler.request_invocation(s)
      assert s.status == :busy
      assert s.dirty == true
    end
  end

  describe "notify_state_changed/1" do
    test "busy → marks dirty" do
      {:invoke, s} = AgentScheduler.request_invocation(AgentScheduler.new())
      s = AgentScheduler.notify_state_changed(s)
      assert s.dirty == true
      assert s.status == :busy
    end

    test "idle → no change" do
      s = AgentScheduler.new()
      s = AgentScheduler.notify_state_changed(s)
      assert s.status == :idle
      assert s.dirty == false
    end
  end

  describe "task_completed/1" do
    test "dirty=true → returns {:reinvoke, _}, clears dirty" do
      {:invoke, s} = AgentScheduler.request_invocation(AgentScheduler.new())
      s = AgentScheduler.notify_state_changed(s)
      assert s.dirty == true

      {:reinvoke, s} = AgentScheduler.task_completed(s)
      assert s.status == :busy
      assert s.dirty == false
    end

    test "dirty=false → returns {:idle, _}, transitions to idle" do
      {:invoke, s} = AgentScheduler.request_invocation(AgentScheduler.new())
      assert s.dirty == false

      {:idle, s} = AgentScheduler.task_completed(s)
      assert s.status == :idle
      assert s.dirty == false
    end
  end

  describe "reset/1" do
    test "resets busy scheduler to idle" do
      {:invoke, s} = AgentScheduler.request_invocation(AgentScheduler.new())
      {:queued, s} = AgentScheduler.request_invocation(s)
      assert s.status == :busy
      assert s.dirty == true

      s = AgentScheduler.reset(s)
      assert s.status == :idle
      assert s.dirty == false
    end

    test "reset on idle is idempotent" do
      s = AgentScheduler.new()
      s = AgentScheduler.reset(s)
      assert s.status == :idle
      assert s.dirty == false
    end
  end

  describe "busy?/1" do
    test "returns true when busy" do
      {:invoke, s} = AgentScheduler.request_invocation(AgentScheduler.new())
      assert AgentScheduler.busy?(s) == true
    end

    test "returns false when idle" do
      assert AgentScheduler.busy?(AgentScheduler.new()) == false
    end
  end

  describe "task_completed on idle (stale)" do
    test "returns {:stale, _} when scheduler is idle (orphaned task after reset)" do
      s = AgentScheduler.new()
      {:stale, s} = AgentScheduler.task_completed(s)
      assert s.status == :idle
      assert s.dirty == false
    end

    test "reset while busy then task completes → stale" do
      {:invoke, s} = AgentScheduler.request_invocation(AgentScheduler.new())
      assert s.status == :busy

      s = AgentScheduler.reset(s)
      assert s.status == :idle

      {:stale, s} = AgentScheduler.task_completed(s)
      assert s.status == :idle
    end
  end

  describe "full lifecycle scenarios" do
    test "single invocation: idle → invoke → complete → idle" do
      s = AgentScheduler.new()
      assert s.status == :idle

      {:invoke, s} = AgentScheduler.request_invocation(s)
      assert s.status == :busy

      {:idle, s} = AgentScheduler.task_completed(s)
      assert s.status == :idle
    end

    test "message while busy: invoke → queued → reinvoke → complete → idle" do
      s = AgentScheduler.new()

      # First message triggers invocation
      {:invoke, s} = AgentScheduler.request_invocation(s)
      assert s.status == :busy

      # Second message while busy → queued
      {:queued, s} = AgentScheduler.request_invocation(s)
      assert s.dirty == true

      # First task completes → stale, reinvoke
      {:reinvoke, s} = AgentScheduler.task_completed(s)
      assert s.status == :busy
      assert s.dirty == false

      # Re-invocation completes cleanly
      {:idle, s} = AgentScheduler.task_completed(s)
      assert s.status == :idle
    end

    test "mechanical event while busy: state_changed → reinvoke on completion" do
      s = AgentScheduler.new()

      {:invoke, s} = AgentScheduler.request_invocation(s)

      # Mechanical event (e.g. pagination) changes state
      s = AgentScheduler.notify_state_changed(s)
      assert s.dirty == true

      # Agent finishes but state is stale → reinvoke
      {:reinvoke, s} = AgentScheduler.task_completed(s)
      assert s.status == :busy

      # Clean completion
      {:idle, s} = AgentScheduler.task_completed(s)
      assert s.status == :idle
    end

    test "multiple events during single invocation: all collapsed into one reinvoke" do
      s = AgentScheduler.new()
      {:invoke, s} = AgentScheduler.request_invocation(s)

      # Multiple events while busy
      {:queued, s} = AgentScheduler.request_invocation(s)
      s = AgentScheduler.notify_state_changed(s)
      {:queued, s} = AgentScheduler.request_invocation(s)

      # Only ONE reinvoke happens (not three)
      {:reinvoke, s} = AgentScheduler.task_completed(s)
      assert s.status == :busy

      # Clean completion
      {:idle, s} = AgentScheduler.task_completed(s)
      assert s.status == :idle
    end

    test "reinvoke chain: dirty during reinvocation triggers another reinvoke" do
      s = AgentScheduler.new()
      {:invoke, s} = AgentScheduler.request_invocation(s)

      # Event during first invocation
      {:queued, s} = AgentScheduler.request_invocation(s)
      {:reinvoke, s} = AgentScheduler.task_completed(s)

      # Another event during reinvocation
      s = AgentScheduler.notify_state_changed(s)
      {:reinvoke, s} = AgentScheduler.task_completed(s)

      # Finally clean
      {:idle, s} = AgentScheduler.task_completed(s)
      assert s.status == :idle
    end

    test "reset during busy: orphaned task result is stale" do
      s = AgentScheduler.new()

      {:invoke, s} = AgentScheduler.request_invocation(s)
      assert s.status == :busy

      # User resets while agent is running
      s = AgentScheduler.reset(s)
      assert s.status == :idle

      # Orphaned task completes → stale (ignored)
      {:stale, s} = AgentScheduler.task_completed(s)
      assert s.status == :idle

      # System works normally after
      {:invoke, s} = AgentScheduler.request_invocation(s)
      {:idle, s} = AgentScheduler.task_completed(s)
      assert s.status == :idle
    end

    test "back to back after clean completion" do
      s = AgentScheduler.new()

      # First full cycle
      {:invoke, s} = AgentScheduler.request_invocation(s)
      {:idle, s} = AgentScheduler.task_completed(s)
      assert s.status == :idle

      # Second full cycle
      {:invoke, s} = AgentScheduler.request_invocation(s)
      {:idle, s} = AgentScheduler.task_completed(s)
      assert s.status == :idle
    end
  end
end
