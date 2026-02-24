defmodule EuropaWeb.UnauthorizedOnlyTest do
  use EuropaWeb.ConnCase

  alias EuropaWeb.UnauthorizedOnly

  describe "call/2" do
    test "does nothing when user unauthorized", %{conn_without_auth: conn} do
      conn = UnauthorizedOnly.call(conn)
      refute conn.halted
    end

    test "redirects and halts", %{conn: conn} do
      conn = UnauthorizedOnly.call(conn)
      assert redirected_to(conn) == ~p"/"
      assert conn.halted
    end
  end
end
