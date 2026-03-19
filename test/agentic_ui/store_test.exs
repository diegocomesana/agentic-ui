defmodule AgenticUi.StoreTest do
  use ExUnit.Case, async: true

  alias AgenticUi.Store

  describe "add_message/3 (backward compatible)" do
    test "adds message without state_context" do
      store = Store.new() |> Store.add_message(:user, "hello")
      [msg] = store.conversation
      assert msg.role == :user
      assert msg.content == "hello"
      refute Map.has_key?(msg, :state_context)
    end
  end

  describe "add_message/4 with state_context" do
    test "adds state_context when provided" do
      store = Store.new() |> Store.add_message(:user, "hello", "[cart: empty | screen: empty]")
      [msg] = store.conversation
      assert msg.role == :user
      assert msg.content == "hello"
      assert msg.state_context == "[cart: empty | screen: empty]"
    end

    test "does not add state_context when nil" do
      store = Store.new() |> Store.add_message(:user, "hello", nil)
      [msg] = store.conversation
      assert msg.role == :user
      assert msg.content == "hello"
      refute Map.has_key?(msg, :state_context)
    end

    test "preserves state_context through to_persistable/from_persistable" do
      store =
        Store.new()
        |> Store.add_message(:user, "hello", "[cart(2): Mouse, Keyboard | screen: grid-keyboards]")
        |> Store.add_message(:assistant, "Here are keyboards!", "[cart(2): Mouse, Keyboard | screen: grid-keyboards]")

      persisted = Store.to_persistable(store)
      restored = Store.from_persistable(persisted)

      [user_msg, assistant_msg] = restored.conversation
      assert user_msg.state_context == "[cart(2): Mouse, Keyboard | screen: grid-keyboards]"
      assert assistant_msg.state_context == "[cart(2): Mouse, Keyboard | screen: grid-keyboards]"
    end

    test "messages without state_context round-trip correctly" do
      store =
        Store.new()
        |> Store.add_message(:user, "hi")
        |> Store.add_message(:assistant, "hello", "[cart: empty | screen: empty]")

      persisted = Store.to_persistable(store)
      restored = Store.from_persistable(persisted)

      [user_msg, assistant_msg] = restored.conversation
      refute Map.has_key?(user_msg, :state_context)
      assert assistant_msg.state_context == "[cart: empty | screen: empty]"
    end
  end
end
