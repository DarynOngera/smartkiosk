defmodule SmartKioskCore.Repo.Migrations.AddOwnerIdToShops do
  use Ecto.Migration

  def change do
    alter table(:shops) do
      add :owner_id, references(:users, type: :uuid, on_delete: :nilify_all)
    end

    create index(:shops, [:owner_id])
  end
end
