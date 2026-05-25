defmodule Mix.Tasks.Search.Rebuild do
  @moduledoc """
  Rebuilds the search index from the database.

  ## Examples

      mix search.rebuild
      mix search.rebuild --force

  ## Options

    * `--force` - Force rebuild even if index already has documents
  """

  use Mix.Task

  require Logger

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    force = "--force" in args

    Logger.info("Triggering search index rebuild (force=#{force})...")

    result =
      if force do
        %{"force" => true}
      else
        %{}
      end
      |> SmartKioskCore.Workers.SearchRebuildWorker.new()
      |> Oban.insert()

    case result do
      {:ok, job} ->
        Logger.info("Search rebuild job enqueued: #{job.id}")
        :ok

      {:error, reason} ->
        Logger.error("Failed to enqueue search rebuild: #{inspect(reason)}")
        exit({:shutdown, 1})
    end
  end
end
