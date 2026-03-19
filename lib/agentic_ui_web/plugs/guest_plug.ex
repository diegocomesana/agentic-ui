defmodule AgenticUiWeb.Plugs.GuestPlug do
  @moduledoc """
  Assigns a persistent guest_token to anonymous visitors.
  The token is stored in the Phoenix session (cookie-backed).
  """
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_session(conn, :guest_token) do
      nil ->
        token = Ecto.UUID.generate()
        conn |> put_session(:guest_token, token)

      _token ->
        conn
    end
  end
end
