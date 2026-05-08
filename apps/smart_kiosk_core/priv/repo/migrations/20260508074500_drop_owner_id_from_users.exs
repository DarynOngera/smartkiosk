defmodule SmartKioskCore.Repo.Migrations.DropOwnerIdFromUsers do
  use Ecto.Migration

  def change do
    # Use raw SQL so this migration is safe to run even if the column/index
    # was already removed by a previous failed run. We provide a reversible
    # down SQL that re-adds the column (without constraints) so migrations
    # remain reversible if needed.

    execute(
      "ALTER TABLE users DROP COLUMN IF EXISTS owner_id",
      "ALTER TABLE users ADD COLUMN owner_id uuid"
    )

    execute(
      "DROP INDEX IF EXISTS index_users_on_owner_id",
      ""
    )
  end
end
