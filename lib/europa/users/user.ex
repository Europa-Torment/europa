defmodule Europa.Users.User do
  use Ecto.Schema

  import Ecto.Changeset

  @create_required_fields [:username, :password, :password_confirmation, :hashed_password]
  @login_required_fields [:username, :password]

  @username_regex ~r/[A-Za-z0-9]/

  schema "users" do
    field :username, :string
    field :hashed_password, :string

    field :password, :string, virtual: true
    field :password_confirmation, :string, virtual: true

    field :captcha, :string, virtual: true
    field :captcha_confirmation, :string, virtual: true

    timestamps()
  end

  @spec create_changeset(map()) :: Ecto.Changeset.t()
  def create_changeset(params \\ %{}) do
    %__MODULE__{}
    |> cast(params, @create_required_fields)
    |> validate_required(@create_required_fields)
    |> validate_username()
    |> validate_password()
    |> unique_constraint(:username)
    |> validate_confirmation(:password)
    |> validate_confirmation(:captcha)
  end

  @spec login_changeset(map()) :: Ecto.Changeset.t()
  def login_changeset(params \\ %{}) do
    %__MODULE__{}
    |> cast(params, @login_required_fields)
    |> validate_required(@login_required_fields)
    |> validate_username()
    |> validate_password()
  end

  defp validate_username(changeset) do
    changeset
    |> validate_format(:username, @username_regex)
    |> validate_length(:username, min: 2, max: 100)
  end

  defp validate_password(changeset) do
    changeset
    |> validate_length(:password, min: 5, max: 100)
  end
end
