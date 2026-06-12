defmodule SmartKioskCore.Plans do
  @moduledoc """
  Provides canonical plan definitions for the platform. These are in-memory
  representations used by UI and seeds. There is no DB table for plans yet.

  Plan information is centralized here to enable:
  - Feature gating based on shop plan
  - Consistent plan references across schemas
  - Easy extensibility for future plan features
  """

  defmodule Plan do
    defstruct [
      :name,
      :slug,
      :price_cents,
      :max_products,
      :max_staff,
      :max_riders,
      :max_orders_per_month,
      :features
    ]
  end

  @plans [
    %{
      name: "Basic",
      slug: "basic",
      price_cents: 0,
      max_products: 50,
      max_staff: 1,
      max_riders: 1,
      max_orders_per_month: 100,
      features: %{"analytics" => false, "api_access" => false, "priority_support" => false}
    },
    %{
      name: "Pro",
      slug: "pro",
      price_cents: 1999,
      max_products: 1000,
      max_staff: 5,
      max_riders: 5,
      max_orders_per_month: 10_000,
      features: %{"analytics" => true, "api_access" => true, "priority_support" => false}
    },
    %{
      name: "Enterprise",
      slug: "enterprise",
      price_cents: 9999,
      max_products: 100_000,
      max_staff: 50,
      max_riders: 15,
      max_orders_per_month: 1_000_000,
      features: %{"analytics" => true, "api_access" => true, "priority_support" => true}
    }
  ]

  # Legacy plan mappings for backward compatibility
  @legacy_plans %{
    "kiosk" => "basic",
    "duka" => "pro",
    "biashara" => "enterprise"
  }

  @canonical_plan_atoms ~w(basic pro enterprise)a
  @legacy_plan_atoms ~w(kiosk duka biashara)a
  @all_plan_atoms @canonical_plan_atoms ++ @legacy_plan_atoms

  @doc "Returns the list of plan structs."
  def list_plans, do: Enum.map(@plans, &struct(Plan, &1))

  @doc "Returns plans formatted as select options: [{Label, atom_slug}]"
  def select_options do
    list_plans()
    |> Enum.map(fn %Plan{slug: slug, name: name} -> {name, slug} end)
  end

  @doc "Returns canonical plan atoms: [:basic, :pro, :enterprise]"
  def plan_atoms, do: @canonical_plan_atoms

  @doc "Returns all plan atoms including legacy ones for schema Ecto.Enum"
  def all_plan_atoms, do: @all_plan_atoms

  @doc "Get a plan by slug. Returns Plan struct or nil."
  def get_plan_by_slug(slug) when is_atom(slug), do: get_plan_by_slug(Atom.to_string(slug))

  def get_plan_by_slug(slug) when is_binary(slug) do
    Enum.find(list_plans(), fn plan -> plan.slug == slug end)
  end

  @doc "Normalize plan value to canonical slug atom."
  def normalize_plan(nil), do: :basic

  def normalize_plan(plan) when is_atom(plan), do: normalize_plan(Atom.to_string(plan))

  def normalize_plan(plan) when is_binary(plan) do
    slug = String.downcase(plan)
    # Check if it's a legacy plan name
    canonical_slug = Map.get(@legacy_plans, slug, slug)
    String.to_existing_atom(canonical_slug)
  rescue
    _ -> :basic
  end

  @doc "Check if shop plan has a feature enabled."
  def has_feature?(plan_slug, feature_key) when is_atom(plan_slug) do
    plan = get_plan_by_slug(plan_slug)
    plan && Map.get(plan.features, feature_key, false)
  end

  @doc "Get plan limit for a given key (e.g., :max_products, :max_staff)."
  def get_limit(plan_slug, limit_key) when is_atom(plan_slug) do
    plan = get_plan_by_slug(plan_slug)
    plan && Map.get(plan, limit_key)
  end
end
