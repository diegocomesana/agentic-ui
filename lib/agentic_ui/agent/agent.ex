defmodule AgenticUi.Agent do
  @moduledoc """
  Agent that receives conversation context and returns UI mutations.
  Uses LLM tool calling to query product data on demand,
  then returns a structured JSON response with widget instructions.
  Provider-agnostic: delegates to the configured AgenticUi.Agent.Provider implementation.
  """
  require Logger

  alias AgenticUi.Business.Descriptors.Registry
  alias AgenticUi.Store
  alias AgenticUi.Business.Tools

  @system_prompt_path Path.expand("prompts/system_prompt.eex", __DIR__)
  @external_resource @system_prompt_path
  @system_prompt_template File.read!(@system_prompt_path)

  @business_prompt_path Path.expand("../../../business/prompts/business_prompt.eex", __DIR__)
  @external_resource @business_prompt_path
  @business_prompt_template File.read!(@business_prompt_path)

  @max_tool_rounds 20

  defp provider do
    Application.get_env(:agentic_ui, __MODULE__, [])
    |> Keyword.get(:provider, AgenticUi.Agent.Providers.OpenAI)
  end

  def invoke(context) do
    system_prompt = build_system_prompt(context)
    messages = build_messages(system_prompt, context.conversation)
    mcp_tools = Tools.Registry.definitions()
    tools = provider().format_tools(mcp_tools)

    system_chars = String.length(system_prompt)
    history_count = length(messages) - 1
    model = Application.get_env(:agentic_ui, __MODULE__, []) |> Keyword.get(:model, "gpt-4o-mini")
    provider_name = provider().name()
    Logger.info("[AGENT] invoking provider=#{provider_name} model=#{model} system_prompt=#{system_chars} chars, history=#{history_count} messages, tools=#{length(tools)}")

    run_tool_loop(messages, tools, 0)
  end

  defp run_tool_loop(_messages, _tools, round) when round >= @max_tool_rounds do
    Logger.error("[AGENT] tool loop exceeded max rounds (#{@max_tool_rounds})")
    {:error, :tool_loop_limit}
  end

  defp run_tool_loop(messages, tools, round) do
    response_format = provider().format_response_format(:json_object)

    case provider().chat_completion(messages,
           tools: tools,
           response_format: response_format
         ) do
      {:ok, %{"tool_calls" => tool_calls} = message} when is_list(tool_calls) and tool_calls != [] ->
        Logger.info("[AGENT] round #{round + 1}: #{length(tool_calls)} tool call(s)")

        # Append the assistant message (with tool_calls) to the conversation
        assistant_msg = %{
          "role" => "assistant",
          "content" => message["content"],
          "tool_calls" => tool_calls
        }

        # Execute each tool call and build tool result messages
        tool_results =
          Enum.map(tool_calls, fn tc ->
            func = tc["function"]
            name = func["name"]
            args = parse_tool_args(func["arguments"])

            Logger.info("[AGENT] executing tool=#{name} args=#{inspect(args)}")

            result =
              case Tools.Registry.execute(name, args) do
                {:ok, data} -> Jason.encode!(data)
                {:error, reason} -> Jason.encode!(%{error: inspect(reason)})
              end

            %{
              "role" => "tool",
              "tool_call_id" => tc["id"],
              "content" => result
            }
          end)

        run_tool_loop(messages ++ [assistant_msg | tool_results], tools, round + 1)

      {:ok, message} when is_map(message) ->
        content = message["content"]
        Logger.info("[AGENT] final response received: #{String.length(content || "")} chars (rounds: #{round + 1})")

        case Jason.decode(content || "") do
          {:ok, _} ->
            parse_response(content)

          {:error, _reason} ->
            # Try to recover from concatenated JSONs before expensive retry
            case extract_best_json(content || "") do
              {:ok, parsed} ->
                Logger.info("[AGENT] recovered JSON from concatenated response")
                validate_response(parsed, content)

              :error ->
                Logger.warning("[AGENT] invalid JSON, retrying once with correction prompt")
                retry_msg = %{"role" => "user", "content" => "Your previous response was not valid JSON. Please respond with valid JSON matching the required format: {\"message\": \"...\", \"widgets\": [...], \"layout\": ...}"}
                retry_messages = messages ++ [%{"role" => "assistant", "content" => content}, retry_msg]

                case provider().chat_completion(retry_messages,
                       tools: tools,
                       response_format: response_format
                     ) do
                  {:ok, retry_message} when is_map(retry_message) ->
                    retry_content = retry_message["content"]
                    Logger.info("[AGENT] retry response: #{String.length(retry_content || "")} chars")
                    parse_response(retry_content)

                  _ ->
                    Logger.error("[AGENT] retry also failed, falling back to text")
                    {:ok, %{message: content || "", widgets: [], layout: nil}}
                end
            end
        end

      {:error, reason} ->
        Logger.error("[AGENT] invoke failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp build_system_prompt(context) do
    bindings = prompt_bindings(context)

    case Application.get_env(:agentic_ui, :business_prompt_only, false) do
      true ->
        EEx.eval_string(@business_prompt_template, bindings)

      _ ->
        business_content = EEx.eval_string(@business_prompt_template, bindings)
        EEx.eval_string(@system_prompt_template, Keyword.put(bindings, :business_content, business_content))
    end
  end

  defp prompt_bindings(context) do
    pinned_widgets =
      context.store.widgets
      |> Enum.filter(fn {_id, w} -> w[:pinned] == true end)
      |> Enum.map(fn {id, _w} -> id end)

    [
      catalog: Registry.catalog_for_agent() |> Jason.encode!(pretty: true),
      ui_snapshot: Store.serialize(context.store) |> Jason.encode!(pretty: true),
      widget_instructions: Registry.agent_instructions(),
      widget_types: Registry.widget_type_names(),
      pinned_widgets: pinned_widgets,
      chat_widget_catalog: Registry.chat_widget_catalog_for_agent() |> Jason.encode!(pretty: true),
      chat_widget_types: Registry.chat_widget_type_names()
    ]
  end

  defp build_messages(system_prompt, conversation) do
    history =
      conversation
      |> Enum.take(-20)
      |> Enum.map(fn msg ->
        content =
          case msg[:state_context] do
            nil -> msg.content
            "" -> msg.content
            ctx -> msg.content <> "\n---\nState: " <> ctx
          end

        %{"role" => to_string(msg.role), "content" => content}
      end)

    [%{"role" => "system", "content" => system_prompt} | history]
  end

  defp parse_tool_args(args) when is_binary(args) do
    case Jason.decode(args) do
      {:ok, parsed} -> parsed
      {:error, _} -> %{}
    end
  end

  defp parse_tool_args(args) when is_map(args), do: args
  defp parse_tool_args(_), do: %{}

  defp parse_response(content) when is_binary(content) do
    case Jason.decode(content) do
      {:ok, parsed} ->
        validate_response(parsed, content)

      {:error, _reason} ->
        # Try to extract individual JSON objects from concatenated response
        case extract_best_json(content) do
          {:ok, parsed} ->
            Logger.info("[AGENT] recovered JSON from concatenated response")
            validate_response(parsed, content)

          :error ->
            Logger.error("[AGENT] failed to parse JSON response, content: #{String.slice(content, 0, 500)}")
            {:ok, %{message: content, widgets: [], layout: nil}}
        end
    end
  end

  defp parse_response(nil) do
    {:error, :empty_response}
  end

  # Extract and MERGE individual JSON objects from a concatenated string like "{...}{...}"
  # Merges all widget/action operations from all objects to avoid losing ops.
  defp extract_best_json(content) do
    # Find all top-level JSON objects by tracking brace depth
    jsons = split_json_objects(content)

    parsed =
      jsons
      |> Enum.map(fn str ->
        case Jason.decode(str) do
          {:ok, map} when is_map(map) -> map
          _ -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    case parsed do
      [] -> :error
      [single] -> {:ok, single}
      objects ->
        Logger.info("[AGENT] extract_best_json: merging #{length(objects)} JSON objects")

        # Merge all widget/action ops from every object
        all_widgets = Enum.flat_map(objects, fn obj -> obj["widgets"] || [] end)
        all_actions = Enum.flat_map(objects, fn obj -> obj["actions"] || [] end)
        all_chat_widgets = Enum.flat_map(objects, fn obj -> obj["chat_widgets"] || [] end)

        # Take message from the object with the longest message
        message = objects
          |> Enum.map(fn obj -> obj["message"] || "" end)
          |> Enum.max_by(&String.length/1)

        # Take layout from the last object that has one
        layout = objects
          |> Enum.map(fn obj -> obj["layout"] end)
          |> Enum.reject(&is_nil/1)
          |> List.last()

        # Build merged result — put ops in whichever key they came from
        merged = %{"message" => message, "layout" => layout}
        merged = if all_widgets != [], do: Map.put(merged, "widgets", all_widgets), else: merged
        merged = if all_actions != [], do: Map.put(merged, "actions", all_actions), else: merged
        merged = if all_chat_widgets != [], do: Map.put(merged, "chat_widgets", all_chat_widgets), else: merged

        total_ops = length(all_widgets) + length(all_actions)
        Logger.info("[AGENT] extract_best_json: merged result has #{total_ops} total ops")

        {:ok, merged}
    end
  end

  defp split_json_objects(str) do
    str
    |> String.graphemes()
    |> Enum.reduce({[], 0, []}, fn char, {objects, depth, current} ->
      case char do
        "{" ->
          new_depth = depth + 1
          {objects, new_depth, current ++ [char]}

        "}" ->
          new_depth = depth - 1
          new_current = current ++ [char]
          if new_depth == 0 do
            {objects ++ [Enum.join(new_current)], 0, []}
          else
            {objects, new_depth, new_current}
          end

        _ ->
          if depth > 0, do: {objects, depth, current ++ [char]}, else: {objects, depth, current}
      end
    end)
    |> elem(0)
  end

  defp validate_response(parsed, _raw) when is_map(parsed) do
    message = Map.get(parsed, "message")
    # Accept "actions" as alias for "widgets" (agent sometimes uses wrong key)
    # Note: [] is truthy in Elixir, so we must explicitly check for nil/empty
    raw_widgets = Map.get(parsed, "widgets")
    raw_actions = Map.get(parsed, "actions")
    widgets = if raw_widgets == nil or raw_widgets == [], do: raw_actions, else: raw_widgets
    layout = Map.get(parsed, "layout")
    raw_chat_widgets = Map.get(parsed, "chat_widgets")

    message =
      cond do
        is_binary(message) -> message
        is_nil(message) -> ""
        true ->
          Logger.warning("[AGENT] invalid message type: #{inspect(message)}, using empty string")
          ""
      end

    widgets =
      cond do
        is_list(widgets) -> Enum.filter(widgets, &is_map/1)
        is_nil(widgets) -> []
        true ->
          Logger.warning("[AGENT] invalid widgets type: #{inspect(widgets)}, using empty list")
          []
      end

    layout =
      cond do
        is_map(layout) -> layout
        is_nil(layout) -> nil
        true ->
          Logger.warning("[AGENT] invalid layout type: #{inspect(layout)}, using nil")
          nil
      end

    chat_widgets =
      cond do
        is_list(raw_chat_widgets) -> Enum.filter(raw_chat_widgets, &is_map/1)
        is_nil(raw_chat_widgets) -> []
        true ->
          Logger.warning("[AGENT] invalid chat_widgets type: #{inspect(raw_chat_widgets)}, using empty list")
          []
      end

    {:ok, %{message: message, widgets: widgets, layout: layout, chat_widgets: chat_widgets}}
  end
end
