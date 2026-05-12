defmodule SmartKioskWeb.UserForgotPasswordLive do
  @moduledoc """
  Forgot-password page.

  Accepts an email address and, if a user with that address exists, sends a
  password-reset link via SmartKioskCore.UserNotifier.

  Deliberately vague success message to prevent user-enumeration attacks —
  we never confirm whether the email exists.

  Route: GET /reset-password  (live_session :redirect_if_authenticated)
  """
  use SmartKioskWeb, :live_view
  alias SmartKioskCore.Accounts

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Forgot Password · Smart Kiosk")
     |> assign(:form, to_form(%{"email" => ""}, as: :user))
     |> assign(:email_sent, false)}
  end

  @spec handle_event(<<_::152>>, map(), map()) :: {:noreply, map()}
  def handle_event("send_reset_password", %{"user" => %{"email" => email}}, socket) do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_user_reset_password_instructions(user,&url(~p"/reset-password/#{&1}"))
    end

    # Always show the same success message regardless of whether the email
    # exists, to prevent user-enumeration.
    {:noreply, socket
    |> assign(:email_sent, true)
    |> assign(:form, to_form(%{"email" => ""}, as: :user))}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_path="/reset-password">
      <div class="min-h-screen bg-[#0B0F1A] flex items-center justify-center px-6 py-12">
        <%!-- Ambient glow --%>
        <div class="absolute top-1/3 left-1/2 -translate-x-1/2 w-[500px] h-[500px] bg-violet-500/10 rounded-full blur-[140px] pointer-events-none">
        </div>

        <div class="w-full max-w-[420px] z-10">
          <%!-- Logo --%>
          <div class="flex flex-col items-center mb-8">
            <div class="w-12 h-12 bg-gradient-to-tr from-violet-500 to-indigo-400 rounded-xl mb-4 flex items-center justify-center shadow-lg shadow-violet-500/20">
              <.icon name="hero-lock-closed-solid" class="w-6 h-6 text-white" />
            </div>
            <h1 class="text-white text-2xl font-bold tracking-tight">Forgot your password?</h1>
            <p class="text-slate-500 mt-2 text-sm text-center">
              Enter your email and we'll send you a reset link
            </p>
          </div>

          <%= if @email_sent do %>
            <%!-- Success state --%>
            <div class="bg-white/5 backdrop-blur-xl border border-emerald-500/30 rounded-3xl p-8 shadow-2xl text-center">
              <div class="w-14 h-14 bg-emerald-500/20 rounded-full flex items-center justify-center mx-auto mb-4">
                <.icon name="hero-envelope-solid" class="w-7 h-7 text-emerald-400" />
              </div>
              <h2 class="text-white font-bold text-lg mb-2">Check your inbox</h2>
              <p class="text-slate-400 text-sm leading-relaxed">
                If an account exists for that email address, you'll receive a
                password reset link within a few minutes. Check your spam folder
                if it doesn't appear.
              </p>
              <div class="mt-6 space-y-3">
                <button
                  phx-click="send_email"
                  phx-value-user={Jason.encode!(%{"email" => ""})}
                  class="w-full py-3 bg-white/5 hover:bg-white/10 text-white text-sm font-medium rounded-xl transition-colors"
                  onclick="this.closest('form') && this.closest('form').reset()"
                >
                  Resend email
                </button>
                <.link
                  navigate={~p"/login"}
                  class="block text-center text-violet-400 hover:text-violet-300 text-sm font-medium transition-colors"
                >
                  Back to sign in
                </.link>
              </div>
            </div>
          <% else %>
            <%!-- Form state --%>
            <div class="bg-white/5 backdrop-blur-xl border border-white/10 rounded-3xl p-8 shadow-2xl">
              <.form for={@form} id="forgot-password-form" phx-submit="send_email" class="space-y-5">
                <div class="space-y-2">
                  <label class="text-[11px] uppercase tracking-[0.2em] text-slate-400 font-bold ml-1">
                    Email Address
                  </label>
                  <div class="relative group">
                    <div class="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none text-slate-500 group-focus-within:text-violet-400 transition-colors">
                      <.icon name="hero-envelope" class="w-5 h-5" />
                    </div>
                    <input
                      type="email"
                      id="user_email"
                      name="user[email]"
                      value={@form[:email].value}
                      required
                      placeholder="name@company.com"
                      class="w-full bg-slate-900/50 border border-white/5 rounded-2xl py-4 pl-12 pr-4 text-white placeholder:text-slate-600 focus:outline-none focus:ring-2 focus:ring-violet-500/50 focus:border-violet-500 transition-all"
                    />
                  </div>
                </div>

                <button
                  type="submit"
                  phx-disable-with="Sending…"
                  class="w-full bg-violet-500 hover:bg-violet-400 text-white font-bold py-4 rounded-2xl shadow-lg shadow-violet-500/20 transition-all active:scale-[0.98] flex items-center justify-center gap-2"
                >
                  <.icon name="hero-paper-airplane" class="w-4 h-4" /> Send Reset Link
                </button>
              </.form>
            </div>
          <% end %>

          <%!-- Footer link --%>
          <p class="text-center mt-6 text-slate-500 text-sm">
            Remembered it?
            <.link
              navigate={~p"/login"}
              class="text-white font-semibold hover:text-violet-400 transition-colors ml-1"
            >
              Sign in
            </.link>
          </p>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
