defmodule SmartKioskCore.Repo.Migrations.AddOwnerIdToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :owner_id, :binary_id
    end

    create index(:users, [:owner_id])
  end
end
