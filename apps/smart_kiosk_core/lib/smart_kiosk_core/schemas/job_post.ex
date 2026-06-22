defmodule SmartKioskCore.Schemas.JobPost do
  use Ecto.Schema
  import Ecto.Changeset

  @moduledoc """
  Represents a job posting for a shop, such as a delivery rider position.
  """

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @roles ~w(rider cashier supplier)a
  schema "job_posts" do
    field(:title, :string)
    field(:description, :string)
    field(:requirements, :string)
    field(:status, :string, default: "active")
    field(:role, Ecto.Enum, values: @roles)

    belongs_to(:shop, SmartKioskCore.Schemas.Shop, type: :binary_id)

    timestamps()
  end

  @doc false
  def changeset(job_post, attrs) do
    job_post
    |> cast(attrs, [:title, :description, :requirements, :status, :shop_id, :role])
    |> validate_required([:title, :description, :requirements, :status, :shop_id, :role])
    |> assoc_constraint(:shop)
  end
end
