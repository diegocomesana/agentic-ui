defmodule AgenticUiWeb.Router do
  use AgenticUiWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {AgenticUiWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug AgenticUiWeb.Plugs.GuestPlug
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", AgenticUiWeb do
    pipe_through :browser

    live "/", WorkspaceLive
  end

  # Other scopes may use custom stacks.
  # scope "/api", AgenticUiWeb do
  #   pipe_through :api
  # end
end
