defmodule Europa.Users.UserTestx do
  use Europa.DataCase

  alias Europa.Users.User
  alias Europa.Repo

  describe "changeset/1" do
    test "validates username format" do
      changeset = User.create_changeset(%{"username" => "некорректное значение"})
      assert "has invalid format" in errors_on(changeset).username
    end

    test "validates username uniqueness" do
      user = insert(:user)

      {:error, changeset} =
        params_for(:user)
        |> Map.put(:username, user.username)
        |> User.create_changeset()
        |> Repo.insert()

      assert "has already been taken" in errors_on(changeset).username
    end

    test "validates username length" do
      changeset = User.create_changeset(%{"username" => "a"})
      assert "should be at least 2 character(s)" in errors_on(changeset).username
    end

    test "validates password length" do
      changeset = User.create_changeset(%{"password" => "a"})
      assert "should be at least 5 character(s)" in errors_on(changeset).password
    end

    test "validates password confirmation" do
      changeset =
        User.create_changeset(%{"password" => "abcdefg", "password_confirmation" => "afadaa"})

      assert "does not match confirmation" in errors_on(changeset).password_confirmation
    end
  end
end
