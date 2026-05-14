defmodule SmartKioskWeb.Router do
  use SmartKioskWeb, :router

  import SmartKioskWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {SmartKioskWeb.Layouts, :root}
    plug :put_layout, html: false
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :require_auth do
    plug :require_authenticated_user
  end

  pipeline :require_admin do
    plug :require_platform_admin
  end

  # ── Public routes ─────────────────────────────────────────────────────────────
  scope "/", SmartKioskWeb do
    pipe_through :browser

    live_session :public,
      on_mount: [{SmartKioskWeb.UserAuth, :current_user}] do
      live "/", HomeLive, :index
      live "/cart", CartLive, :index

      # Shop public storefront (accessed by consumers)
      live "/shop/:slug", StorefrontLive.Index, :index
      live "/shop/:slug/product/:id", StorefrontLive.Show, :show
    end
  end

  # ── Auth routes (phx.gen.auth) ────────────────────────────────────────────────
  scope "/", SmartKioskWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    live_session :redirect_if_authenticated,
      on_mount: [{SmartKioskWeb.UserAuth, :redirect_if_user_is_authenticated}] do
      live "/register", UserRegistrationLive, :new
      live "/login", UserLoginLive, :new
      live "/reset-password", UserForgotPasswordLive, :new
      live "/reset-password/:token", UserResetPasswordLive, :edit
    end

    post "/login", UserSessionController, :create
  end

  # ── Dashboard (Unified) ──────────────────────────────────────────────────────
  scope "/", SmartKioskWeb do
    pipe_through [:browser, :require_auth]

    live_session :require_authenticated,
      on_mount: [{SmartKioskWeb.UserAuth, :ensure_authenticated}, SmartKioskWeb.ShopAuth] do
      live "/users/settings", UserSettingsLive, :edit
      live "/users/settings/confirm-email/:token", UserSettingsLive, :confirm_email
      live "/dashboard", UI.DashboardLive, :index
      live "/create-shop", UI.CreateShopLive, :new
    end

    delete "/logout", UserSessionController, :delete
  end

  # ── Merchant dashboard (Strict) ──────────────────────────────────────────────
  scope "/", SmartKioskWeb.UI do
    pipe_through [:browser, :require_auth]

    live_session :dashboard_merchant,
      on_mount: [
        {SmartKioskWeb.UserAuth, :ensure_authenticated},
        SmartKioskWeb.ShopAuth,
        {SmartKioskWeb.ShopAuth, :require_shop}
      ] do
      live "/inventory", Inventory.InventoryLive.Index, :index
      live "/inventory/new", Inventory.InventoryLive.New, :new
      live "/inventory/:id/edit", Inventory.InventoryLive.EditModalLive, :edit
      live "/orders", OrdersLive.Index, :index
      live "/orders/:id", OrdersLive.Show, :show
      live "/pos", POSLive.Index, :index
      live "/settings", SettingsLive.Index, :index
      live "/customers", CustomersLive.Index, :index
      live "/analytics", AnalyticsLive.Index, :index
      live "/campaigns", CampaignsLive.Index, :index
    end
  end

  # ── Platform admin ────────────────────────────────────────────────────────────
  scope "/admin", SmartKioskWeb do
    pipe_through [:browser, :require_auth, :require_admin]

    live_session :admin,
      on_mount: [{SmartKioskWeb.UserAuth, :ensure_authenticated}] do
      live "/", AdminLive, :index
    end
  end

  # ── M-PESA callback (no CSRF — external webhook) ─────────────────────────────
  scope "/api/mpesa", SmartKioskWeb.Api do
    pipe_through :api
    post "/callback", MpesaCallbackController, :create
    post "/validation", MpesaCallbackController, :validation
  end

  # ── Rider stub (Phase 1 — real app deferred) ─────────────────────────────────
  scope "/api/rider", SmartKioskWeb.Api do
    pipe_through :api
    post "/location", RiderStubController, :update_location
    get "/tasks", RiderStubController, :list_tasks
    post "/tasks/:id/status", RiderStubController, :update_task_status
  end

  # ── Dev tooling ───────────────────────────────────────────────────────────────
  if Application.compile_env(:smart_kiosk_web, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser
      live_dashboard "/dashboard", metrics: SmartKioskWeb.Telemetry
    end
  end
end
