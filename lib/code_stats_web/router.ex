defmodule CodeStatsWeb.Router do
  use CodeStatsWeb, :router

  pipeline :browser_common do
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug CodeStatsWeb.RememberMePlug
    plug CodeStatsWeb.SetSessionUserPlug
  end

  pipeline :browser_html do
    plug :accepts, ["html"]
  end

  pipeline :browser_csv do
    plug :accepts, ["csv"]
  end

  pipeline :browser_auth do
    plug CodeStatsWeb.AuthRequiredPlug
  end

  pipeline :browser_unauth do
    plug CodeStatsWeb.AuthNotAllowedPlug
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :api_auth do
    plug CodeStatsWeb.APIAuthRequiredPlug
  end

  scope "/", CodeStatsWeb do
    pipe_through :browser_html
    pipe_through :browser_common

    get "/", PageController, :index

    get "/api-docs", PageController, :api_docs
    get "/tos", PageController, :terms
    get "/plugins", PageController, :plugins
    get "/changes", PageController, :changes

    get "/aliases", AliasController, :list

    get "/battle", BattleController, :battle

    scope "/" do
      pipe_through :browser_unauth

      get "/login", AuthController, :render_login
      post "/login", AuthController, :login
      get "/signup", AuthController, :render_signup
      post "/signup", AuthController, :signup
      get "/forgot-password", AuthController, :render_forgot
      post "/forgot-password", AuthController, :forgot
      get "/reset-password/:token", AuthController, :render_reset
      put "/reset-password/:token", AuthController, :reset
    end

    get "/logout", AuthController, :logout

    get "/users/:username", ProfileController, :profile

    scope "/my" do
      pipe_through :browser_auth

      get "/profile", ProfileController, :my_profile

      get "/preferences", PreferencesController, :edit
      put "/preferences", PreferencesController, :do_edit

      post "/password", PreferencesController, :change_password
      post "/sound_of_inevitability", PreferencesController, :delete

      get "/machines", MachineController, :list
      post "/machines", MachineController, :add
      get "/machines/:id", MachineController, :view_single
      put "/machines/:id", MachineController, :edit
      delete "/machines/:id", MachineController, :delete
      post "/machines/:id/activate", MachineController, :activate
      post "/machines/:id/deactivate", MachineController, :deactivate
      post "/machines/:id/key", MachineController, :regen_machine_key
    end
  end

  scope "/", CodeStatsWeb do
    pipe_through :browser_csv
    pipe_through :browser_common
    pipe_through :browser_auth

    get "/my/pulses", PulseController, :list
  end

  scope "/api", CodeStatsWeb do
    pipe_through :api

    get "/users/:username", ProfileController, :profile_api

    scope "/my" do
      pipe_through :api_auth
      post "/pulses", PulseController, :add
    end
  end
end
