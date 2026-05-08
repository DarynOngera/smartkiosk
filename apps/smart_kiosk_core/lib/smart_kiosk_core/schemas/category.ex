defmodule SmartKioskCore.Schemas.Category do
  @moduledoc """
  Product categories. Self-referential tree (one level of parent/child is enough for now).

  `attribute_templates` is a JSONB list of attribute definitions that drive
  the dynamic product form for shops in this category.

  Template shape:
    [
      %{
        "key"      => "expiry_date",
        "label"    => "Expiry Date",
        "type"     => "date",        # text | number | boolean | date | select
        "required" => true,
        "options"  => nil            # list of strings for select type
      },
      ...
    ]
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "categories" do
    field :name,                :string
    field :slug,                :string
    field :icon,                :string   # Tabler icon name e.g. "ti-pill"
    field :description,         :string
    field :attribute_templates, {:array, :map}, default: []
    field :position,            :integer, default: 0

    belongs_to :parent, __MODULE__, foreign_key: :parent_id
    has_many   :children, __MODULE__, foreign_key: :parent_id
    has_many   :products, SmartKioskCore.Schemas.Product

    timestamps(type: :utc_datetime)
  end

  def changeset(category, attrs) do
    category
    |> cast(attrs, [:name, :slug, :icon, :description, :attribute_templates, :position, :parent_id])
    |> validate_required([:name])
    |> validate_length(:name, min: 2, max: 80)
    |> put_slug()
    |> unique_constraint(:slug)
    |> validate_attribute_templates()
  end

  # Generate slug from name
  defp put_slug(%Ecto.Changeset{valid?: true, changes: %{name: name}} = cs) do
    put_change(cs, :slug, Slug.slugify(name))
  end
  defp put_slug(cs), do: cs

  # Validate attribute templates structure
  defp validate_attribute_templates(changeset) do
    templates = get_change(changeset, :attribute_templates, [])

    valid? =
      Enum.all?(templates, fn t ->
        is_map(t) and
          Map.has_key?(t, "key") and
          Map.has_key?(t, "label") and
          Map.has_key?(t, "type") and
          t["type"] in ~w(text number boolean date select)
      end)

    if valid? do
      changeset
    else
      add_error(changeset, :attribute_templates, "each template must have key, label, and a valid type")
    end
  end
end
