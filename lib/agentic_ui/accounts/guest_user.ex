defmodule AgenticUi.Accounts.GuestUser do
  use Ecto.Schema
  import Ecto.Changeset

  schema "guest_users" do
    field :token, Ecto.UUID
    field :last_seen_at, :utc_datetime_usec

    has_one :session, AgenticUi.Accounts.GuestSession

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(guest_user, attrs) do
    guest_user
    |> cast(attrs, [:token, :last_seen_at])
    |> validate_required([:token])
    |> unique_constraint(:token)
  end
end
