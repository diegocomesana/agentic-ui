defmodule AgenticUiWeb.Plugs.HealthCheck do
  @moduledoc """
  Responds with 200 on /healthz for Kubernetes liveness and readiness probes.
  Must be placed early in the Endpoint pipeline, before Plug.SSL / force_ssl.
  """
  import Plug.Conn

  def init(opts), do: opts

  def call(%Plug.Conn{request_path: "/healthz"} = conn, _opts) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, "ok")
    |> halt()
  end

  def call(conn, _opts), do: conn
end
