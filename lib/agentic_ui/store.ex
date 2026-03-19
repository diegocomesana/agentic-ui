defmodule AgenticUi.Store do
  @moduledoc """
  Pure functional store: state_in → state_out.
  Central state for widgets, layout, and conversation.
  """

  def new do
    %{
      widgets: %{},
      layout: nil,
      conversation: [],
      cart: [],
      wishlist: [],
      chat_widgets: %{}
    }
  end

  def put_widget(store, id, widget) do
    widget = Map.merge(%{widget: nil, config: %{}, data: %{}, pinned: false, locked: false}, widget)
    put_in(store, [:widgets, id], widget)
  end

  def pinned?(store, id) do
    w = get_in(store, [:widgets, id])
    w[:pinned] == true || w[:locked] == true
  end

  def locked?(store, id) do
    get_in(store, [:widgets, id, :locked]) == true
  end

  def toggle_pin(store, id) do
    case get_in(store, [:widgets, id]) do
      nil -> store
      %{locked: true} -> store  # locked widgets can't be unpinned
      _widget -> update_in(store, [:widgets, id, :pinned], &(!&1))
    end
  end

  def set_pinned(store, id, pinned?) do
    case get_in(store, [:widgets, id]) do
      nil -> store
      %{locked: true} -> store  # locked widgets can't be unpinned
      _widget -> put_in(store, [:widgets, id, :pinned], pinned?)
    end
  end

  def clear_unpinned_widgets(store) do
    protected = Enum.filter(store.widgets, fn {_id, w} -> w[:pinned] == true || w[:locked] == true end) |> Map.new()

    layout =
      case store.layout do
        %{"children" => children} = l when protected != %{} ->
          protected_ids = Map.keys(protected)
          %{l | "children" => Enum.filter(children, &(&1 in protected_ids))}

        _ when protected != %{} ->
          %{"type" => "stack", "direction" => "vertical", "children" => Map.keys(protected)}

        _ ->
          nil
      end

    %{store | widgets: protected, layout: layout}
  end

  def remove_widget(store, id) do
    if locked?(store, id) do
      store  # locked widgets can't be removed
    else
      update_in(store, [:widgets], &Map.delete(&1, id))
    end
  end

  def set_widget_data(store, id, data) do
    case get_in(store, [:widgets, id]) do
      nil -> store
      _widget -> put_in(store, [:widgets, id, :data], data)
    end
  end

  def set_loading(store, id, loading) do
    case get_in(store, [:widgets, id]) do
      nil -> store
      _widget -> put_in(store, [:widgets, id, :loading], loading)
    end
  end

  def set_layout(store, layout) do
    %{store | layout: layout}
  end

  def add_to_layout(store, widget_id) do
    case store.layout do
      %{"children" => children} = l ->
        if widget_id in children,
          do: store,
          else: set_layout(store, %{l | "children" => [widget_id | children]})

      _ ->
        set_layout(store, %{
          "type" => "stack",
          "direction" => "vertical",
          "children" => [widget_id | Map.keys(store.widgets)]
        })
    end
  end

  def remove_from_layout(store, widget_id) do
    case store.layout do
      %{"children" => children} = layout ->
        set_layout(store, %{layout | "children" => List.delete(children, widget_id)})

      _ ->
        store
    end
  end

  def add_message(store, role, content) do
    add_message(store, role, content, nil)
  end

  def add_message(store, role, content, state_context) do
    msg = %{role: role, content: content, timestamp: DateTime.utc_now()}
    msg = if state_context, do: Map.put(msg, :state_context, state_context), else: msg
    update_in(store, [:conversation], &(&1 ++ [msg]))
  end

  def clear_widgets(store) do
    %{store | widgets: %{}, layout: nil}
  end

  # Chat widget operations

  def put_chat_widget(store, id, spec) do
    put_in(store, [:chat_widgets, id], spec)
  end

  def merge_chat_widgets(store, new_widgets) when is_map(new_widgets) do
    %{store | chat_widgets: Map.merge(store[:chat_widgets] || %{}, new_widgets)}
  end

  # Cart operations

  def add_to_cart(store, product, qty \\ 1) do
    product_id = to_string(product[:id] || product["id"])
    cart = store[:cart] || []
    qty = max(qty, 1)

    case Enum.find_index(cart, fn item -> item.product_id == product_id end) do
      nil ->
        item = %{
          product_id: product_id,
          name: product[:name] || product["name"],
          price: product[:price] || product["price"] || 0,
          image: product[:image] || product["image"],
          qty: qty
        }
        %{store | cart: cart ++ [item]}

      idx ->
        updated = List.update_at(cart, idx, fn item -> %{item | qty: item.qty + qty} end)
        %{store | cart: updated}
    end
  end

  def update_cart_qty(store, product_id, delta) do
    cart = store[:cart] || []
    product_id = to_string(product_id)

    updated =
      cart
      |> Enum.map(fn item ->
        if item.product_id == product_id do
          %{item | qty: max(item.qty + delta, 1)}
        else
          item
        end
      end)

    %{store | cart: updated}
  end

  def set_cart_qty(store, product_id, qty) do
    cart = store[:cart] || []
    product_id = to_string(product_id)
    qty = max(qty, 1)

    updated =
      Enum.map(cart, fn item ->
        if item.product_id == product_id do
          %{item | qty: qty}
        else
          item
        end
      end)

    %{store | cart: updated}
  end

  def remove_from_cart(store, product_id) do
    cart = store[:cart] || []
    product_id = to_string(product_id)
    %{store | cart: Enum.reject(cart, fn item -> item.product_id == product_id end)}
  end

  def clear_cart(store) do
    %{store | cart: []}
  end

  def cart_total(store) do
    (store[:cart] || [])
    |> Enum.reduce(0.0, fn item, acc -> acc + (item.price || 0) * item.qty end)
  end

  # Wishlist operations

  def add_to_wishlist(store, product) do
    product_id = to_string(product[:id] || product["id"])
    wishlist = store[:wishlist] || []

    if Enum.any?(wishlist, fn item -> item.product_id == product_id end) do
      store
    else
      item = %{
        product_id: product_id,
        name: product[:name] || product["name"],
        price: product[:price] || product["price"] || 0,
        image: product[:image] || product["image"]
      }
      %{store | wishlist: wishlist ++ [item]}
    end
  end

  def remove_from_wishlist(store, product_id) do
    wishlist = store[:wishlist] || []
    product_id = to_string(product_id)
    %{store | wishlist: Enum.reject(wishlist, fn item -> item.product_id == product_id end)}
  end

  def clear_wishlist(store) do
    %{store | wishlist: []}
  end

  def in_wishlist?(store, product_id) do
    product_id = to_string(product_id)
    Enum.any?(store[:wishlist] || [], fn item -> item.product_id == product_id end)
  end

  def serialize(store) do
    cart_summary = summarize_cart(store)
    wishlist_summary = summarize_wishlist(store)

    %{
      widgets:
        Enum.into(store.widgets, %{}, fn {id, w} ->
          visible_data =
            cond do
              w[:widget] == "cart" -> cart_summary
              w[:widget] == "wishlist" -> wishlist_summary
              true -> summarize_data(w[:widget], w[:data])
            end

          {id,
           %{
             type: w[:widget],
             config: w[:config] || %{},
             pinned: w[:pinned] == true,
             locked: w[:locked] == true,
             visible_data: visible_data
           }}
        end),
      layout: store.layout,
      message_count: length(store.conversation),
      cart: cart_summary,
      wishlist: wishlist_summary
    }
  end

  defp summarize_cart(store) do
    cart = store[:cart] || []

    items =
      Enum.map(cart, fn item ->
        %{
          product_id: item.product_id,
          name: item.name,
          price: item.price,
          qty: item.qty
        }
      end)

    %{
      items: items,
      item_count: length(items),
      total: cart_total(store)
    }
  end

  defp summarize_wishlist(store) do
    wishlist = store[:wishlist] || []

    items =
      Enum.map(wishlist, fn item ->
        %{
          product_id: item.product_id,
          name: item.name,
          price: item.price
        }
      end)

    %{
      items: items,
      item_count: length(items)
    }
  end

  defp summarize_data("product_grid", data) when is_map(data) and map_size(data) > 0 do
    items = data[:items] || data["items"] || []

    %{
      page: data[:page] || data["page"],
      total_pages: data[:total_pages] || data["total_pages"],
      visible_items:
        Enum.map(items, fn item ->
          %{
            id: item[:id] || item["id"],
            name: item[:name] || item["name"],
            price: item[:price] || item["price"]
          }
        end)
    }
  end

  defp summarize_data("product_detail", data) when is_map(data) and map_size(data) > 0 do
    %{
      id: data[:id] || data["id"],
      name: data[:name] || data["name"],
      price: data[:price] || data["price"],
      category: data[:category] || data["category"]
    }
  end

  defp summarize_data("comparator", data) when is_map(data) and map_size(data) > 0 do
    products = data[:products] || data["products"] || []

    %{
      products:
        Enum.map(products, fn p ->
          %{
            id: p[:id] || p["id"],
            name: p[:name] || p["name"],
            price: p[:price] || p["price"]
          }
        end)
    }
  end

  defp summarize_data("top_products", data) when is_map(data) and map_size(data) > 0 do
    items = data[:items] || data["items"] || []

    %{
      visible_items:
        Enum.map(items, fn item ->
          %{
            id: item[:id] || item["id"],
            name: item[:name] || item["name"],
            price: item[:price] || item["price"]
          }
        end)
    }
  end

  defp summarize_data("product_carousel", data) when is_map(data) and map_size(data) > 0 do
    summarize_data("product_grid", data)
  end

  defp summarize_data("hero_carousel", data) when is_map(data) and map_size(data) > 0 do
    items = data[:items] || data["items"] || []

    %{
      visible_items:
        Enum.map(items, fn item ->
          %{
            id: item[:id] || item["id"],
            name: item[:name] || item["name"],
            price: item[:price] || item["price"]
          }
        end)
    }
  end

  defp summarize_data(_, _), do: %{}

  # --- Persistence serialization ---

  @doc """
  Converts the store to a JSON-safe map for JSONB persistence.
  Atom keys → string keys, DateTime → ISO 8601 string.
  """
  def to_persistable(store) do
    %{
      "widgets" => persistable_widgets(store.widgets),
      "layout" => store.layout,
      "conversation" => Enum.map(store.conversation, &persistable_message/1),
      "cart" => Enum.map(store[:cart] || [], &persistable_map/1),
      "wishlist" => Enum.map(store[:wishlist] || [], &persistable_map/1),
      "chat_widgets" => persistable_widgets(store[:chat_widgets] || %{})
    }
  end

  defp persistable_widgets(widgets) do
    Map.new(widgets, fn {id, w} ->
      {id, persistable_map(w)}
    end)
  end

  defp persistable_message(msg) do
    msg
    |> persistable_map()
    |> Map.update("timestamp", nil, fn
      %DateTime{} = dt -> DateTime.to_iso8601(dt)
      other -> other
    end)
  end

  defp persistable_map(map) when is_map(map) do
    Map.new(map, fn
      {k, %DateTime{} = v} -> {to_string(k), DateTime.to_iso8601(v)}
      {k, v} when is_map(v) -> {to_string(k), persistable_map(v)}
      {k, v} when is_list(v) -> {to_string(k), Enum.map(v, &persistable_value/1)}
      {k, v} -> {to_string(k), v}
    end)
  end

  defp persistable_value(v) when is_map(v), do: persistable_map(v)
  defp persistable_value(v), do: v

  @doc """
  Reconstructs a store from persisted JSONB data.
  String keys → atom keys where needed, ISO timestamps → DateTime.
  """
  def from_persistable(data) when is_map(data) do
    %{
      widgets: restore_widgets(data["widgets"] || %{}),
      layout: data["layout"],
      conversation: Enum.map(data["conversation"] || [], &restore_message/1),
      cart: Enum.map(data["cart"] || [], &restore_atom_map/1),
      wishlist: Enum.map(data["wishlist"] || [], &restore_atom_map/1),
      chat_widgets: restore_widgets(data["chat_widgets"] || %{})
    }
  end

  defp restore_widgets(widgets) do
    Map.new(widgets, fn {id, w} ->
      {id, restore_atom_map(w)}
    end)
  end

  defp restore_message(msg) do
    msg
    |> restore_atom_map()
    |> Map.update(:timestamp, nil, &parse_datetime/1)
    |> Map.update(:role, nil, fn
      r when is_binary(r) -> String.to_atom(r)
      r -> r
    end)
  end

  defp restore_atom_map(map) when is_map(map) do
    Map.new(map, fn
      {k, v} when is_map(v) and not is_struct(v) ->
        key = safe_atom_key(k)
        # Keep config/layout as string-keyed maps (they're used with string keys everywhere)
        if key in [:config, :layout] do
          {key, v}
        else
          {key, restore_atom_map(v)}
        end
      {k, v} when is_list(v) ->
        {safe_atom_key(k), Enum.map(v, &restore_value/1)}
      {k, v} ->
        {safe_atom_key(k), v}
    end)
  end

  defp restore_value(v) when is_map(v), do: restore_atom_map(v)
  defp restore_value(v), do: v

  defp safe_atom_key(k) when is_atom(k), do: k
  defp safe_atom_key(k) when is_binary(k) do
    String.to_existing_atom(k)
  rescue
    ArgumentError -> String.to_atom(k)
  end

  defp parse_datetime(nil), do: nil
  defp parse_datetime(%DateTime{} = dt), do: dt
  defp parse_datetime(str) when is_binary(str) do
    case DateTime.from_iso8601(str) do
      {:ok, dt, _offset} -> dt
      _ -> nil
    end
  end
  defp parse_datetime(_), do: nil

  def debug_serialize(store) do
    %{
      widgets:
        Enum.into(store.widgets, %{}, fn {id, w} ->
          {id,
           %{
             type: w[:widget],
             config: w[:config] || %{},
             data: w[:data] || %{}
           }}
        end),
      layout: store.layout,
      message_count: length(store.conversation)
    }
  end
end
