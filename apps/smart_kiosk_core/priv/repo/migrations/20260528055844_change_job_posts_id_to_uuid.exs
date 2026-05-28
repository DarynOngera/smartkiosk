defmodule SmartKioskCore.Repo.Migrations.ChangeJobPostsIdToUuid do
  use Ecto.Migration

  def up do
    drop table(:job_posts)

    create table(:job_posts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :description, :text, null: false
      add :requirements, :text, null: false
      add :status, :string, null: false, default: "active"
      add :shop_id, references(:shops, on_delete: :delete_all, type: :binary_id), null: false

      timestamps()
    end

    create index(:job_posts, [:shop_id])
  end

  def down do
    drop table(:job_posts)

    create table(:job_posts) do
      add :title, :string, null: false
      add :description, :text, null: false
      add :requirements, :text, null: false
      add :status, :string, null: false, default: "active"
      add :shop_id, references(:shops, on_delete: :delete_all, type: :binary_id), null: false

      timestamps()
    end

    create index(:job_posts, [:shop_id])
  end
end
