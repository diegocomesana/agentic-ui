defmodule AgenticUi.Release do
  @moduledoc """
  Release tasks for running migrations in production.
  Called from the entrypoint script before starting the server.
  """

  @app :agentic_ui

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  rescue
    _ -> []
  end

  defp load_app do
    Application.ensure_all_started(:ssl)
    Application.load(@app)
  end
end
