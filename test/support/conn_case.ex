defmodule EuropaWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use EuropaWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  import Phoenix.ConnTest

  @endpoint EuropaWeb.Endpoint

  using do
    quote do
      # The default endpoint for testing
      @endpoint EuropaWeb.Endpoint

      use EuropaWeb, :verified_routes

      alias Europa.Users.User

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import EuropaWeb.ConnCase
      import Europa.Support.Factory
      import Hammox

      @spec render_template(Plug.Conn.t()) :: String.t()
      def render_template(conn), do: conn.private.phoenix_template

      @spec auth_conn() :: Plug.Conn.t()
      def auth_conn do
        insert(:user)
        |> auth_conn()
      end

      @spec auth_conn(User.t()) :: Plug.Conn.t()
      def auth_conn(user) do
        Phoenix.ConnTest.build_conn()
        |> Plug.Conn.assign(:current_user, user.id)
        |> Plug.Conn.assign(:current_user_username, user.username)
      end

      def assert_redirect_if_authorized(conn) do
        assert conn.halted
        assert redirected_to(conn) == ~p"/"
      end

      def assert_redirect_if_unauthorized(conn) do
        assert conn.halted
        assert redirected_to(conn) == ~p"/users/register"
      end
    end
  end

  setup tags do
    Europa.DataCase.setup_sandbox(tags)

    user = Europa.Support.Factory.insert(:user)

    conn =
      Phoenix.ConnTest.build_conn()
      |> bypass_through(EuropaWeb.Router, [:browser])
      |> get("/")

    conn_with_session =
      conn
      |> Plug.Conn.put_session(:current_user, user.id)

    conn_with_auth =
      conn_with_session
      |> Plug.Conn.assign(:current_user, user.id)
      |> Plug.Conn.assign(:current_user_username, user.username)

    {:ok, conn: conn_with_auth, conn_with_session: conn_with_session, conn_without_auth: conn, current_user: user}
  end
end
