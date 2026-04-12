defmodule EuropaWeb.AuthorizedOnlyTest do
  use EuropaWeb.ConnCase

  alias EuropaWeb.AuthorizedOnly

  describe "call/2" do
    test "does nothing when user authorized", %{conn: conn} do
      conn = AuthorizedOnly.call(conn)
      refute conn.halted
    end

    test "redirects and halts", %{conn_without_auth: conn} do
      conn = AuthorizedOnly.call(conn)
      assert redirected_to(conn) == ~p"/users/register"
      assert conn.halted
    end
  end
end
