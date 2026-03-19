defmodule AgenticUi.Business.StateSummarizer do
  @moduledoc """
  Generates a compact state snapshot string to attach to conversation messages.
  The agent uses these annotations to track state evolution across the history.
  """

  def summarize(store) do
    parts = []

    # Cart
    cart = store[:cart] || []

    parts =
      if cart != [] do
        names = cart |> Enum.map(& &1.name) |> Enum.take(5) |> Enum.join(", ")
        suffix = if length(cart) > 5, do: "...", else: ""
        parts ++ ["cart(#{length(cart)}): #{names}#{suffix}"]
      else
        parts ++ ["cart: empty"]
      end

    # Wishlist
    wishlist = store[:wishlist] || []

    parts =
      if wishlist != [] do
        names = wishlist |> Enum.map(& &1.name) |> Enum.take(3) |> Enum.join(", ")
        suffix = if length(wishlist) > 3, do: "...", else: ""
        parts ++ ["wishlist(#{length(wishlist)}): #{names}#{suffix}"]
      else
        parts
      end

    # Visible widgets
    widget_ids =
      case store.layout do
        %{"children" => children} when is_list(children) -> children
        _ -> store.widgets |> Map.keys() |> Enum.sort()
      end

    parts =
      if widget_ids != [] do
        parts ++ ["screen: #{Enum.join(widget_ids, ", ")}"]
      else
        parts ++ ["screen: empty"]
      end

    "[" <> Enum.join(parts, " | ") <> "]"
  end
end
