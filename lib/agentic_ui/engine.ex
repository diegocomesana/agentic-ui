defmodule AgenticUi.Engine do
  @moduledoc """
  Processes chat messages and widget events.
  Orchestrates agent invocations and service calls.
  """
  require Logger

  alias AgenticUi.Store
  alias AgenticUi.Business.Services.ProductService

  def process_chat(message, store) do
    ctx = generate_state_context(store)
    store = Store.add_message(store, :user, message, ctx)
    context = %{store: store, conversation: store.conversation}
    {:invoke_agent, context, store}
  end

  def apply_agent_response(store, %{message: message, widgets: widgets, layout: layout} = response) do
    ctx = generate_state_context(store)
    store = Store.add_message(store, :assistant, message, ctx)

    # Apply chat widgets (merge into store)
    chat_widgets = Map.get(response, :chat_widgets, [])
    store = apply_chat_widgets(store, chat_widgets)

    # Apply widget mutations
    {store, data_calls} =
      Enum.reduce(widgets, {store, []}, fn widget_op, {s, calls} ->
        Logger.info("[ENGINE] applying widget op: action=#{widget_op["action"]} id=#{widget_op["id"]} type=#{widget_op["type"]}")
        apply_widget_op(s, widget_op, calls)
      end)

    # Apply layout (ensure pinned widgets stay in children)
    store =
      if layout do
        Store.set_layout(store, enforce_pinned_in_layout(store, layout))
      else
        store
      end

    if data_calls == [] do
      {:ok, store}
    else
      {:resolve_data, data_calls, store}
    end
  end

  def resolve_data(store, data_calls) do
    Enum.reduce(data_calls, store, fn {widget_id, call}, acc ->
      case execute_service_call(call, acc) do
        {:ok, data} -> Store.set_widget_data(acc, widget_id, data)
        {:error, _} -> acc
      end
    end)
  end

  defp apply_chat_widgets(store, chat_widgets) when is_list(chat_widgets) do
    Enum.reduce(chat_widgets, store, fn cw, acc ->
      id = cw["id"]
      type = cw["type"]
      config = cw["config"] || %{}

      if id && type do
        Store.put_chat_widget(acc, id, %{widget: type, config: config})
      else
        Logger.warning("[ENGINE] invalid chat_widget: #{inspect(cw)}")
        acc
      end
    end)
  end

  defp apply_chat_widgets(store, _), do: store

  def process_widget_event(widget_id, action, event_data, store) do
    widget = get_in(store, [:widgets, widget_id]) || get_in(store, [:chat_widgets, widget_id])

    # 1. Guard check — short-circuit if guard fails
    case check_guard(widget_id, action, event_data, store) do
      :blocked ->
        {:mechanical, nil, store}

      :pass ->
        # 2. Semantic condition — route to agent if config key is truthy
        case check_semantic_condition(widget_id, action, event_data, store) do
          {:semantic, context, new_store} ->
            {:semantic, context, new_store}

          :pass ->
            # 3. Dispatch chain: spawn_action → reducer → universal → unhandled
            dispatch_mechanical(widget_id, action, event_data, widget, store)
        end
    end
  end

  defp dispatch_mechanical(widget_id, action, event_data, widget, store) do
    case maybe_handle_spawn_action(widget_id, action, event_data, store) do
      {:ok, new_store} ->
        {:mechanical, nil, new_store}

      :not_found ->
        case maybe_handle_reducer(widget_id, action, event_data, store) do
          {:ok, new_store} ->
            {:mechanical, nil, new_store}

          {:ok, new_store, service_call} ->
            {:mechanical, service_call, new_store}

          :not_found ->
            case maybe_handle_universal_action(widget_id, action, store) do
              {:ok, new_store} ->
                {:mechanical, nil, new_store}

              :not_found ->
                Logger.warning("[ENGINE] unhandled widget event: widget=#{widget_id} action=#{action} type=#{widget[:widget]}")
                {:mechanical, nil, store}
            end
        end
    end
  end

  defp resolve_descriptor(widget_type) do
    AgenticUi.Business.Descriptors.Registry.get(widget_type) ||
      AgenticUi.Business.Descriptors.Registry.get_chat_widget(widget_type)
  end

  defp check_guard(widget_id, action, event_data, store) do
    widget = get_in(store, [:widgets, widget_id]) || get_in(store, [:chat_widgets, widget_id])
    widget_type = widget[:widget]
    descriptor_mod = resolve_descriptor(widget_type)

    with mod when mod != nil <- descriptor_mod,
         desc <- mod.descriptor(),
         event_spec when is_map(event_spec) <- get_in(desc, [:events, action]),
         %{non_empty: keys} when is_list(keys) <- event_spec[:guard] do
      if Enum.all?(keys, fn k ->
           val = Map.get(event_data, k)
           val != nil and val != ""
         end) do
        :pass
      else
        Logger.debug("[ENGINE] guard blocked: #{widget_type}.#{action} — empty keys: #{inspect(keys)}")
        :blocked
      end
    else
      _ -> :pass
    end
  end

  defp check_semantic_condition(widget_id, action, event_data, store) do
    widget = get_in(store, [:widgets, widget_id]) || get_in(store, [:chat_widgets, widget_id])
    widget_type = widget[:widget]
    descriptor_mod = resolve_descriptor(widget_type)

    with mod when mod != nil <- descriptor_mod,
         desc <- mod.descriptor(),
         event_spec when is_map(event_spec) <- get_in(desc, [:events, action]),
         config_key when is_binary(config_key) <- event_spec[:semantic_condition] do
      if get_in(widget, [:config, config_key]) == true do
        message = build_semantic_message(event_spec, event_data)
        ctx = generate_state_context(store)
        new_store = Store.add_message(store, :user, message, ctx)
        context = %{store: new_store, conversation: new_store.conversation}
        {:semantic, context, new_store}
      else
        :pass
      end
    else
      _ -> :pass
    end
  end

  defp build_semantic_message(event_spec, event_data) do
    template = event_spec[:semantic_message] || "User action: {action}"

    Regex.replace(~r/\{(\w+)\}/, template, fn _, key ->
      Map.get(event_data, key, key)
    end)
  end

  # --- Spawn Actions ---
  # Pluggable mechanism: descriptors can declare `spawn_actions` to create new widgets
  # mechanically (no agent call) when a widget event fires. See architecture docs for details.

  defp maybe_handle_spawn_action(widget_id, action, event_data, store) do
    widget = get_in(store, [:widgets, widget_id]) || get_in(store, [:chat_widgets, widget_id])
    widget_type = widget[:widget]
    descriptor_mod = resolve_descriptor(widget_type)

    with mod when mod != nil <- descriptor_mod,
         desc <- mod.descriptor(),
         specs when is_list(specs) <- get_in(desc, [:spawn_actions, action]) do
      Logger.info("[ENGINE] spawn_action: #{widget_type}.#{action} → spawning #{length(specs)} widget(s)")

      new_store =
        Enum.reduce(specs, store, fn spec, acc ->
          execute_spawn_spec(spec, event_data, widget_id, acc)
        end)

      {:ok, new_store}
    else
      _ -> :not_found
    end
  end

  defp execute_spawn_spec(spec, event_data, reference_widget_id, store) do
    new_id = interpolate_id(spec.widget_id, event_data)
    config = build_spawn_config(spec, event_data)

    # Create or update the widget
    store = Store.put_widget(store, new_id, %{widget: spec.widget_type, config: config, data: %{}})

    # Insert in layout relative to the reference widget
    store = insert_in_layout_relative(store, new_id, reference_widget_id, spec.position)

    # If replacing, remove the source widget from the store
    store = if spec.position == :replace, do: Store.remove_widget(store, reference_widget_id), else: store

    # Resolve data if the target widget has a data_source
    target_mod = AgenticUi.Business.Descriptors.Registry.get(spec.widget_type)

    if target_mod do
      target_desc = target_mod.descriptor()

      if target_desc[:data_source] && target_desc[:data_source] != "agent_filled" do
        call = build_service_call_from_config(target_desc[:data_source], config)

        case execute_service_call(call, store) do
          {:ok, data} -> Store.set_widget_data(store, new_id, data)
          {:error, _} -> store
        end
      else
        store
      end
    else
      store
    end
  end

  # --- Pluggable Reducers ---
  # Descriptors can declare `reducer: {Module, :function}` on events.
  # Engine looks it up and calls it — no Engine code change needed for new business logic.
  # Supports optional service_call → reducer chaining.

  defp maybe_handle_reducer(widget_id, action, event_data, store) do
    widget = get_in(store, [:widgets, widget_id]) || get_in(store, [:chat_widgets, widget_id])
    widget_type = widget[:widget]
    descriptor_mod = resolve_descriptor(widget_type)

    with mod when mod != nil <- descriptor_mod,
         desc <- mod.descriptor(),
         event_spec when is_map(event_spec) <- get_in(desc, [:events, action]),
         {reducer_mod, reducer_fn} <- event_spec[:reducer] do

      Logger.info("[ENGINE] reducer: #{widget_type}.#{action} → #{inspect(reducer_mod)}.#{reducer_fn}")

      # Build context
      ctx = %{
        widget_id: widget_id,
        action: action,
        event_data: event_data,
        widget: widget,
        service_result: nil,
        reducer_opts: event_spec[:reducer_opts]
      }

      # Optional service call before reducer
      ctx =
        if event_spec[:service_call] do
          params = build_reducer_params(event_spec[:params_map] || %{}, event_data)
          call = build_service_call_from_config(event_spec[:service_call], params)

          case execute_service_call(call, store) do
            {:ok, data} -> %{ctx | service_result: {:ok, data}}
            error -> %{ctx | service_result: error}
          end
        else
          ctx
        end

      # Execute reducer
      new_store = apply(reducer_mod, reducer_fn, [store, ctx])

      # If service_target is declared and service produced data, fill that widget + insert in layout.
      # Without explicit service_target, service data is only for the reducer (via ctx.service_result).
      case {event_spec[:service_target], ctx.service_result} do
        {target, {:ok, data}} when target != nil ->
          target_id = interpolate_id(target, event_data)

          if get_in(new_store, [:widgets, target_id]) do
            new_store = Store.set_widget_data(new_store, target_id, data)
            new_store = insert_in_layout_relative(new_store, target_id, widget_id, :after)
            {:ok, new_store}
          else
            {:ok, new_store}
          end

        _ ->
          # refetch: after reducer mutates config, rebuild service call from data_source
          if event_spec[:refetch] do
            updated_config = get_in(new_store, [:widgets, widget_id, :config]) || %{}
            call = build_service_call_from_config(desc[:data_source], updated_config)
            {:ok, new_store, {widget_id, call}}
          else
            {:ok, new_store}
          end
      end
    else
      _ -> :not_found
    end
  end

  # Universal actions: toggle_pin and close apply to every widget regardless of
  # whether the descriptor declares them. Acts as final fallback.
  defp maybe_handle_universal_action(widget_id, "toggle_pin", store) do
    {:ok, Store.toggle_pin(store, widget_id)}
  end

  defp maybe_handle_universal_action(widget_id, "close", store) do
    if Store.pinned?(store, widget_id) do
      Logger.info("[ENGINE] blocked close on pinned widget: #{widget_id}")
      {:ok, store}
    else
      store = Store.remove_widget(store, widget_id)
      store = Store.remove_from_layout(store, widget_id)
      {:ok, store}
    end
  end

  defp maybe_handle_universal_action(_widget_id, _action, _store), do: :not_found

  defp build_reducer_params(params_map, event_data) do
    Enum.into(params_map, %{}, fn {config_key, event_key} ->
      {config_key, Map.get(event_data, event_key)}
    end)
  end

  defp interpolate_id(template, event_data) do
    Regex.replace(~r/\{(\w+)\}/, template, fn _, key ->
      Map.get(event_data, key, key)
    end)
  end

  defp build_spawn_config(spec, event_data) do
    mapped =
      Enum.into(spec.config_map, %{}, fn {config_key, event_key} ->
        {config_key, Map.get(event_data, event_key)}
      end)

    Map.merge(spec.config_defaults, mapped)
  end

  defp insert_in_layout_relative(store, new_id, reference_id, position) do
    case store.layout do
      %{"children" => children} = layout ->
        # Remove new_id if already present (re-spawn replaces position)
        children = List.delete(children, new_id)

        children =
          case position do
            :top ->
              [new_id | children]

            :bottom ->
              children ++ [new_id]

            :replace ->
              case Enum.find_index(children, &(&1 == reference_id)) do
                nil -> [new_id | children]
                idx -> children |> List.replace_at(idx, new_id)
              end

            relative when relative in [:before, :after] ->
              case Enum.find_index(children, &(&1 == reference_id)) do
                nil ->
                  if relative == :before, do: [new_id | children], else: children ++ [new_id]

                idx ->
                  insert_at = if relative == :before, do: idx, else: idx + 1
                  List.insert_at(children, insert_at, new_id)
              end
          end

        Store.set_layout(store, %{layout | "children" => children})

      _ ->
        # No layout yet — create one with all current widgets
        existing_ids = Map.keys(store.widgets)

        Store.set_layout(store, %{
          "type" => "stack",
          "direction" => "vertical",
          "children" => existing_ids
        })
    end
  end

  # Private

  defp apply_widget_op(store, %{"action" => "add", "type" => "wishlist"} = op, calls) do
    config = op["config"] || %{}
    product_id = config["product_id"]
    product_ids = config["product_ids"] || []

    if product_id || product_ids != [] do
      Logger.info("[ENGINE] Redirecting add+wishlist to add_to_wishlist")
      apply_widget_op(store, Map.put(op, "action", "add_to_wishlist"), calls)
    else
      store = ensure_wishlist_widget(store)
      {store, calls}
    end
  end

  defp apply_widget_op(store, %{"action" => "add", "type" => "cart"} = op, calls) do
    # Agent sometimes sends {"action":"add","type":"cart"} instead of {"action":"add_to_cart"}.
    # Intercept and redirect to add_to_cart logic when product_id or product_ids is present.
    config = op["config"] || %{}
    has_products = config["product_id"] || (config["product_ids"] && config["product_ids"] != [])

    if has_products do
      Logger.info("[ENGINE] Redirecting add+cart to add_to_cart")
      apply_widget_op(store, Map.put(op, "action", "add_to_cart"), calls)
    else
      # No product_id — just show an empty cart widget
      store = ensure_cart_widget(store)
      {store, calls}
    end
  end

  defp apply_widget_op(store, %{"action" => "add"} = op, calls) do
    id = op["id"]
    type = op["type"]
    config = op["config"] || %{}
    data = op["data"] || %{}

    # Validate config against descriptor schema (clamp enum values, etc.)
    config = validate_config(type, config)

    # Preserve pinned and locked flags if widget already exists
    existing_pinned = get_in(store, [:widgets, id, :pinned]) == true
    existing_locked = get_in(store, [:widgets, id, :locked]) == true
    store = Store.put_widget(store, id, %{widget: type, config: config, data: data, pinned: existing_pinned, locked: existing_locked})

    # Check if widget needs data from a service
    descriptor_mod = AgenticUi.Business.Descriptors.Registry.get(type)

    if descriptor_mod do
      desc = descriptor_mod.descriptor()

      if desc[:data_source] && desc[:data_source] != "agent_filled" && data == %{} do
        call = {id, build_service_call_from_config(desc[:data_source], config)}
        {store, [call | calls]}
      else
        {store, calls}
      end
    else
      {store, calls}
    end
  end

  defp apply_widget_op(store, %{"action" => "update"} = op, calls) do
    id = op["id"]
    config = op["config"]
    data = op["data"]

    # Validate config against descriptor schema if we know the widget type
    config =
      if config do
        widget = get_in(store, [:widgets, id])
        type = widget && widget[:widget]
        if type, do: validate_config(type, config), else: config
      else
        config
      end

    # Never allow agent to change pinned flag via update
    store =
      if config do
        current = get_in(store, [:widgets, id])

        if current do
          merged_config = Map.merge(current[:config] || %{}, config)
          put_in(store, [:widgets, id, :config], merged_config)
        else
          Logger.warning("[ENGINE] update op for non-existent widget #{id}, skipping config update")
          store
        end
      else
        store
      end

    store =
      if data && data != %{} do
        Store.set_widget_data(store, id, data)
      else
        store
      end

    # If config changed and widget has a data_source, re-fetch data
    if config do
      widget = get_in(store, [:widgets, id])
      type = widget[:widget]
      descriptor_mod = AgenticUi.Business.Descriptors.Registry.get(type)

      if descriptor_mod do
        desc = descriptor_mod.descriptor()

        if desc[:data_source] && desc[:data_source] != "agent_filled" do
          call = {id, build_service_call_from_config(desc[:data_source], widget[:config])}
          {store, [call | calls]}
        else
          {store, calls}
        end
      else
        {store, calls}
      end
    else
      {store, calls}
    end
  end

  # Smart redirect: agent sends "remove" but actually means "remove_from_cart"
  # Detect when config has product_id or product_ids and redirect
  defp apply_widget_op(store, %{"action" => "remove", "type" => "cart"} = op, calls) do
    config = op["config"] || %{}
    has_product = config["product_id"] || config["product_ids"]

    if has_product do
      Logger.info("[ENGINE] redirecting remove+cart+product_id to remove_from_cart")
      apply_widget_op(store, Map.put(op, "action", "remove_from_cart"), calls)
    else
      do_remove_widget(store, op, calls)
    end
  end

  defp apply_widget_op(store, %{"action" => "remove"} = op, calls) do
    do_remove_widget(store, op, calls)
  end

  defp apply_widget_op(store, %{"action" => "add_to_cart"} = op, calls) do
    config = op["config"] || %{}
    product_ids = config["product_ids"] || []
    single_id = config["product_id"]
    qty = parse_int(config["quantity"], 1)

    ids =
      if product_ids != [],
        do: Enum.map(product_ids, &to_string/1),
        else: if(single_id, do: [to_string(single_id)], else: [])

    store =
      Enum.reduce(ids, store, fn pid, acc ->
        case ProductService.get_detail(pid) do
          {:ok, product} ->
            Store.add_to_cart(acc, product, qty)

          {:error, _} ->
            Logger.warning("[ENGINE] add_to_cart failed: product #{pid} not found")
            acc
        end
      end)

    store = if ids != [], do: ensure_cart_widget(store), else: store
    {store, calls}
  end

  defp apply_widget_op(store, %{"action" => "set_cart_qty"} = op, calls) do
    product_id = get_in(op, ["config", "product_id"]) || ""
    qty = parse_int(get_in(op, ["config", "quantity"]), 1)
    {Store.set_cart_qty(store, to_string(product_id), qty), calls}
  end

  defp apply_widget_op(store, %{"action" => "remove_from_cart"} = op, calls) do
    config = op["config"] || %{}
    product_ids = config["product_ids"] || []
    single_id = config["product_id"]

    ids =
      if product_ids != [],
        do: Enum.map(product_ids, &to_string/1),
        else: if(single_id, do: [to_string(single_id)], else: [])

    store = Enum.reduce(ids, store, fn pid, acc -> Store.remove_from_cart(acc, pid) end)
    {store, calls}
  end

  defp apply_widget_op(store, %{"action" => "clear_cart"}, calls) do
    {Store.clear_cart(store), calls}
  end

  defp apply_widget_op(store, %{"action" => "add_to_wishlist"} = op, calls) do
    config = op["config"] || %{}
    product_ids = config["product_ids"] || []
    single_id = config["product_id"]

    # Support both single product_id and bulk product_ids array
    ids = if product_ids != [], do: Enum.map(product_ids, &to_string/1), else: if(single_id, do: [to_string(single_id)], else: [])

    store =
      Enum.reduce(ids, store, fn pid, acc ->
        case ProductService.get_detail(pid) do
          {:ok, product} ->
            Store.add_to_wishlist(acc, product)

          {:error, _} ->
            Logger.warning("[ENGINE] add_to_wishlist failed: product #{pid} not found")
            acc
        end
      end)

    store = if ids != [], do: ensure_wishlist_widget(store), else: store
    {store, calls}
  end

  defp apply_widget_op(store, %{"action" => "remove_from_wishlist"} = op, calls) do
    product_id = get_in(op, ["config", "product_id"]) || ""
    {Store.remove_from_wishlist(store, to_string(product_id)), calls}
  end

  defp apply_widget_op(store, %{"action" => "clear_wishlist"}, calls) do
    {Store.clear_wishlist(store), calls}
  end

  defp apply_widget_op(store, %{"action" => "pin"} = op, calls) do
    id = op["id"]

    if get_in(store, [:widgets, id]) do
      {Store.set_pinned(store, id, true), calls}
    else
      Logger.warning("[ENGINE] pin failed: widget #{id} not found")
      {store, calls}
    end
  end

  defp apply_widget_op(store, %{"action" => "unpin"} = op, calls) do
    id = op["id"]

    if get_in(store, [:widgets, id]) do
      {Store.set_pinned(store, id, false), calls}
    else
      Logger.warning("[ENGINE] unpin failed: widget #{id} not found")
      {store, calls}
    end
  end

  defp apply_widget_op(store, %{"action" => "clear_all"}, calls) do
    {Store.clear_unpinned_widgets(store), calls}
  end

  defp apply_widget_op(store, op, calls) do
    Logger.warning("[ENGINE] unrecognized widget op: #{inspect(op)}")
    {store, calls}
  end

  defp do_remove_widget(store, op, calls) do
    id = op["id"]

    if Store.pinned?(store, id) do
      Logger.info("[ENGINE] blocked remove on pinned widget: #{id}")
      {store, calls}
    else
      # When removing bucket widgets, also clear the underlying data
      store = if id == "wishlist", do: Store.clear_wishlist(store), else: store
      store = if id == "cart", do: Store.clear_cart(store), else: store
      {Store.remove_widget(store, id), calls}
    end
  end

  defp build_service_call_from_config("product_service.list_products", config) do
    %{service: "product_service", method: "list_products", params: config}
  end

  defp build_service_call_from_config("product_service.get_detail", config) do
    %{service: "product_service", method: "get_detail", params: %{id: config["product_id"]}}
  end

  defp build_service_call_from_config("product_service.list_categories", _config) do
    %{service: "product_service", method: "list_categories", params: %{}}
  end

  defp build_service_call_from_config("product_service.compare_products", config) do
    ids = config["product_ids"] || config[:product_ids] || []
    %{service: "product_service", method: "compare_products", params: %{ids: ids}}
  end

  defp build_service_call_from_config("product_service.get_products_by_ids", config) do
    ids = config["product_ids"] || config[:product_ids] || []
    %{service: "product_service", method: "get_products_by_ids", params: %{ids: ids}}
  end

  defp build_service_call_from_config("product_service.top_products", config) do
    %{service: "product_service", method: "top_products", params: config}
  end

  defp build_service_call_from_config(_, _config), do: nil

  def execute_service_call(%{service: "product_service", method: "list_categories"}, _store) do
    Logger.info("[ENGINE] service=product_service method=list_categories")
    {:ok, %{categories: ProductService.categories()}}
  end

  def execute_service_call(%{service: "product_service", method: "list_products", params: params}, _store) do
    Logger.info("[ENGINE] service=product_service method=list_products params=#{inspect(params)}")
    {:ok, ProductService.list_products(params)}
  end

  def execute_service_call(%{service: "product_service", method: "get_detail", params: %{id: id}}, _store) do
    Logger.info("[ENGINE] service=product_service method=get_detail params=#{inspect(%{id: id})}")
    ProductService.get_detail(id)
  end

  def execute_service_call(%{service: "product_service", method: "compare_products", params: %{ids: ids}}, _store) do
    Logger.info("[ENGINE] service=product_service method=compare_products params=#{inspect(%{ids: ids})}")
    products = ProductService.get_products_by_ids(ids)
    {:ok, %{products: products}}
  end

  def execute_service_call(%{service: "product_service", method: "get_products_by_ids", params: %{ids: ids}}, _store) do
    Logger.info("[ENGINE] service=product_service method=get_products_by_ids params=#{inspect(%{ids: ids})}")
    products = ProductService.get_products_by_ids(ids)
    {:ok, %{products: products}}
  end

  def execute_service_call(%{service: "product_service", method: "top_products", params: params}, _store) do
    Logger.info("[ENGINE] service=product_service method=top_products params=#{inspect(params)}")
    items = ProductService.top_products(params)
    {:ok, %{items: items}}
  end

  def execute_service_call(nil, _store), do: {:error, :no_call}
  def execute_service_call(_, _store), do: {:error, :unknown_service}

  defp enforce_pinned_in_layout(store, layout) do
    pinned_ids =
      store.widgets
      |> Enum.filter(fn {_id, w} -> w[:pinned] == true || w[:locked] == true end)
      |> Enum.map(fn {id, _} -> id end)

    case layout do
      %{"children" => children} = l when is_list(children) ->
        missing = Enum.reject(pinned_ids, &(&1 in children))

        if missing == [] do
          l
        else
          Logger.info("[ENGINE] enforcing pinned widgets in layout: #{inspect(missing)}")
          %{l | "children" => missing ++ children}
        end

      _ ->
        layout
    end
  end

  @doc """
  Resolves data for default/initial widgets using their descriptor data_source.
  Called once during mount to populate default widgets with data.
  """
  def resolve_initial_data(store, mode \\ :agent_on) do
    Enum.reduce(AgenticUi.Business.DefaultState.data_calls(mode), store, fn {widget_id, data_source, config}, acc ->
      call = build_service_call_from_config(data_source, config)

      case execute_service_call(call, acc) do
        {:ok, data} -> Store.set_widget_data(acc, widget_id, data)
        {:error, _} -> acc
      end
    end)
  end

  defp ensure_cart_widget(store) do
    if get_in(store, [:widgets, "cart"]) do
      store
    else
      store = Store.put_widget(store, "cart", %{widget: "cart", config: %{}, data: %{}})
      update_layout_add(store, "cart")
    end
  end

  defp ensure_wishlist_widget(store) do
    if get_in(store, [:widgets, "wishlist"]) do
      store
    else
      store = Store.put_widget(store, "wishlist", %{widget: "wishlist", config: %{}, data: %{}})
      update_layout_add(store, "wishlist")
    end
  end

  defp update_layout_add(store, new_widget_id) do
    Store.add_to_layout(store, new_widget_id)
  end

  defp parse_int(nil, default), do: default
  defp parse_int(val, _default) when is_integer(val), do: val
  defp parse_int(val, default) when is_binary(val) do
    case Integer.parse(val) do
      {n, _} -> n
      :error -> default
    end
  end
  defp parse_int(val, _default) when is_float(val), do: round(val)
  defp parse_int(_, default), do: default

  defp generate_state_context(store) do
    case AgenticUi.Business.UiConfig.config()[:state_summarizer] do
      nil ->
        nil

      mod when is_atom(mod) ->
        try do
          mod.summarize(store)
        rescue
          e ->
            Logger.warning("[ENGINE] state summarizer failed: #{inspect(e)}")
            nil
        end
    end
  end

  # Validate agent-provided config against descriptor schema.
  # Clamps enum values to the nearest valid option.
  defp validate_config(type, config) when is_binary(type) and is_map(config) do
    descriptor_mod = AgenticUi.Business.Descriptors.Registry.get(type)

    if descriptor_mod do
      schema = descriptor_mod.descriptor()[:config_schema] || %{}

      Enum.reduce(schema, config, fn {key, spec}, acc ->
        str_key = to_string(key)

        case {Map.has_key?(acc, str_key), spec[:enum]} do
          {true, valid_values} when is_list(valid_values) and valid_values != [] ->
            raw = acc[str_key]
            val = if is_binary(raw), do: parse_int(raw, raw), else: raw

            if val in valid_values do
              acc
            else
              default = spec[:default] || List.first(valid_values)
              Logger.warning("[ENGINE] Config #{str_key}=#{inspect(val)} not in #{inspect(valid_values)} for #{type}, using #{default}")
              Map.put(acc, str_key, default)
            end

          _ ->
            acc
        end
      end)
    else
      config
    end
  end

  defp validate_config(_type, config), do: config

end
