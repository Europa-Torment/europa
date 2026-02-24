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
end
