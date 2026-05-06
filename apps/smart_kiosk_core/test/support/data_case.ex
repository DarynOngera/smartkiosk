defmodule SmartKioskCore.DataCase do
  @moduledoc """
  Test case template for tests requiring database access.

  Sets up the SQL sandbox so every test runs in an isolated transaction
  that is rolled back on exit. Import this in any test that touches the Repo.

  Usage:

      use SmartKioskCore.DataCase, async: true
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias SmartKioskCore.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import SmartKioskCore.DataCase
    end
  end

  setup tags do
    SmartKioskCore.DataCase.setup_sandbox(tags)
    :ok
  end

  @doc "Starts the SQL sandbox for a test. Called from setup/1."
  def setup_sandbox(tags) do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(SmartKioskCore.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
  end

  @doc """
  Flattens changeset errors into a map of field → [message] for assertions.

      assert "can't be blank" in errors_on(changeset).name
  """
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
