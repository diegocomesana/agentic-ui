defmodule AgenticUi.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    log_storage_mode()

    children =
      [
        AgenticUiWeb.Telemetry,
        {DNSCluster, query: Application.get_env(:agentic_ui, :dns_cluster_query) || :ignore},
        {Phoenix.PubSub, name: AgenticUi.PubSub}
      ] ++
        maybe_repo() ++
        [
          # Product data cache (ETS)
          AgenticUi.Business.Services.ProductCache,
          # In-memory session store
          AgenticUi.Session,
          # Start to serve requests, typically the last entry
          AgenticUiWeb.Endpoint
        ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: AgenticUi.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp log_storage_mode do
    require Logger

    if Application.get_env(:agentic_ui, :ecto_repos, []) != [] do
      Logger.info("[APP] Storage: PostgreSQL (sessions persist across restarts)")
    else
      Logger.info("[APP] Storage: in-memory (sessions lost on restart). Set DATABASE_URL to enable PostgreSQL.")
    end
  end

  defp maybe_repo do
    if Application.get_env(:agentic_ui, :ecto_repos, []) != [] do
      [AgenticUi.Repo]
    else
      []
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    AgenticUiWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
