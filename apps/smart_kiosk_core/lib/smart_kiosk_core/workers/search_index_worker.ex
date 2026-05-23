defmodule SmartKioskCore.Workers.SearchIndexWorker do
  use Oban.Worker, queue: :default

  alias SmartKioskCore.{Catalogue, Shops}
  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"type" => "product", "id" => id}}) do
    case Catalogue.get_product_by_id(id) do
      nil ->
        Logger.warning("SearchIndexWorker: Product #{id} not found, skipping indexing.")
        :ok

      product ->
        SmartKioskCore.Search.index_product(product)
    end
  end

  def perform(%Oban.Job{args: %{"type" => "shop", "id" => id}}) do
    case Shops.get_shop(id) do
      nil ->
        Logger.warning("SearchIndexWorker: Shop #{id} not found, skipping indexing.")
        :ok

      shop ->
        SmartKioskCore.Search.index_shop(shop)
    end
  end
end
