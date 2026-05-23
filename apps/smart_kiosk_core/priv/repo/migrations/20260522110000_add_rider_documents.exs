defmodule SmartKioskCore.Repo.Migrations.AddRiderDocuments do
  use Ecto.Migration

  def change do
    # Make migration idempotent: use raw SQL with IF NOT EXISTS so it can be
    # re-run safely if the columns already exist (e.g., from manual changes).
    execute("ALTER TABLE riders ADD COLUMN IF NOT EXISTS license_url varchar")
    execute("ALTER TABLE riders ADD COLUMN IF NOT EXISTS national_id_url varchar")
    execute("ALTER TABLE riders ADD COLUMN IF NOT EXISTS verification_status varchar DEFAULT 'pending'")
  end
end
