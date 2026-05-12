defmodule SmartKioskWeb.Inventory.EditModal do
  use SmartKioskWeb, :live_component

  alias SmartKioskCore.Catalogue
  alias SmartKioskCore.Schemas.Product

  def update(%{product: product, shop: shop}, socket) do
    changeset = Product.changeset(product, %{})

    {:ok,
     socket
     |> assign(:product, product)
     |> assign(:shop, shop)
     |> assign(:changeset, changeset)
     |> assign(:categories, Catalogue.list_categories())}
  end

  def handle_event("validate", %{"product" => product_params}, socket) do
    changeset =
      socket.assigns.product
      |> Product.changeset(product_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("save", %{"product" => product_params}, socket) do
    _shop = socket.assigns.shop
    product = socket.assigns.product

    case Catalogue.update_product(product, product_params) do
      {:ok, _updated_product} ->
        send(self(), {:product_updated, product.id})
        {:noreply,
         socket
         |> put_flash(:info, "Product updated successfully!")
         |> push_patch(to: "#")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  def handle_event("close", _params, socket) do
    {:noreply, push_patch(socket, to: "#")}
  end
end
