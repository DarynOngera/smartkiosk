defmodule SmartKioskCore.Cart do
  @moduledoc """
  The Cart context.
  """

  import Ecto.Query
  alias SmartKioskCore.Repo
  alias SmartKioskCore.Schemas.{CartItem, Product, User}

  @doc "Returns a list of cart items for a logged-in user."
  def get_user_cart(%User{id: user_id}) do
    Repo.all(from(c in CartItem, where: c.user_id == ^user_id, preload: [product: [:shop, :images]]))
  end

  @doc "Returns a list of cart items for a guest session."
  def get_session_cart(session_id) when is_binary(session_id) do
    Repo.all(from(c in CartItem, where: c.session_id == ^session_id, preload: [product: [:shop, :images]]))
  end

  @doc "Calculates the total amount for a list of cart items."
  def calculate_cart_total(items) do
    Enum.reduce(items, Decimal.new("0"), fn item, acc ->
      Decimal.add(acc, item.line_total)
    end)
  end

  @doc "Fetches a cart item by ID."
  def get_cart_item!(id), do: Repo.get!(CartItem, id)

  @doc "Updates the quantity of a cart item."
  def update_cart_item(%CartItem{} = item, attrs) do
    item
    |> CartItem.changeset(attrs)
    |> Repo.update()
  end

  @doc "Removes a cart item."
  def remove_cart_item(%CartItem{} = item), do: Repo.delete(item)

  @doc "Returns the number of items in the cart for a logged-in user."
  def get_user_cart_count(%User{id: user_id}) do
    Repo.aggregate(from(c in CartItem, where: c.user_id == ^user_id), :count, :id)
  end

  @doc "Returns the number of items in the cart for a guest session."
  def get_session_cart_count(session_id) when is_binary(session_id) do
    Repo.aggregate(from(c in CartItem, where: c.session_id == ^session_id), :count, :id)
  end

  @doc "Adds a product to the cart."
  def add_to_cart(%Product{} = product, quantity, opts) do
    user_id = opts[:user_id]
    session_id = opts[:session_id]

    # Check if item exists in cart already to increment quantity instead
    existing_item =
      case {user_id, session_id} do
        {uid, nil} when not is_nil(uid) ->
          Repo.one(from(c in CartItem, where: c.user_id == ^uid and c.product_id == ^product.id))

        {nil, sid} when not is_nil(sid) ->
          Repo.one(
            from(c in CartItem, where: c.session_id == ^sid and c.product_id == ^product.id)
          )

        _ ->
          nil
      end

    if existing_item do
      existing_item
      |> CartItem.changeset(%{
        quantity: existing_item.quantity + quantity,
        unit_price: existing_item.unit_price
      })
      |> Repo.update()
    else
      %CartItem{}
      |> CartItem.changeset(%{
        product_id: product.id,
        shop_id: product.shop_id,
        product_name: product.name,
        unit_price: product.price,
        quantity: quantity,
        user_id: user_id,
        session_id: session_id
      })
      |> Repo.insert()
    end
  end
end
