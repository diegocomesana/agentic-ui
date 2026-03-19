defmodule AgenticUi.Accounts do
  @moduledoc """
  Context for guest user management and session persistence.
  All functions require the Repo to be available (DATABASE_URL set).
  """
  import Ecto.Query
  alias AgenticUi.Repo
  alias AgenticUi.Accounts.{GuestUser, GuestSession}

  @doc """
  Returns true if the database is configured and available.
  """
  def db_available? do
    Application.get_env(:agentic_ui, :ecto_repos, []) != []
  end

  @doc """
  Finds or creates a guest user by token.
  Updates last_seen_at on every call.
  """
  def find_or_create_guest(token) do
    now = DateTime.utc_now()

    case Repo.one(from g in GuestUser, where: g.token == ^token) do
      nil ->
        %GuestUser{}
        |> GuestUser.changeset(%{token: token, last_seen_at: now})
        |> Repo.insert()

      guest ->
        guest
        |> GuestUser.changeset(%{last_seen_at: now})
        |> Repo.update()
    end
  end

  @doc """
  Loads the persisted session for a guest user.
  Returns {:ok, store_data} or :not_found.
  """
  def load_session(guest_user_id) do
    case Repo.one(from s in GuestSession, where: s.guest_user_id == ^guest_user_id) do
      nil -> :not_found
      session -> {:ok, session.store_data}
    end
  end

  @doc """
  Saves (upserts) the store data for a guest user.
  Creates the session row if it doesn't exist, updates if it does.
  """
  def save_session(guest_user_id, store_data) do
    case Repo.one(from s in GuestSession, where: s.guest_user_id == ^guest_user_id) do
      nil ->
        %GuestSession{}
        |> GuestSession.changeset(%{guest_user_id: guest_user_id, store_data: store_data})
        |> Repo.insert()

      session ->
        session
        |> GuestSession.changeset(%{store_data: store_data})
        |> Repo.update()
    end
  end
end
