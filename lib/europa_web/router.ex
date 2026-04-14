defmodule EuropaWeb.Router do
  # coveralls-ignore-start
  use EuropaWeb, :router

  alias EuropaWeb.UnauthorizedOnly
  alias EuropaWeb.AuthorizedOnly
  alias EuropaWeb.Auth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {EuropaWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug Auth
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", EuropaWeb do
    pipe_through [:browser]
    get "/", PageController, :home
  end

  scope "/", EuropaWeb do
    pipe_through [:browser, AuthorizedOnly]

    get "/users/logout", UserController, :logout
  end

  scope "/games", EuropaWeb do
    pipe_through [:browser, AuthorizedOnly]

    get "/", GameController, :index
    get "/new", GameController, :create
    get "/leaderboard", GameController, :leaderboard

    live "/:uuid", GameLive

    get "/:uuid/game-over", GameController, :game_over
  end

  scope "/users", EuropaWeb do
    pipe_through [:browser, UnauthorizedOnly]

    get "/login", UserController, :login
    post "/login", UserController, :do_login

    get "/register", UserController, :new
    post "/register", UserController, :create

    post "/", UserController, :create
  end

  # coveralls-ignore-stop
end
