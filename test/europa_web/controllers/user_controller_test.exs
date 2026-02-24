defmodule EuropaWeb.UserControllerTest do
  use EuropaWeb.ConnCase, async: true

  setup do
    user = insert(:user)
    conn = auth_conn(user)

    {:ok, conn: conn, user: user}
  end

  describe "GET /users/login" do
    setup do
      path = ~p"/users/login"
      {:ok, path: path}
    end

    test "renders login template", %{conn_without_auth: conn, path: path} do
      conn = get(conn, path)
      assert render_template(conn) == "login.html"
    end

    test "redirects if authorized", %{conn: conn, path: path} do
      conn
      |> get(path)
      |> assert_redirect_if_authorized()
    end
  end

  describe "POST /users/login" do
    setup do
      path = ~p"/users/login"
      {:ok, path: path}
    end

    test "authenticates user and redirects to root page", %{conn_without_auth: conn, path: path, user: user} do
      params = %{"user" => %{"username" => user.username, "password" => "password"}}
      conn = post(conn, path, params)

      assert conn.assigns.current_user
      assert redirected_to(conn) == ~p"/games"
    end

    test "redirects to login page when params are invalid", %{conn_without_auth: conn, path: path, user: user} do
      params = %{"user" => %{"username" => user.username, "password" => "fake-password"}}
      conn = post(conn, path, params)

      assert redirected_to(conn) == ~p"/users/login"
    end

    test "redirects if authorized", %{conn: conn, path: path, user: user} do
      params = %{"user" => %{"username" => user.username, "password" => "password"}}

      conn
      |> post(path, params)
      |> assert_redirect_if_authorized()
    end
  end

  describe "GET /users/register" do
    setup do
      path = ~p"/users/register"
      {:ok, path: path}
    end

    test "renders register template", %{conn_without_auth: conn, path: path} do
      conn = get(conn, path)
      assert render_template(conn) == "register.html"
    end

    test "redirects if authorized", %{conn: conn, path: path} do
      conn
      |> get(path)
      |> assert_redirect_if_authorized()
    end
  end

  describe "POST /users/register" do
    setup do
      path = ~p"/users/register"
      {:ok, path: path}
    end

    test "authenticates user and redirects to root page", %{conn_without_auth: conn, path: path} do
      params = %{"user" => %{"username" => "username", "password" => "password", "password_confirmation" => "password"}}
      conn = post(conn, path, params)

      assert conn.assigns.current_user
      assert redirected_to(conn) == ~p"/games"
    end

    test "renders register page when params are invalid", %{conn_without_auth: conn, path: path} do
      params = %{"user" => %{"username" => "", "password" => "fake-password"}}
      conn = post(conn, path, params)

      assert render_template(conn) == "register.html"
    end

    test "redirects if authorized", %{conn: conn, path: path} do
      params = %{"user" => %{"username" => "username", "password" => "password", "password_confirmation" => "password"}}

      conn
      |> post(path, params)
      |> assert_redirect_if_authorized()
    end
  end

  describe "GET /users/logout" do
    setup do
      path = ~p"/users/logout"
      {:ok, path: path}
    end

    test "logouts and redirects to root page", %{conn: conn, path: path} do
      conn = get(conn, path)
      assert redirected_to(conn) == ~p"/"
    end

    test "redirects if unauthorized", %{conn_without_auth: conn, path: path} do
      conn
      |> get(path)
      |> assert_redirect_if_unauthorized()
    end
  end
end
