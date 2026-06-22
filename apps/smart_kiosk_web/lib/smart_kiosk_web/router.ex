defmodule SmartKioskWeb.Router do
  use SmartKioskWeb, :router

  import SmartKioskWeb.UserAuth

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(SmartKioskWeb.Plugs.EnsureSessionId)
    plug(:fetch_live_flash)
    plug(:put_root_layout, html: {SmartKioskWeb.Layouts, :root})
    plug(:put_layout, html: false)
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
    plug(:fetch_current_user)
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  pipeline :require_auth do
    plug(:require_authenticated_user)
  end

  pipeline :require_admin do
    plug(:require_platform_admin)
  end

  # ── Public routes ─────────────────────────────────────────────────────────────
  scope "/", SmartKioskWeb do
    pipe_through(:browser)

    live_session :public,
      on_mount: [
        {SmartKioskWeb.UserAuth, :current_user},
        {SmartKioskWeb.UserAuth, :load_cart_count}
      ] do
      live("/", HomeLive, :index)
      live("/cart", CartLive, :index)

      # Shop public storefront (accessed by consumers)
      live("/shop/:slug", StorefrontLive.Index, :index)
      live("/shop/:slug/product/:id", StorefrontLive.Show, :show)
      live("/shop/:slug/rider/register", RiderRegistrationLive, :new)
      live("/shop/:slug/rider/thanks", RiderApplicationThanksLive, :show)

      # Job board (public access for job seekers)
      live("/jobs", Careers.JobBoardLive, :index)
      live("/jobs/new", Careers.JobFormLive, :new)
      live("/jobs/:id/edit", Careers.JobFormLive, :edit)
      live("/jobs/:id", Careers.JobDetailLive, :show)
    end
  end

  # ── Auth routes (phx.gen.auth) ────────────────────────────────────────────────
  scope "/", SmartKioskWeb do
    pipe_through([:browser, :redirect_if_user_is_authenticated])

    live_session :redirect_if_authenticated,
      on_mount: [
        {SmartKioskWeb.UserAuth, :redirect_if_user_is_authenticated},
        {SmartKioskWeb.UserAuth, :load_cart_count}
      ] do
      live("/register", UserRegistrationLive, :new)
      live("/login", UserLoginLive, :new)
      live("/job-invite/:token", JobInviteLive, :edit)
      live("/reset-password", UserForgotPasswordLive, :new)
      live("/reset-password/:token", UserResetPasswordLive, :edit)
    end

    post("/login", UserSessionController, :create)
  end

  # ── Dashboard (Unified) ──────────────────────────────────────────────────────
  scope "/", SmartKioskWeb do
    pipe_through([:browser, :require_auth])

    live_session :require_authenticated,
      on_mount: [
        {SmartKioskWeb.UserAuth, :ensure_authenticated},
        SmartKioskWeb.ShopAuth,
        {SmartKioskWeb.UserAuth, :load_cart_count},
        {SmartKioskWeb.UserAuth, :restrict_cashier}
      ] do
      live("/users/settings", UserSettingsLive, :edit)
      live("/users/settings/confirm-email/:token", UserSettingsLive, :confirm_email)
      live("/dashboard", UI.DashboardLive, :index)
      live("/create-shop", UI.CreateShopLive, :new)
      live("/careers", Careers.CareersLive, :index)
      live("/careers/new", Careers.CareersLive, :new)
    end

    delete("/logout", UserSessionController, :delete)
  end

  # ── Merchant dashboard (Strict) ──────────────────────────────────────────────
  scope "/", SmartKioskWeb.UI do
    pipe_through([:browser, :require_auth])

    live_session :dashboard_merchant,
      on_mount: [
        {SmartKioskWeb.UserAuth, :ensure_authenticated},
        SmartKioskWeb.ShopAuth,
        {SmartKioskWeb.ShopAuth, :require_shop},
        {SmartKioskWeb.UserAuth, :load_cart_count},
        {SmartKioskWeb.UserAuth, :restrict_cashier}
      ] do
      live("/inventory", Inventory.InventoryLive.Index, :index)
      live("/inventory/new", Inventory.InventoryLive.New, :new)
      live("/inventory/:id/edit", Inventory.InventoryLive.EditModalLive, :edit)
      live("/orders", OrdersLive.Index, :index)
      live("/orders/:id", OrdersLive.Show, :show)

      live("/delivery-zones", DeliveryZoneLive.Index, :index)
      live("/delivery-zones/new", DeliveryZoneLive.Index, :new)
      live("/delivery-zones/:id/edit", DeliveryZoneLive.Index, :edit)
      live("/manage-staff", ManageStaffLive, :index)
      live("/settings", SettingsLive.Index, :index)
      live("/customers", CustomersLive.Index, :index)
      live("/analytics", AnalyticsLive.Index, :index)
      live("/reports", ReportsLive.Index, :index)
      live("/reports/:id", ReportsLive.Show, :show)
      live("/campaigns", CampaignsLive.Index, :index)
    end
  end

  # ── Cashier POS (restricted access) ──────────────────────────────────────────────
  scope "/", SmartKioskWeb.UI do
    pipe_through([:browser, :require_auth])

    live_session :cashier_only,
      on_mount: [
        {SmartKioskWeb.UserAuth, :ensure_authenticated},
        SmartKioskWeb.ShopAuth,
        {SmartKioskWeb.ShopAuth, :require_shop},
        {SmartKioskWeb.UserAuth, :require_cashier_only},
        {SmartKioskWeb.UserAuth, :load_cart_count}
      ] do
      live("/pos", POSLive.Index, :index)
    end
  end

  # ── Platform admin ────────────────────────────────────────────────────────────
  scope "/admin", SmartKioskWeb do
    pipe_through([:browser, :require_auth, :require_admin])

    live_session :admin,
      on_mount: [{SmartKioskWeb.UserAuth, :ensure_authenticated}] do
      live("/", AdminLive, :index)
      live("/shops", AdminShopsLive, :index)
      live("/shops/:id", AdminShopDetailLive, :show)
      live("/users", AdminUsersLive, :index)
    end
  end

  # ── M-PESA callback (no CSRF — external webhook) ─────────────────────────────
  scope "/api/mpesa", SmartKioskWeb.Api do
    pipe_through(:api)
    post("/callback", MpesaCallbackController, :create)
    post("/validation", MpesaCallbackController, :validation)
  end

  # ── Rider stub (Phase 1 — real app deferred) ─────────────────────────────────
  scope "/api/rider", SmartKioskWeb.Api do
    pipe_through(:api)
    post("/location", RiderStubController, :update_location)
    get("/tasks", RiderStubController, :list_tasks)
    post("/tasks/:id/status", RiderStubController, :update_task_status)
  end

  # ── Search metrics (public monitoring endpoint) ────────────────────────────────
  scope "/api/search", SmartKioskWeb.Api do
    pipe_through(:api)
    get("/metrics", SearchMetricsController, :index)
  end

  # ── Dev tooling ───────────────────────────────────────────────────────────────
  if Application.compile_env(:smart_kiosk_web, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through(:browser)
      live_dashboard("/dashboard", metrics: SmartKioskWeb.Telemetry)
      forward("/mailbox", Plug.Swoosh.MailboxPreview)
    end
  end
end
