defmodule SmartKioskCore.Repo.Migrations.AddCategoryToShops do
  use Ecto.Migration

  def change do
    alter table(:shops) do
      add :category, :string, null: false, default: "general_shop"
    end
  end
end
