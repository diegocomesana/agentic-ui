defmodule AgenticUiWeb.PageControllerTest do
  use AgenticUiWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Agentic UI"
  end
end
