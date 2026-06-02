defmodule SmartKioskCore.Repo.Migrations.AddJobPostIdToRiders do
  use Ecto.Migration

  def change do
    alter table(:riders) do
      add :job_post_id, references(:job_posts, type: :uuid, on_delete: :nilify_all)
    end

    create index(:riders, [:job_post_id])
  end
end
