defmodule AgenticUi.Accounts.GuestSession do
  use Ecto.Schema
  import Ecto.Changeset

  schema "sessions" do
    belongs_to :guest_user, AgenticUi.Accounts.GuestUser
    field :store_data, :map, default: %{}

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(session, attrs) do
    session
    |> cast(attrs, [:guest_user_id, :store_data])
    |> validate_required([:guest_user_id])
    |> unique_constraint(:guest_user_id)
    |> foreign_key_constraint(:guest_user_id)
  end
end
