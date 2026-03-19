defmodule AgenticUi.Agent.Provider do
  @moduledoc """
  Behaviour for LLM providers.
  Each provider converts MCP-standard tools to its native format
  and normalizes responses to a common shape.
  """

  @doc "Send a chat completion request. Returns {:ok, message_map} or {:error, reason}."
  @callback chat_completion(messages :: [map()], opts :: keyword()) ::
              {:ok, map()} | {:error, term()}

  @doc "Convert MCP-standard tool definitions to the provider's native format."
  @callback format_tools(tools :: [map()]) :: [map()]

  @doc "Convert a generic response format atom (e.g. :json_object) to provider-native format."
  @callback format_response_format(format :: atom() | nil) :: map() | nil

  @doc "Provider name for logging."
  @callback name() :: String.t()
end
