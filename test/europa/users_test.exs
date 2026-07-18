defmodule Europa.UsersTest do
  use Europa.DataCase

  alias Europa.Users
  alias Europa.Users.User

  describe "create_user/1" do
    setup do
      params = %{
        "username" => "test",
        "password" => "password123",
        "password_confirmation" => "password123"
      }

      {:ok, params: params}
    end

    test "creates user", %{params: params} do
      assert {:ok, %User{} = user} = Users.create_user(params)
      assert user.username == Map.get(params, "username")
      assert Bcrypt.verify_pass("password123", user.hashed_password)
    end

    test "returns error when params are invalid" do
      assert {:error, %Ecto.Changeset{valid?: false}} = Users.create_user(%{})
    end
  end

  describe "get_by_id/1" do
    test "returns user by id" do
      user = %User{id: user_id} = insert(:user)
      assert {:ok, %User{id: ^user_id}} = Users.get_by_id(user.id)
    end

    test "returns not_found error" do
      assert Users.get_by_id(0) == {:error, :not_found}
    end
  end

  describe "get_by_username/1" do
    test "returns user by username" do
      user = %User{id: user_id} = insert(:user)
      assert {:ok, %User{id: ^user_id}} = Users.get_by_username(user.username)
    end

    test "returns not_found error" do
      assert Users.get_by_username("fake") == {:error, :not_found}
    end
  end

  describe "admin?/1" do
    test "checks if user is admin" do
      user = insert(:user, role: :user)
      admin = insert(:user, role: :admin)

      assert Users.admin?(user.id) == false
      assert Users.admin?(user) == false

      assert Users.admin?(admin.id) == true
      assert Users.admin?(admin) == true

      assert Users.admin?(nil) == false
    end
  end

  describe "check_login/1" do
    test "returns user if params are valid" do
      user = %User{id: user_id} = insert(:user)
      params = %{"username" => user.username, "password" => "password"}

      assert {:ok, %User{id: ^user_id}} = Users.check_login(params)
    end

    test "returns error when params are invalid" do
      assert {:error, %Ecto.Changeset{valid?: false}} = Users.check_login(%{})
    end

    test "returns not_found error when user is not exists" do
      assert Users.check_login(%{"username" => "user1", "password" => "password"}) == {:error, :not_found}
    end

    test "returns invalid_password error" do
      user = insert(:user)

      assert Users.check_login(%{"username" => user.username, "password" => "fake-password"}) ==
               {:error, :invalid_password}
    end
  end

  describe "get_users_count/0" do
    test "returns all users count" do
      count = 10
      insert_list(count, :user)

      assert Users.get_users_count() == count
    end
  end

  describe "get_new_users_count/0" do
    test "returns new users count" do
      count = 10
      insert_list(count, :user)
      insert_list(count, :user, inserted_at: Timex.now() |> Timex.shift(days: -2))

      assert Users.get_new_users_count() == count
    end
  end
end
