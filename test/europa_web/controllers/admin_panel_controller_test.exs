defmodule EuropaWeb.AdminPanelControllerTest do
  use EuropaWeb.ConnCase

  describe "GET /" do
    setup do
      path = ~p"/admin"
      {:ok, path: path}
    end

    test "renders index template", %{admin_conn: conn, path: path} do
      conn = get(conn, path)
      assert render_template(conn) == "index.html"
    end

    test "redirect if unauthorized", %{conn_without_auth: conn, path: path} do
      conn
      |> get(path)
      |> assert_redirect_if_unauthorized()
    end

    test "redirect if not admin", %{conn: conn, path: path} do
      conn
      |> get(path)
      |> assert_redirect_if_not_admin()
    end
  end
end
