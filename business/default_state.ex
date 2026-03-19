defmodule AgenticUi.Business.DefaultState do
  @moduledoc """
  Defines the initial widgets for each mode: agent_on and agent_off.
  Pure functional — no side effects.

  Each mode has its own widget set with independent pinned/locked flags.
  - pinned: user can unpin via UI → then removable by agent or user
  - locked: permanently fixed — cannot be removed or unpinned by anyone
  """

  alias AgenticUi.Store

  # --- Agent ON layout ---
  # Full experience: search bar (semantic), carousel, top products, categories
  @agent_on_widgets [
    %{id: "main-menu", widget: "main_menu",
      config: %{},
      pinned: false, locked: false},
    %{id: "hero-carousel", widget: "hero_carousel",
      config: %{"category" => "all", "limit" => 5, "interval" => 5000},
      pinned: false, locked: false},
    %{id: "search-bar", widget: "search_bar",
      config: %{"placeholder" => "Search products..."},
      pinned: false, locked: false},
    %{id: "categories", widget: "category_browser",
      config: %{},
      pinned: false, locked: false},
    %{id: "top-all", widget: "top_products",
      config: %{"category" => "all", "limit" => 5},
      pinned: false, locked: false}
  ]

  # --- Agent OFF layout ---
  # Manual browsing: search bar on top (mechanical mode), categories, top products
  @agent_off_widgets [
    %{id: "main-menu", widget: "main_menu",
      config: %{},
      pinned: false, locked: false},
    %{id: "search-bar", widget: "search_bar",
      config: %{"placeholder" => "Search products..."},
      pinned: false, locked: false},
    %{id: "categories", widget: "category_browser",
      config: %{},
      pinned: false, locked: false},
    %{id: "top-all", widget: "top_products",
      config: %{"category" => "all", "limit" => 5},
      pinned: false, locked: false}
  ]

  @doc """
  Builds the initial store for the given mode (:agent_on or :agent_off).

  When `previous_store` is provided, persistent state (cart, conversation)
  is carried over. This is used on mode switch and layout reset so the user
  doesn't lose their cart or chat history.
  """
  def build_initial_store(mode \\ :agent_on, previous_store \\ nil) do
    widgets = widgets_for(mode)

    base = Store.new()

    # Carry over persistent state from previous store
    base =
      if previous_store do
        %{base |
          cart: previous_store[:cart] || [],
          wishlist: previous_store[:wishlist] || [],
          conversation: previous_store[:conversation] || [],
          chat_widgets: previous_store[:chat_widgets] || %{}
        }
      else
        base
      end

    store =
      Enum.reduce(widgets, base, fn w, acc ->
        Store.put_widget(acc, w.id, %{
          widget: w.widget,
          config: w.config,
          data: %{},
          pinned: Map.get(w, :pinned, false),
          locked: Map.get(w, :locked, false)
        })
      end)

    # If cart has items, include the cart widget
    store =
      if (store[:cart] || []) != [] && !Map.has_key?(store.widgets, "cart") do
        Store.put_widget(store, "cart", %{widget: "cart", config: %{}, data: %{}})
      else
        store
      end

    # If wishlist has items, include the wishlist widget
    store =
      if (store[:wishlist] || []) != [] && !Map.has_key?(store.widgets, "wishlist") do
        Store.put_widget(store, "wishlist", %{widget: "wishlist", config: %{}, data: %{}})
      else
        store
      end

    widget_ids = Enum.map(widgets, & &1.id)

    children =
      Enum.reduce(["wishlist", "cart"], widget_ids, fn bucket, acc ->
        if (store[String.to_existing_atom(bucket)] || []) != [] && bucket not in acc do
          [bucket | acc]
        else
          acc
        end
      end)

    layout = %{
      "type" => "stack",
      "direction" => "vertical",
      "children" => children
    }

    Store.set_layout(store, layout)
  end

  @doc """
  Returns data_calls for widgets that need data resolution in the given mode.
  """
  def data_calls(mode \\ :agent_on) do
    alias AgenticUi.Business.Descriptors.Registry

    Enum.flat_map(widgets_for(mode), fn w ->
      case Registry.get(w.widget) do
        nil ->
          []

        mod ->
          desc = mod.descriptor()

          if desc[:data_source] && desc[:data_source] != "agent_filled" do
            [{w.id, desc[:data_source], w.config}]
          else
            []
          end
      end
    end)
  end

  defp widgets_for(:agent_on), do: @agent_on_widgets
  defp widgets_for(:agent_off), do: @agent_off_widgets
  defp widgets_for(_), do: @agent_on_widgets
end
