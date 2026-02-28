defmodule Europa.Support.Factory do
  # coveralls-ignore-start
  use ExMachina.Ecto, repo: Europa.Repo

  alias Europa.Server.Chat
  alias Europa.Server.Loot
  alias Europa.Server.Player
  alias Europa.Server.Planet
  alias Europa.Server.Enemy
  alias Europa.Users.User
  alias Europa.Games.Game
  alias Europa.Support.PlanetLandConverter

  @spec user_factory() :: User.t()
  def user_factory do
    %User{
      username: sequence(:user, &"user#{&1 + 1}"),
      hashed_password: Bcrypt.hash_pwd_salt("password"),
      password: "password",
      password_confirmation: "password"
    }
  end

  @spec game_factory() :: Game.t()
  def game_factory do
    %Game{
      uuid: Ecto.UUID.generate(),
      state: :active,
      user: build(:user)
    }
  end

  @spec chat_factory() :: Chat.t()
  def chat_factory do
    %Chat{
      messages: [],
      last_id: 0
    }
  end

  @spec chat_message_factory() :: Chat.Message.t()
  def chat_message_factory do
    %Chat.Message{
      category: :regular,
      text: sequence(:text, &"Message #{&1 + 1}")
    }
  end

  @spec loot_item_box_factory() :: Loot.ItemBox.t()
  def loot_item_box_factory do
    %Loot.ItemBox{
      type: :box,
      items: [build(:weapon), build(:ammo)],
      stand_on: Planet.snow()
    }
  end

  @spec weapon_factory() :: Loot.Weapon.t()
  def weapon_factory do
    %Loot.Weapon{
      uuid: Ecto.UUID.generate(),
      equiped: false,
      name: sequence(:name, &"weapon #{&1 + 1}"),
      shot_cost: 1,
      reload_cost: 1,
      magazine_size: 10,
      accuracy: 30,
      rounds_loaded: 10,
      shooting_type: :bullet,
      damage: 10,
      caliber: "8mm",
      shooting_distance: 5,
      image_name: "default_pistol",
      sound_name: "pistol"
    }
  end

  @spec ammo_factory() :: Loot.Ammo.t()
  def ammo_factory do
    %Loot.Weapon.Ammo{
      uuid: Ecto.UUID.generate(),
      caliber: "8mm",
      count: 10
    }
  end

  @spec helmet_factory() :: Loot.Helmet.t()
  def helmet_factory do
    %Loot.Helmet{
      uuid: Ecto.UUID.generate(),
      name: sequence(:name, &"helmet #{&1 + 1}"),
      max_health: 1,
      accuracy: 2,
      image_name: "default_helmet"
    }
  end

  @spec suit_factory() :: Loot.Suit.t()
  def suit_factory do
    %Loot.Suit{
      uuid: Ecto.UUID.generate(),
      name: sequence(:name, &"suit #{&1 + 1}"),
      max_health: 1,
      efficiency: 2,
      image_name: "default_suit"
    }
  end

  @spec boots_factory() :: Loot.Boots.t()
  def boots_factory do
    %Loot.Boots{
      uuid: Ecto.UUID.generate(),
      name: sequence(:name, &"boots #{&1 + 1}"),
      max_health: 1,
      efficiency: 2,
      image_name: "default_boots"
    }
  end

  @spec supply_factory() :: Loot.Supply.t()
  def supply_factory do
    %Loot.Supply{
      uuid: Ecto.UUID.generate(),
      type: :medicine,
      name: sequence(:name, &"supply #{&1 + 1}"),
      count: 1,
      consume_cost: 1,
      properties: build(:supply_properties)
    }
  end

  @spec supply_properties_factory() :: Loot.Supply.Properties.t()
  def supply_properties_factory do
    %Loot.Supply.Properties{
      health: 10
    }
  end

  @spec player_factory() :: Player.t()
  def player_factory do
    %Player{
      view_direction: :up,
      inventory: [],
      inventory_size: 10,
      max_health: 100,
      health: 50,
      accuracy: 5,
      efficiency: 1,
      stand_on: Planet.snow()
    }
  end

  @spec planet_factory(map()) :: Planet.t()
  def planet_factory(opts \\ %{}) do
    %Planet{
      year: Map.get(opts, :year, 1000),
      current_coord: Map.get(opts, :current_coord, {4, 5}),
      land: Map.get(opts, :land, default_land())
    }
  end

  @spec planet_action_factory() :: Planet.Action.t()
  def planet_action_factory do
    %Planet.Action{
      subject: build(:enemy),
      action_type: :attack
    }
  end

  @spec enemy_factory() :: Enemy.t()
  def enemy_factory do
    %Enemy{
      type: :monster,
      name: sequence(:name, &"Enemy #{&1 + 1}"),
      health: 20,
      damage: 5,
      move_distance: 2,
      accuracy: 5,
      stand_on: Planet.snow(),
      image_name: "monster_semiworm"
    }
  end

  ### PRIVATE ###

  defp default_land do
    s = Planet.snow()
    p = Planet.player()

    [
      [s, s, s, s, s, s, s, s, s, s],
      [s, s, s, s, s, s, s, s, s, s],
      [s, s, s, s, s, s, s, s, s, s],
      [s, s, s, s, s, s, s, s, s, s],
      [s, s, s, s, p, s, s, s, s, s],
      [s, s, s, s, s, s, s, s, s, s],
      [s, s, s, s, s, s, s, s, s, s],
      [s, s, s, s, s, s, s, s, s, s],
      [s, s, s, s, s, s, s, s, s, s],
      [s, s, s, s, s, s, s, s, s, s]
    ]
    |> PlanetLandConverter.from_matrix()
  end

  # coveralls-ignore-stop
end
