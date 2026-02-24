defmodule Europa.Users do
  alias Europa.Repo
  alias Europa.Users.User

  @type id :: pos_integer()

  defdelegate create_changeset(params), to: User
  defdelegate login_changeset(params), to: User

  @spec create_user(map()) :: {:ok, User.t()} | {:error, Ecto.Chageset.t()}
  def create_user(params) when is_map(params) do
    params
    |> maybe_put_hashed_password()
    |> User.create_changeset()
    |> Repo.insert()
  end

  @spec check_login(map()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t() | :invalid_password | :not_found}
  def check_login(params) do
    with {:ok, _changeset} <- validate_login_params(params),
         username <- Map.fetch!(params, "username"),
         password <- Map.fetch!(params, "password"),
         {:ok, user} <- get_by_username(username),
         :ok <- check_password(user, password) do
      {:ok, user}
    end
  end

  @spec get_by_username(String.t()) :: {:ok, User.t()} | {:error, :not_found}
  def get_by_username(username) do
    case Repo.get_by(User, username: username) do
      nil ->
        {:error, :not_found}

      user ->
        {:ok, user}
    end
  end

  @spec get_by_id(pos_integer()) :: {:ok, User.t()} | {:error, :not_found}
  def get_by_id(id) do
    case Repo.get(User, id) do
      nil ->
        {:error, :not_found}

      user ->
        {:ok, user}
    end
  end

  defp validate_login_params(params) do
    params
    |> login_changeset()
    |> Ecto.Changeset.apply_action(:login)
  end

  defp check_password(user, password) do
    if Bcrypt.verify_pass(password, user.hashed_password) do
      :ok
    else
      {:error, :invalid_password}
    end
  end

  defp maybe_put_hashed_password(%{"password" => password} = params) when is_binary(password) do
    hashed_password = Bcrypt.hash_pwd_salt(password)
    Map.put(params, "hashed_password", hashed_password)
  end

  defp maybe_put_hashed_password(params), do: params
end
