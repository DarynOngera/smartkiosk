defmodule SmartKioskCore.Repo.Migrations.AddRoleToJobPosts do
  use Ecto.Migration

  def change do
    alter table(:job_posts) do
      add(:role, :string)
    end
  end
end
