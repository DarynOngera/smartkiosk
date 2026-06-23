defmodule SmartKioskWeb.JobInviteLive do
  use SmartKioskWeb, :live_view

  alias SmartKioskCore.Accounts

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    case Accounts.get_user_by_job_invite_token(token) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Account setup link is invalid or it has expired.")
         |> push_navigate(to: ~p"/login")}

      user ->
        changeset = Accounts.change_user_password(user)

        {:ok,
         socket
         |> assign(:page_title, "Create Account")
         |> assign(:user, user)
         |> assign(:token, token)
         |> assign(:form, to_form(changeset, as: :user))}
    end
  end

  @impl true
  def handle_event("validate", %{"user" => params}, socket) do
    changeset =
      socket.assigns.user
      |> Accounts.change_user_password(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset, as: :user))}
  end

  def handle_event("save", %{"user" => params}, socket) do
    case Accounts.accept_job_invite(socket.assigns.user, params) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Account created. You can now sign in.")
         |> push_navigate(to: ~p"/login")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, as: :user, action: :insert))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_path="/job-invite">
      <div class="min-h-screen bg-[#0B0F1A] flex items-center justify-center px-6 py-12">
        <div class="w-full max-w-[440px]">
          <div class="mb-8 text-center">
            <div class="mx-auto mb-4 flex h-12 w-12 items-center justify-center rounded-xl bg-violet-500 shadow-lg shadow-violet-500/20">
              <.icon name="hero-briefcase" class="h-6 w-6 text-white" />
            </div>
            <h1 class="text-2xl font-bold tracking-tight text-white">Create your account</h1>
            <p class="mt-2 text-sm text-slate-400">
              Set a password for <span class="text-slate-200">{@user.email}</span>
            </p>
          </div>

          <div class="rounded-3xl border border-white/10 bg-white/5 p-8 shadow-2xl backdrop-blur-xl">
            <.form
              for={@form}
              id="job-invite-form"
              phx-submit="save"
              phx-change="validate"
              class="space-y-5"
            >
              <.input
                field={@form[:password]}
                type="password"
                label="Password"
                required
                minlength="12"
                placeholder="At least 12 characters"
              />

              <.input
                field={@form[:password_confirmation]}
                type="password"
                label="Confirm password"
                required
                placeholder="Repeat your password"
              />

              <button
                type="submit"
                phx-disable-with="Creating account..."
                class="flex w-full items-center justify-center gap-2 rounded-2xl bg-violet-500 px-4 py-4 font-bold text-white shadow-lg shadow-violet-500/20 transition-all hover:bg-violet-400 active:scale-[0.98]"
              >
                <.icon name="hero-check" class="h-4 w-4" /> Create account
              </button>
            </.form>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
