defmodule SmartKioskCore.Workers.ReportGeneratorWorker do
  use Oban.Worker, queue: :reports, max_attempts: 2

  alias SmartKioskCore.{Reports, Repo}

  alias SmartKioskCore.Schemas.Shop

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"shop_id" => shop_id, "period" => period, "starts_at" => starts, "ends_at" => ends}}) do
    shop = Repo.get(Shop, shop_id)
    starts_at = parse_datetime(starts)
    ends_at = parse_datetime(ends)

    summary = Reports.generate_sales_summary(shop, starts_at, ends_at)
    {:ok, report} = Reports.create_report(shop, period, starts_at, ends_at, summary)

    # PDF generate by the way
    # Reports.gen_pdf(report)

    {:ok, %{report_id: report.id}}
  end

  defp parse_datetime(dt) when is_binary(dt) do
    case DateTime.from_iso8601(dt) do
      {:ok, datetime, _offset} -> datetime
      {:error, _} -> nil
    end
  end

  defp parse_datetime(dt), do: dt


end
