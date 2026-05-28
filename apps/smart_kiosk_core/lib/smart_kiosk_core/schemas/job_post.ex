defmodule SmartKioskCore.Schemas.JobPost do
  use Ecto.Schema
  import Ecto.Changeset

  @moduledoc """
  Represents a job posting for a shop, such as a delivery rider position.
  """

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "job_posts" do
    field(:title, :string)
    field(:description, :string)
    field(:requirements, :string)
    field(:status, :string, default: "active")

    belongs_to(:shop, SmartKioskCore.Schemas.Shop, type: :binary_id)

    timestamps()
  end

  @doc false
  def changeset(job_post, attrs) do
    job_post
    |> cast(attrs, [:title, :description, :requirements, :status, :shop_id])
    |> validate_required([:title, :description, :requirements, :status, :shop_id])
    |> assoc_constraint(:shop)
  end
end
