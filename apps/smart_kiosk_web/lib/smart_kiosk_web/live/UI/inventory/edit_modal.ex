defmodule SmartKioskWeb.UI.Inventory.InventoryLive.EditModal do
  use SmartKioskWeb, :live_component

  alias SmartKioskCore.Catalogue
  alias SmartKioskCore.Schemas.Product
  alias SmartKioskWeb.LocalUploads

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
     |> assign(:category_options, category_options)
     |> maybe_allow_image_upload()}
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
      {:ok, updated_product} ->
        existing_count = length(product.images || [])

        socket
        |> LocalUploads.consume(:images, "products")
        |> Enum.with_index(existing_count)
        |> Enum.each(fn {url, position} ->
          Catalogue.add_product_image(updated_product, %{
            url: url,
            alt_text: updated_product.name,
            position: position
          })
        end)

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

  defp maybe_allow_image_upload(socket) do
    if Map.has_key?(socket.assigns[:uploads] || %{}, :images) do
      socket
    else
      allow_upload(socket, :images,
        accept: ~w(.jpg .jpeg .png .webp),
        max_entries: 5,
        max_file_size: 5_000_000
      )
    end
  end
end
