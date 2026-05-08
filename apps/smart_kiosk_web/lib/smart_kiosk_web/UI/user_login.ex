defmodule SmartKioskWeb.UserLoginLive do
  @moduledoc """
  Modern styled login page with daisyUI/Tailwind.
  """
  use SmartKioskWeb, :live_view

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="min-h-[80vh] flex items-center justify-center px-4 py-12">
        <div class="card bg-base-100 shadow-xl w-full max-w-md">
          <div class="card-body space-y-6">
            <%!-- Logo & Header --%>
            <div class="text-center space-y-2">
              <div class="avatar placeholder mx-auto">
                <div class="bg-primary text-primary-content w-16 rounded-xl">
                  <span class="text-2xl font-bold">SK</span>
                </div>
              </div>
              <h2 class="card-title justify-center text-2xl font-bold">Welcome back</h2>
              <p class="text-base-content/70">Sign in to your SmartKiosk account</p>
            </div>

            <%!-- Login Form --%>
            <form class="space-y-4" action={~p"/login"} method="POST" id="login-form">
              <input type="hidden" name="_csrf_token" value={Phoenix.Controller.get_csrf_token()} />

              <%!-- Email Input --%>
              <div class="form-control">
                <label class="label" for="email">
                  <span class="label-text font-medium">Email</span>
                </label>
                <label class="input input-bordered flex items-center gap-2 has-[:focus]:input-primary">
                  <.icon name="hero-envelope" class="w-4 h-4 text-base-content/50" />
                  <input
                    id="email"
                    name="email"
                    type="email"
                    placeholder="you@example.com"
                    autocomplete="email"
                    required
                    class="grow bg-transparent border-none focus:outline-none"
                  />
                </label>
              </div>

              <%!-- Password Input --%>
              <div class="form-control">
                <label class="label" for="password">
                  <span class="label-text font-medium">Password</span>
                </label>
                <label class="input input-bordered flex items-center gap-2 has-[:focus]:input-primary">
                  <.icon name="hero-lock-closed" class="w-4 h-4 text-base-content/50" />
                  <input
                    id="password"
                    name="password"
                    type="password"
                    placeholder="••••••••"
                    autocomplete="current-password"
                    required
                    class="grow bg-transparent border-none focus:outline-none"
                  />
                </label>
              </div>

              <%!-- Remember Me & Forgot Password --%>
              <div class="flex items-center justify-between text-sm">
                <label class="label cursor-pointer gap-2">
                  <input type="checkbox" name="remember_me" class="checkbox checkbox-primary checkbox-sm" />
                  <span class="label-text">Remember me</span>
                </label>
                <a href={~p"/reset-password"} class="link link-primary text-sm">
                  Forgot password?
                </a>
              </div>

              <%!-- Submit Button --%>
              <button type="submit" class="btn btn-primary w-full">
                <.icon name="hero-arrow-right-end-on-rectangle" class="w-5 h-5" />
                Sign in
              </button>
            </form>

            <%!-- Divider --%>
            <div class="divider text-sm">or</div>

            <%!-- Sign Up Link --%>
            <div class="text-center text-sm">
              <span class="text-base-content/70">Don't have an account?</span>
              <a href={~p"/register"} class="link link-primary font-medium ml-1">
                Create one now
              </a>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
