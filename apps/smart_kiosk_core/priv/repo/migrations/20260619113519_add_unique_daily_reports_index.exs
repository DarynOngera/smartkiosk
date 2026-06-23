defmodule SmartKioskCore.Repo.Migrations.AddUniqueDailyReportsIndex do
  use Ecto.Migration

  def change do
    execute("""
    DELETE FROM reports
    WHERE id IN (
      SELECT id
      FROM (
        SELECT
          id,
          row_number() OVER (
            PARTITION BY shop_id, period, starts_at, ends_at
            ORDER BY inserted_at DESC, id DESC
          ) AS duplicate_rank
        FROM reports
        WHERE period = 'daily'
      ) ranked_reports
      WHERE duplicate_rank > 1
    )
    """)

    create(
      unique_index(:reports, [:shop_id, :period, :starts_at, :ends_at],
        where: "period = 'daily'",
        name: :reports_daily_once_per_period_index
      )
    )
  end
end
