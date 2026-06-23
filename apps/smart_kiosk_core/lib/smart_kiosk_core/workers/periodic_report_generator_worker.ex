defmodule SmartKioskCore.Workers.PeriodicReportGeneratorWorker do
  use Oban.Worker, queue: :reports, max_attempts: 1

  alias SmartKioskCore.Schemas.Shop
  alias SmartKioskCore.Workers.ReportGeneratorWorker
  alias SmartKioskCore.Repo

  def perform(%Oban.Job{args: %{"period" => period}}) when period in ["weekly", "monthly"] do
    {starts_at, ends_at} = completed_range(period, DateTime.utc_now())

    Shop
    |> Repo.all()
    |> Enum.each(fn shop ->
      %{
        shop_name: shop.name,
        shop_id: shop.id,
        period: period,
        starts_at: DateTime.to_iso8601(starts_at),
        ends_at: DateTime.to_iso8601(ends_at)
      }
      |> ReportGeneratorWorker.new()
      |> Oban.insert()
    end)

    :ok
  end

  # this os fo rthe weekly reports
  defp completed_range("weekly", now) do
    today = DateTime.to_date(now)
    current_week_start = Date.add(today, 1 - Date.day_of_week(today))
    previous_week_start = Date.add(current_week_start, -7)
    previous_week_end = Date.add(current_week_start, -1)

    starts_at = DateTime.new!(previous_week_start, ~T[00:00:00], "Etc/UTC")
    ends_at = DateTime.new!(previous_week_end, ~T[23:59:59], "Etc/UTC")

    {starts_at, ends_at}
  end

  # this is for the monthly now
  defp completed_range("monthly", now) do
    today = DateTime.to_date(now)
    current_month_start = Date.new!(today.year, today.month, 1)
    previous_month_end = Date.add(current_month_start, -1)
    previous_month_start = Date.new!(previous_month_end.year, previous_month_end.month, 1)

    starts_at = DateTime.new!(previous_month_start, ~T[00:00:00], "Etc/UTC")
    ends_at = DateTime.new!(previous_month_end, ~T[23:59:59], "Etc/UTC")

    {starts_at, ends_at}
  end
end
