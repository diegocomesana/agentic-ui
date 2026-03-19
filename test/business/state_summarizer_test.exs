defmodule AgenticUi.Business.StateSummarizerTest do
  use ExUnit.Case, async: true

  alias AgenticUi.Store
  alias AgenticUi.Business.StateSummarizer

  describe "summarize/1" do
    test "empty store" do
      store = Store.new()
      result = StateSummarizer.summarize(store)
      assert result == "[cart: empty | screen: empty]"
    end

    test "store with cart items" do
      store =
        Store.new()
        |> Store.add_to_cart(%{id: "1", name: "Wireless Mouse", price: 29.99})
        |> Store.add_to_cart(%{id: "2", name: "Mechanical Keyboard", price: 79.99})

      result = StateSummarizer.summarize(store)
      assert result == "[cart(2): Wireless Mouse, Mechanical Keyboard | screen: empty]"
    end

    test "store with wishlist items" do
      store =
        Store.new()
        |> Store.add_to_wishlist(%{id: "10", name: "Gaming Monitor", price: 499.99})

      result = StateSummarizer.summarize(store)
      assert result == "[cart: empty | wishlist(1): Gaming Monitor | screen: empty]"
    end

    test "store with widgets in layout" do
      store =
        Store.new()
        |> Store.put_widget("grid-keyboards", %{widget: "product_grid", config: %{}, data: %{}})
        |> Store.put_widget("detail-5", %{widget: "product_detail", config: %{}, data: %{}})
        |> Store.set_layout(%{"type" => "stack", "direction" => "vertical", "children" => ["grid-keyboards", "detail-5"]})

      result = StateSummarizer.summarize(store)
      assert result == "[cart: empty | screen: grid-keyboards, detail-5]"
    end

    test "cart with more than 5 items truncates" do
      store =
        Enum.reduce(1..7, Store.new(), fn i, acc ->
          Store.add_to_cart(acc, %{id: "#{i}", name: "Product #{i}", price: 10.0})
        end)

      result = StateSummarizer.summarize(store)
      assert result =~ "cart(7): Product 1, Product 2, Product 3, Product 4, Product 5..."
    end

    test "wishlist with more than 3 items truncates" do
      store =
        Enum.reduce(1..5, Store.new(), fn i, acc ->
          Store.add_to_wishlist(acc, %{id: "#{i}", name: "Item #{i}", price: 10.0})
        end)

      result = StateSummarizer.summarize(store)
      assert result =~ "wishlist(5): Item 1, Item 2, Item 3..."
    end

    test "widgets without layout uses sorted map keys" do
      store =
        Store.new()
        |> Store.put_widget("cart", %{widget: "cart", config: %{}, data: %{}})
        |> Store.put_widget("grid-mice", %{widget: "product_grid", config: %{}, data: %{}})

      result = StateSummarizer.summarize(store)
      assert result == "[cart: empty | screen: cart, grid-mice]"
    end

    test "full state with cart, wishlist, and widgets" do
      store =
        Store.new()
        |> Store.add_to_cart(%{id: "1", name: "Mouse", price: 29.99})
        |> Store.add_to_wishlist(%{id: "5", name: "Monitor", price: 499.99})
        |> Store.put_widget("grid-keyboards", %{widget: "product_grid", config: %{}, data: %{}})
        |> Store.set_layout(%{"type" => "stack", "direction" => "vertical", "children" => ["grid-keyboards"]})

      result = StateSummarizer.summarize(store)
      assert result == "[cart(1): Mouse | wishlist(1): Monitor | screen: grid-keyboards]"
    end

    test "empty wishlist is omitted from output" do
      store = Store.new()
      result = StateSummarizer.summarize(store)
      refute result =~ "wishlist"
    end
  end
end
