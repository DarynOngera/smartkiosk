defmodule SmartKioskWeb.UserResetPasswordLive do
  @moduledoc """
  Reset-password page.

  Validates the one-time token from the email link, then lets the user
  choose a new password. On success redirects to /login.

  Route: GET /reset-password/:token  (live_session :redirect_if_authenticated)

  Token lifecycle:
    - Built by Accounts.deliver_user_reset_password_instructions/2
    - Stored hashed in users_tokens (context: "reset_password")
    - Valid for 10 minutes (see UserToken.verify_reset_password_token_query/1)
    - Consumed (deleted) on successful password change
  """
  use SmartKioskWeb, :live_view
  alias SmartKioskCore.Accounts

  # mount - validate token immediately; redirect if invalid

  def mount(%{"token" => token}, _session, socket) do
    case Accounts.get_user_by_reset_password_token(token) do
      nil ->
        # invalid or expired token
        socket =
          socket
          |> put_flash(:error, "Reset password link is invalid or it has expired.")
          |> redirect(to: ~p"/reset-password")

        {:ok, socket}

      user ->
        changeset = Accounts.change_user_password(user)

        {:ok,
         socket
         |> assign(:page_title, "Reset Password")
         |> assign(:user, user)
         |> assign(:token, token)
         |> assign(:trigger_submit, false)
         |> assign(:form, to_form(changeset, as: :user))}
    end
  end

  # events

  def handle_event("validate", %{"user" => params}, socket) do
    changeset =
      Accounts.change_user_password(socket.assigns.user, params)

    {:noreply, assign(socket, :form, to_form(changeset, as: :user, action: :validate))}
  end

  def handle_event("save", %{"user" => params}, socket) do
    case Accounts.reset_user_password(socket.assigns.user, params) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(
           :info,
           "Password reset successfully. You can now sign in with your new password."
         )
         |> push_navigate(to: ~p"/login")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, as: :user, action: :insert))}
    end
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
              <.icon name="hero-key-solid" class="w-6 h-6 text-white" />
            </div>
            <h1 class="text-white text-2xl font-bold tracking-tight">Set a new password</h1>
            <p class="text-slate-500 mt-2 text-sm text-center">
              Must be at least 12 characters
            </p>
          </div>

          <div class="bg-white/5 backdrop-blur-xl border border-white/10 rounded-3xl p-8 shadow-2xl">
            <.form
              for={@form}
              id="reset-password-form"
              phx-submit="save"
              phx-change="validate"
              class="space-y-5"
            >
              <%!-- New password --%>
              <div class="space-y-2">
                <label class="text-[11px] uppercase tracking-[0.2em] text-slate-400 font-bold ml-1">
                  New Password
                </label>
                <div class="relative group">
                  <div class="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none text-slate-500 group-focus-within:text-violet-400 transition-colors">
                    <.icon name="hero-lock-closed" class="w-5 h-5" />
                  </div>
                  <input
                    type="password"
                    id="user_password"
                    name="user[password]"
                    value={@form[:password].value}
                    required
                    minlength="12"
                    placeholder="At least 12 characters"
                    class={[
                      "w-full bg-slate-900/50 border rounded-2xl py-4 pl-12 pr-4 text-white placeholder:text-slate-600",
                      "focus:outline-none focus:ring-2 focus:ring-violet-500/50 transition-all",
                      if(@form[:password].errors != [],
                        do: "border-red-500/50 focus:border-red-500",
                        else: "border-white/5 focus:border-violet-500"
                      )
                    ]}
                  />
                </div>
                <%= for {msg, _} <- @form[:password].errors do %>
                  <p class="flex items-center gap-1.5 text-sm text-red-400 ml-1">
                    <.icon name="hero-exclamation-circle" class="w-4 h-4 flex-shrink-0" />
                    <%= translate_error({msg, []}) %>
                  </p>
                <% end %>
              </div>

              <%!-- Confirm password --%>
              <div class="space-y-2">
                <label class="text-[11px] uppercase tracking-[0.2em] text-slate-400 font-bold ml-1">
                  Confirm New Password
                </label>
                <div class="relative group">
                  <div class="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none text-slate-500 group-focus-within:text-violet-400 transition-colors">
                    <.icon name="hero-lock-closed" class="w-5 h-5" />
                  </div>
                  <input
                    type="password"
                    id="user_password_confirmation"
                    name="user[password_confirmation]"
                    value={@form[:password_confirmation].value}
                    required
                    placeholder="Repeat your new password"
                    class={[
                      "w-full bg-slate-900/50 border rounded-2xl py-4 pl-12 pr-4 text-white placeholder:text-slate-600",
                      "focus:outline-none focus:ring-2 focus:ring-violet-500/50 transition-all",
                      if(@form[:password_confirmation].errors != [],
                        do: "border-red-500/50 focus:border-red-500",
                        else: "border-white/5 focus:border-violet-500"
                      )
                    ]}
                  />
                </div>
                <%= for {msg, _} <- @form[:password_confirmation].errors do %>
                  <p class="flex items-center gap-1.5 text-sm text-red-400 ml-1">
                    <.icon name="hero-exclamation-circle" class="w-4 h-4 flex-shrink-0" />
                    <%= translate_error({msg, []}) %>
                  </p>
                <% end %>
              </div>

              <%!-- Password strength hint --%>
              <div class="flex items-start gap-2 px-1">
                <.icon
                  name="hero-information-circle"
                  class="w-4 h-4 text-slate-500 flex-shrink-0 mt-0.5"
                />
                <p class="text-xs text-slate-500 leading-relaxed">
                  Use a mix of uppercase, lowercase, numbers, and symbols for a strong password.
                </p>
              </div>

              <button
                type="submit"
                phx-disable-with="Saving…"
                class="w-full bg-violet-500 hover:bg-violet-400 text-white font-bold py-4 rounded-2xl shadow-lg shadow-violet-500/20 transition-all active:scale-[0.98] flex items-center justify-center gap-2"
              >
                <.icon name="hero-check" class="w-4 h-4" /> Reset Password
              </button>
            </.form>
          </div>

          <%!-- Footer links --%>
          <div class="mt-6 flex justify-center gap-6 text-sm text-slate-500">
            <.link navigate={~p"/login"} class="hover:text-white transition-colors">
              Sign in
            </.link>
            <.link navigate={~p"/reset-password"} class="hover:text-white transition-colors">
              Request new link
            </.link>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
