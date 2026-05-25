defmodule SmartKioskCore.Repo.Migrations.CreateRecommendations do
  use Ecto.Migration

  def change do
    create table(:recommendations, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:type, :string, null: false)
      add(:shop_id, references(:shops, on_delete: :delete_all, type: :binary_id), null: false)
      add(:product_id, references(:products, on_delete: :delete_all, type: :binary_id))
      add(:score, :float, null: false)
      add(:rank, :integer, null: false)
      add(:metadata, :map, default: %{})

      timestamps(type: :utc_datetime)
    end

    create(index(:recommendations, [:type, :rank]))
    create(unique_index(:recommendations, [:type, :shop_id, :product_id]))
  end
end
