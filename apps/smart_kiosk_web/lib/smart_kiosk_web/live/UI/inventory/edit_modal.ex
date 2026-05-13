defmodule SmartKioskWeb.UI.Inventory.InventoryLive.EditModal do
  use SmartKioskWeb, :live_component

  alias SmartKioskCore.Catalogue
  alias SmartKioskCore.Schemas.Product

  def update(%{product: product, shop: shop}, socket) do
    changeset = Product.changeset(product, %{})
    form = to_form(changeset, as: "product", action: :new)
    categories = Catalogue.list_categories()
    category_options = Enum.map(categories, &{&1.name, &1.id})

    {:ok,
     socket
     |> assign(:product, product)
     |> assign(:shop, shop)
     |> assign(:form, form)
     |> assign(:category_options, category_options)}
  end

  def handle_event("validate", %{"product" => product_params}, socket) do
    changeset =
      socket.assigns.product
      |> Product.changeset(product_params)
      |> Map.put(:action, :validate)

    form = to_form(changeset, as: "product", action: :validate)
    {:noreply, assign(socket, :form, form)}
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
         |> push_patch(to: ~p"/inventory")}

      {:error, %Ecto.Changeset{} = changeset} ->
        form = to_form(changeset, as: "product", action: :update)

        {:noreply, assign(socket, :form, form)}
    end
  end

  def handle_event("close", _params, socket) do
    {:noreply,
     socket
     |> assign(:edit_product, nil)
     |> push_patch(to: ~p"/inventory")}
  end
end
