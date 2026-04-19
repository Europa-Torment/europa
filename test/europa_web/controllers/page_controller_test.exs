defmodule EuropaWeb.PageControllerTest do
  use EuropaWeb.ConnCase

  describe "GET /" do
    setup do
      path = ~p"/"
      {:ok, path: path}
    end

    test "renders home template", %{conn: conn, path: path} do
      conn = get(conn, path)
      assert render_template(conn) == "home.html"
    end
  end

  describe "GET /lore" do
    setup do
      path = ~p"/lore"
      {:ok, path: path}
    end

    test "renders lore template", %{conn: conn, path: path} do
      conn = get(conn, path)
      assert render_template(conn) == "lore.html"
    end
  end
end
