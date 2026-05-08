defmodule SmartKioskCore.Repo.Migrations.AddUserIdToCustomers do
  use Ecto.Migration

  def change do
    alter table(:customers) do
      add :user_id, references(:users, type: :binary_id, on_delete: :nilify_all), null: true
    end

    create index(:customers, [:user_id])
  end
end
