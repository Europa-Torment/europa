defmodule EuropaWeb.UserController do
  use EuropaWeb, :controller

  alias Europa.Users

  @spec login(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def login(conn, _params) do
    changeset = Users.login_changeset(%{})
    render(conn, :login, changeset: changeset)
  end

  @spec do_login(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def do_login(conn, %{"user" => params}) do
    case Users.check_login(params) do
      {:ok, user} ->
        login_user(conn, user)

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :login, changeset: changeset)

      {:error, _} ->
        conn
        |> put_flash(:error, gettext("Invalid username or password"))
        |> redirect(to: ~p"/users/login")
    end
  end

  @spec new(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def new(conn, _params) do
    {captcha_text, captcha_img} = generate_captcha()

    changeset = Users.create_changeset(%{})

    conn
    |> put_session(:captcha, captcha_text)
    |> assign(:captcha_img, captcha_img)
    |> render(:register, changeset: changeset)
  end

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, %{"user" => params}) do
    params = Map.put(params, "captcha", get_session(conn, :captcha))

    case Users.create_user(params) do
      {:ok, user} ->
        login_user(conn, user)

      {:error, changeset} ->
        {captcha_text, captcha_img} = generate_captcha()

        conn
        |> put_session(:captcha, captcha_text)
        |> assign(:captcha_img, captcha_img)
        |> render(:register, changeset: changeset)
    end
  end

  @spec logout(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def logout(conn, _params) do
    conn
    |> delete_session(:current_user)
    |> redirect(to: ~p"/")
  end

  defp login_user(conn, user) do
    conn
    |> assign(:current_user, user.id)
    |> put_session(:current_user, user.id)
    |> redirect(to: ~p"/games")
  end

  defp generate_captcha do
    {:ok, captcha_text, captcha_img} = Captcha.get()
    captcha_img = Base.encode64(captcha_img)

    {captcha_text, captcha_img}
  end
end
