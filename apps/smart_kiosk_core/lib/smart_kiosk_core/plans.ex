defmodule SmartKioskCore.Plans do
  @moduledoc """
  Provides canonical plan definitions for the platform. These are in-memory
  representations used by UI and seeds. There is no DB table for plans yet.
  """

  defmodule Plan do
    defstruct [:name, :slug, :price_cents, :max_products, :max_staff, :max_orders_per_month, :features]
  end

  @plans [
    %{
      name: "Basic",
      slug: "basic",
      price_cents: 0,
      max_products: 50,
      max_staff: 1,
      max_orders_per_month: 100,
      features: %{"analytics" => false, "api_access" => false, "priority_support" => false}
    },
    %{
      name: "Pro",
      slug: "pro",
      price_cents: 1999,
      max_products: 1000,
      max_staff: 5,
      max_orders_per_month: 10_000,
      features: %{"analytics" => true, "api_access" => true, "priority_support" => false}
    },
    %{
      name: "Enterprise",
      slug: "enterprise",
      price_cents: 9999,
      max_products: 100_000,
      max_staff: 50,
      max_orders_per_month: 1_000_000,
      features: %{"analytics" => true, "api_access" => true, "priority_support" => true}
    }
  ]

  @doc "Returns the list of plan structs."
  def list_plans, do: Enum.map(@plans, &struct(Plan, &1))

  @doc "Returns plans formatted as select options: [{Label, atom_slug}]"
  def select_options do
    list_plans()
    |> Enum.map(fn %Plan{slug: slug, name: name} -> {name, slug} end)
  end
end
