defmodule SmartKioskWeb.UI.Inventory.InventoryLive.New do
  alias SmartKioskCore.Catalogue
  alias SmartKioskCore.Schemas.Product
  alias SmartKioskWeb.LocalUploads
  use SmartKioskWeb, :live_view

  def mount(_params, _session, socket) do
    shop = socket.assigns.current_shop
    changeset = Product.changeset(%Product{shop_id: shop.id}, %{})
    form = to_form(changeset, as: "product")
    categories = Catalogue.list_categories()

    {:ok,
     socket
     |> assign(:page_title, "New Product")
     |> assign(:shop, shop)
     |> assign(:form, form)
     |> assign(:categories, categories)
     |> allow_upload(:images,
       accept: ~w(.jpg .jpeg .png .webp),
       max_entries: 5,
       max_file_size: 5_000_000
     )}
  end

  def handle_event("validate", %{"product" => product_params}, socket) do
    shop = socket.assigns.shop

    changeset =
      %Product{shop_id: shop.id}
      |> Product.changeset(product_params)
      |> Map.put(:action, :validate)

    form = to_form(changeset, as: "product")
    {:noreply, assign(socket, form: form)}
  end

  def handle_event("save", %{"product" => product_params}, socket) do
    shop = socket.assigns.shop

    case Catalogue.create_product(shop, product_params) do
      {:ok, product} ->
        socket
        |> LocalUploads.consume(:images, "products")
        |> Enum.with_index()
        |> Enum.each(fn {url, position} ->
          Catalogue.add_product_image(product, %{
            url: url,
            alt_text: product.name,
            position: position
          })
        end)

        {:noreply,
         socket
         |> put_flash(:info, "Product created successfully!")
         |> push_navigate(to: ~p"/inventory")}

      {:error, changeset} ->
        # Check for base errors (like plan limits) and show them via flash
        socket =
          case Keyword.get(changeset.errors, :base) do
            {msg, opts} ->
              error_message = SmartKioskWeb.CoreComponents.translate_error({msg, opts})
              put_flash(socket, :error, error_message)

            _ ->
              socket
          end

        form = to_form(changeset, as: "product", action: :insert)
        {:noreply, assign(socket, form: form)}
    end
  end

  def handle_event("cancel", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/inventory")}
  end
end
