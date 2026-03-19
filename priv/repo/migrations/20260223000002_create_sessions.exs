defmodule AgenticUi.Repo.Migrations.CreateSessions do
  use Ecto.Migration

  def change do
    create table(:sessions) do
      add :guest_user_id, references(:guest_users, on_delete: :delete_all), null: false
      add :store_data, :map, default: %{}

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:sessions, [:guest_user_id])
  end
end
