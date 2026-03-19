import Config

# Load .env.local in dev (same pattern as argentic-sentinel)
if config_env() == :dev do
  if File.exists?(".env.local") do
    ".env.local"
    |> File.read!()
    |> String.split("\n")
    |> Enum.reject(&(&1 == "" or String.starts_with?(&1, "#")))
    |> Enum.each(fn line ->
      case String.split(line, "=", parts: 2) do
        [key, value] ->
          if System.get_env(String.trim(key)) == nil do
            System.put_env(String.trim(key), String.trim(value))
          end

        _ ->
          :ok
      end
    end)
  end
end

if System.get_env("PHX_SERVER") do
  config :agentic_ui, AgenticUiWeb.Endpoint, server: true
end

config :agentic_ui, AgenticUiWeb.Endpoint,
  http: [port: String.to_integer(System.get_env("PORT", "4000"))]

# Agent configuration (provider-agnostic)
agent_provider =
  case System.get_env("AGENT_PROVIDER") do
    "openai" -> AgenticUi.Agent.Providers.OpenAI
    nil -> AgenticUi.Agent.Providers.OpenAI
    other -> raise "Unknown AGENT_PROVIDER: #{other}. Supported: openai"
  end

config :agentic_ui, AgenticUi.Agent,
  provider: agent_provider,
  model: System.get_env("AGENT_MODEL") || "gpt-4o-mini",
  temperature: String.to_float(System.get_env("AGENT_TEMPERATURE") || "0.0")

# OpenAI provider configuration
config :agentic_ui, AgenticUi.Agent.Providers.OpenAI,
  api_key: System.get_env("OPENAI_API_KEY"),
  base_url: System.get_env("OPENAI_BASE_URL") || "https://api.openai.com/v1",
  request_timeout: String.to_integer(System.get_env("OPENAI_REQUEST_TIMEOUT") || "30000"),
  max_retries: String.to_integer(System.get_env("OPENAI_MAX_RETRIES") || "3")

# Database (optional — app works in-memory without it)
if database_url = System.get_env("DATABASE_URL") do
  config :agentic_ui, AgenticUi.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")

  config :agentic_ui, :ecto_repos, [AgenticUi.Repo]
end

# Prompt mode: set BUSINESS_PROMPT_ONLY=true to skip the system prompt
# and use only business_prompt.eex (must include its own EEx tags for auto-generated vars)
if System.get_env("BUSINESS_PROMPT_ONLY") == "true" do
  config :agentic_ui, :business_prompt_only, true
end

# DummyJSON configuration
config :agentic_ui, AgenticUi.Services.DummyJsonClient,
  base_url: System.get_env("DUMMYJSON_BASE_URL") || "https://dummyjson.com",
  request_timeout: String.to_integer(System.get_env("DUMMYJSON_REQUEST_TIMEOUT") || "15000"),
  max_retries: String.to_integer(System.get_env("DUMMYJSON_MAX_RETRIES") || "2")

if config_env() == :prod do
  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"

  config :agentic_ui, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :agentic_ui, AgenticUiWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/bandit/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0}
    ],
    secret_key_base: secret_key_base

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :agentic_ui, AgenticUiWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :agentic_ui, AgenticUiWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.
end
