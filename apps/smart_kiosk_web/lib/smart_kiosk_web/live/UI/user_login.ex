defmodule SmartKioskWeb.UserLoginLive do
  @moduledoc """
  A high-end, premium minimalist login interface.
  """
  use SmartKioskWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Sign In")}
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex flex-col lg:flex-row bg-[#0B0F1A]">
      <%!-- Left Side: Marketing --%>
      <div class="hidden lg:flex lg:w-1/2 bg-[#0B0F1A] relative overflow-hidden items-center justify-center p-12">
        <%!-- Background Glows --%>
        <div class="absolute top-1/4 left-1/4 w-[500px] h-[500px] bg-violet-500/20 rounded-full blur-[150px] pointer-events-none">
        </div>
        <div class="absolute bottom-1/4 right-1/4 w-[400px] h-[400px] bg-indigo-500/15 rounded-full blur-[120px] pointer-events-none">
        </div>

        <div class="relative z-10 max-w-md">
          <div class="flex items-center gap-3 mb-8">
            <div class="w-10 h-10 bg-gradient-to-tr from-violet-500 to-indigo-400 rounded-xl flex items-center justify-center">
              <.icon name="hero-shopping-bag-solid" class="w-6 h-6 text-white" />
            </div>
            <h2 class="text-2xl font-bold text-white">SmartKiosk</h2>
          </div>

          <h3 class="text-4xl font-bold text-white mb-6 leading-tight">
            The future of<br />local commerce
          </h3>

          <p class="text-slate-400 text-lg mb-8 leading-relaxed">
            Join thousands of shop owners and customers connecting through Kenya's most trusted marketplace platform.
          </p>

          <div class="space-y-4">
            <div class="flex items-center gap-4 p-4 bg-white/5 rounded-xl border border-white/10">
              <div class="w-10 h-10 bg-violet-500/20 rounded-lg flex items-center justify-center">
                <.icon name="hero-storefront" class="w-5 h-5 text-violet-400" />
              </div>
              <div>
                <p class="text-white font-semibold">For Shop Owners</p>
                <p class="text-slate-500 text-sm">Manage inventory, accept M-Pesa, track sales</p>
              </div>
            </div>

            <div class="flex items-center gap-4 p-4 bg-white/5 rounded-xl border border-white/10">
              <div class="w-10 h-10 bg-indigo-500/20 rounded-lg flex items-center justify-center">
                <.icon name="hero-user" class="w-5 h-5 text-indigo-400" />
              </div>
              <div>
                <p class="text-white font-semibold">For Customers</p>
                <p class="text-slate-500 text-sm">Browse local shops, order online, pay securely</p>
              </div>
            </div>
          </div>

          <div class="mt-8 flex items-center gap-6 text-sm text-slate-500">
            <span class="flex items-center gap-2">
              <.icon name="hero-shield-check" class="w-4 h-4" /> Bank-grade security
            </span>
            <span class="flex items-center gap-2">
              <.icon name="hero-bolt" class="w-4 h-4" /> Instant payments
            </span>
          </div>
        </div>
      </div>

      <%!-- Right Side: Login Form --%>
      <div class="flex-1 flex flex-col items-center justify-center bg-[#0B0F1A] px-6 py-12 lg:py-0 relative">
        <%!-- Mobile Glow --%>
        <div class="lg:hidden absolute top-0 left-1/2 -translate-x-1/2 w-[400px] h-[400px] bg-violet-500/15 rounded-full blur-[120px] pointer-events-none">
        </div>

        <div class="w-full max-w-[420px] z-10">
          <%!-- Logo Area (Mobile only) --%>
          <div class="flex lg:hidden flex-col items-center mb-8">
            <div class="w-12 h-12 bg-gradient-to-tr from-violet-500 to-indigo-400 rounded-xl mb-4 flex items-center justify-center">
              <.icon name="hero-shopping-bag-solid" class="w-7 h-7 text-white" />
            </div>
            <h1 class="text-white text-2xl font-bold tracking-tight">Welcome back</h1>
            <p class="text-slate-500 mt-2 text-sm">Sign in to your account</p>
          </div>

          <%!-- Desktop Title --%>
          <div class="hidden lg:block text-center mb-8">
            <h1 class="text-white text-2xl font-bold tracking-tight">Welcome back</h1>
            <p class="text-slate-500 mt-2 text-sm">Enter your details to access your dashboard</p>
          </div>

          <%!-- The Login Card --%>
          <div class="bg-white/5 backdrop-blur-xl border border-white/10 rounded-3xl p-8 shadow-2xl">
            <form action={~p"/login"} method="POST" id="login-form" class="space-y-6">
              <input type="hidden" name="_csrf_token" value={Phoenix.Controller.get_csrf_token()} />

              <%!-- Input Field --%>
              <div class="space-y-2">
                <label class="text-[11px] uppercase tracking-[0.2em] text-slate-400 font-bold ml-1">
                  Email Address
                </label>
                <div class="relative group">
                  <div class="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none text-slate-500 group-focus-within:text-violet-400 transition-colors">
                    <.icon name="hero-envelope" class="w-5 h-5" />
                  </div>
                  <input
                    id="email"
                    name="email"
                    type="email"
                    placeholder="name@company.com"
                    required
                    class="w-full bg-slate-900/50 border border-white/5 rounded-2xl py-4 pl-12 pr-4 text-white placeholder:text-slate-600 focus:outline-none focus:ring-2 focus:ring-violet-500/50 focus:border-violet-500 transition-all"
                  />
                </div>
              </div>

              <%!-- Password Field --%>
              <div class="space-y-2">
                <div class="flex justify-between items-end">
                  <label class="text-[11px] uppercase tracking-[0.2em] text-slate-400 font-bold ml-1">
                    Password
                  </label>
                  <a
                    href={~p"/reset-password"}
                    class="text-xs text-violet-400 hover:text-violet-300 font-medium"
                  >
                    Forgot?
                  </a>
                </div>
                <div class="relative group">
                  <div class="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none text-slate-500 group-focus-within:text-violet-400 transition-colors">
                    <.icon name="hero-lock-closed" class="w-5 h-5" />
                  </div>
                  <input
                    id="password"
                    name="password"
                    type="password"
                    placeholder="••••••••"
                    required
                    class="w-full bg-slate-900/50 border border-white/5 rounded-2xl py-4 pl-12 pr-4 text-white placeholder:text-slate-600 focus:outline-none focus:ring-2 focus:ring-violet-500/50 focus:border-violet-500 transition-all"
                  />
                </div>
              </div>

              <%!-- Actions --%>
              <div class="flex items-center space-x-2 ml-1">
                <input
                  type="checkbox"
                  name="remember_me"
                  class="w-4 h-4 rounded border-white/10 bg-white/5 text-violet-500 focus:ring-offset-slate-900 focus:ring-violet-500"
                />
                <span class="text-sm text-slate-400">Stay signed in</span>
              </div>

              <button
                type="submit"
                class="w-full bg-violet-500 hover:bg-violet-400 text-white font-bold py-4 rounded-2xl shadow-lg shadow-violet-500/20 transition-all active:scale-[0.98] flex items-center justify-center gap-2"
              >
                Sign in <.icon name="hero-arrow-right-solid" class="w-4 h-4" />
              </button>
            </form>
          </div>

          <%!-- Footer --%>
          <p class="text-center mt-8 text-slate-500 text-sm">
            Don't have an account?
            <a
              href={~p"/register"}
              class="text-white font-semibold hover:text-violet-400 transition-colors ml-1"
            >
              Create account
            </a>
          </p>

          <%!-- Trust Badge --%>
          <div class="mt-12 flex justify-center items-center gap-8 opacity-30 grayscale contrast-125">
            <div class="flex items-center gap-2">
              <.icon name="hero-shield-check" class="w-5 h-5 text-white" />
              <span class="text-[10px] font-bold uppercase tracking-widest text-white">
                Secure Cloud
              </span>
            </div>
            <div class="flex items-center gap-2">
              <.icon name="hero-banknotes" class="w-5 h-5 text-white" />
              <span class="text-[10px] font-bold uppercase tracking-widest text-white">
                M-Pesa Ready
              </span>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
