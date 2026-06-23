defmodule SmartKioskWeb.UI.CreateShopLive do
  use SmartKioskWeb, :live_view

  alias SmartKioskCore.{Shops, Plans}

  def mount(_params, _session, socket) do
    # Shop plans and categories
    plans = Plans.select_options()

    categories = [
      General: :general_shop,
      Electronics: :electronics,
      Groceries: :groceries,
      Pharmacy: :pharmacy,
      Fashion: :fashion,
      Bakery: :bakery
    ]

    # Pre-fill user details if available
    current_user = socket.assigns.current_user

    form =
      to_form(
        %{
          "name" => "",
          "phone" => (current_user && current_user.phone) || "",
          "email" => (current_user && current_user.email) || "",
          "address" => "",
          "city" => "",
          "country" => "KE",
          "plan" => :basic,
          "category" => :general_shop,
          "description" => "",
          "lat" => "",
          "lng" => ""
        },
        as: :shop
      )

    {:ok,
     assign(socket,
       form: form,
       plans: plans,
       categories: categories,
       page_title: "Create Your Shop"
     )}
  end

  def handle_event("save", %{"shop" => shop_params}, socket) do
    user = socket.assigns.current_user
    shop_params = Map.put(shop_params, "status", "active")

    case Shops.create_shop_for_user(user, shop_params) do
      {:ok, _shop, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Shop created successfully!")
         |> push_navigate(to: ~p"/dashboard")}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(form: to_form(changeset, as: :shop, action: :insert))
         |> put_flash(:error, "Could not create shop. Check the highlighted fields.")}
    end
  end
end
