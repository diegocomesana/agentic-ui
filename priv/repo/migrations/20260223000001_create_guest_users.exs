defmodule AgenticUi.Repo.Migrations.CreateGuestUsers do
  use Ecto.Migration

  def change do
    create table(:guest_users) do
      add :token, :uuid, null: false
      add :last_seen_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:guest_users, [:token])
  end
end
