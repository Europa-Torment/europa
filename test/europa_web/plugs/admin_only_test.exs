defmodule EuropaWeb.AdminOnlyTest do
  use EuropaWeb.ConnCase

  alias EuropaWeb.AdminOnly

  describe "call/2" do
    test "does nothing when user is admin", %{admin_conn: conn} do
      conn = AdminOnly.call(conn)
      refute conn.halted
    end

    test "redirects and halts (not authorized)", %{conn_without_auth: conn} do
      conn = AdminOnly.call(conn)
      assert redirected_to(conn) == ~p"/"
      assert conn.halted
    end

    test "redirects and halts (not admin)", %{conn: conn} do
      conn = AdminOnly.call(conn)
      assert redirected_to(conn) == ~p"/"
      assert conn.halted
    end
  end
end
