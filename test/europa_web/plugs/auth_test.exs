defmodule EuropaWeb.AuthTest do
  use EuropaWeb.ConnCase

  alias EuropaWeb.Auth

  describe "call/2" do
    test "assigns current_user", %{conn_with_session: conn, current_user: current_user} do
      conn = Auth.call(conn)
      assert conn.assigns.current_user == current_user.id
      assert conn.assigns.current_user_username == current_user.username
    end

    test "does nothing when no session", %{conn_without_auth: conn} do
      conn = Auth.call(conn)
      refute conn.assigns[:current_user]
    end
  end
end
