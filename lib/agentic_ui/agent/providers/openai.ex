defmodule AgenticUi.Agent.Providers.OpenAI do
  @moduledoc """
  OpenAI-compatible provider (works with OpenAI API, Azure OpenAI, and compatible APIs).
  HTTP client with retry logic. Pattern from argentic-sentinel.
  """
  @behaviour AgenticUi.Agent.Provider

  require Logger

  @impl true
  def name, do: "OpenAI"

  @impl true
  def chat_completion(messages, opts \\ []) do
    model = Keyword.get(opts, :model, agent_config(:model) || "gpt-4o-mini")
    temperature = Keyword.get(opts, :temperature, agent_config(:temperature) || 0.0)
    max_tokens = Keyword.get(opts, :max_tokens)
    response_format = Keyword.get(opts, :response_format)
    tools = Keyword.get(opts, :tools)

    body =
      %{"model" => model, "messages" => messages, "temperature" => temperature}
      |> maybe_put("max_tokens", max_tokens)
      |> maybe_put("response_format", response_format)
      |> maybe_put("tools", tools)

    Logger.info("[PROVIDER:OpenAI] chat_completion model=#{model} messages=#{length(messages)} tools=#{if tools, do: length(tools), else: 0}")

    case make_request("/chat/completions", body) do
      {:ok, response} ->
        message = get_in(response, ["choices", Access.at(0), "message"])
        {:ok, message}

      {:error, _} = err ->
        err
    end
  end

  @impl true
  def format_tools(mcp_tools) do
    Enum.map(mcp_tools, fn tool ->
      %{
        "type" => "function",
        "function" => %{
          "name" => tool["name"],
          "description" => tool["description"],
          "parameters" => tool["inputSchema"]
        }
      }
    end)
  end

  @impl true
  def format_response_format(:json_object), do: %{"type" => "json_object"}
  def format_response_format(_), do: nil

  # --- HTTP request with retry ---

  defp make_request(endpoint, body, retry_count \\ 0) do
    base_url = provider_config(:base_url) || "https://api.openai.com/v1"
    api_key = provider_config(:api_key)
    timeout = provider_config(:request_timeout) || 30_000
    max_retries = provider_config(:max_retries) || 2

    url = base_url <> endpoint

    headers = [
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer #{api_key}"}
    ]

    case HTTPoison.post(url, Jason.encode!(body), headers,
           recv_timeout: timeout,
           timeout: timeout
         ) do
      {:ok, %HTTPoison.Response{status_code: 200, body: resp_body}} ->
        Jason.decode(resp_body)

      {:ok, %HTTPoison.Response{status_code: code, body: err_body}} ->
        Logger.error("OpenAI API error", status: code, body: String.slice(err_body, 0, 200))

        if should_retry?(code, retry_count, max_retries) do
          wait = backoff(retry_count)
          Logger.info("Retrying OpenAI request", attempt: retry_count + 1, wait_ms: wait)
          Process.sleep(wait)
          make_request(endpoint, body, retry_count + 1)
        else
          {:error, {:api_error, code, err_body}}
        end

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("OpenAI network error", reason: inspect(reason))

        if retry_count < max_retries do
          wait = backoff(retry_count)
          Process.sleep(wait)
          make_request(endpoint, body, retry_count + 1)
        else
          {:error, {:network_error, reason}}
        end
    end
  end

  defp should_retry?(_code, retry_count, max_retries) when retry_count >= max_retries, do: false
  defp should_retry?(code, _rc, _mr) when code in [500, 502, 503, 504], do: true
  defp should_retry?(_code, _rc, _mr), do: false

  defp backoff(n), do: min(1000 * round(:math.pow(2, n)), 10_000)

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp provider_config(key) do
    Application.get_env(:agentic_ui, __MODULE__, [])
    |> Keyword.get(key)
  end

  defp agent_config(key) do
    Application.get_env(:agentic_ui, AgenticUi.Agent, [])
    |> Keyword.get(key)
  end
end
