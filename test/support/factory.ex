defmodule Europa.Support.Factory do
  # coveralls-ignore-start
  use ExMachina.Ecto, repo: Europa.Repo

  alias Europa.Server.Chat
  alias Europa.Server.Loot
  alias Europa.Server.Player
  alias Europa.Server.Planet
  alias Europa.Server.Planet.Tiles
  alias Europa.Server.Planet.Tiles.Objects.Object
  alias Europa.Server.Enemy
  alias Europa.Server.Npc
  alias Europa.Server.Action
  alias Europa.Server.Event
  alias Europa.Server.Characters
  alias Europa.Server.Characters.Character
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
      readable_name: "box",
      items: [build(:weapon), build(:ammo)],
      item_types: :all,
      movable?: false,
      max_items: 10,
      image_name: "test",
      placing: :outdoor,
      stand_on: Tiles.tile(:ice).atom_value
    }
  end

  @spec weapon_factory() :: Loot.Weapon.t()
  def weapon_factory do
    %Loot.Weapon{
      uuid: Ecto.UUID.generate(),
      equiped: false,
      name: sequence(:name, &"weapon #{&1 + 1}"),
      description: "description",
      shot_cost: 1,
      reload_cost: 1,
      magazine_size: 10,
      accuracy: 30,
      rounds_loaded: 10,
      shooting_type: :bullet,
      damage: 10,
      caliber: ".40 S&W",
      shooting_distance: 5,
      level: 1,
      parts_count: 2,
      weight: 1.0,
      image_name: "default_pistol",
      sound_name: "pistol"
    }
  end

  @spec ammo_factory() :: Loot.Weapon.Ammo.t()
  def ammo_factory do
    %Loot.Weapon.Ammo{
      uuid: Ecto.UUID.generate(),
      caliber: ".40 S&W",
      description: "description",
      weight: 1.0,
      count: 10
    }
  end

  @spec melee_weapon_factory() :: Loot.MeleeWeapon.t()
  def melee_weapon_factory do
    %Loot.MeleeWeapon{
      uuid: Ecto.UUID.generate(),
      equiped: false,
      name: sequence(:name, &"melee weapon #{&1 + 1}"),
      description: "description",
      hit_cost: 1,
      damage: 1,
      weight: 1.0,
      image_name: "default_pistol",
      sound_name: "sword"
    }
  end

  @spec helmet_factory() :: Loot.Helmet.t()
  def helmet_factory do
    %Loot.Helmet{
      uuid: Ecto.UUID.generate(),
      name: sequence(:name, &"helmet #{&1 + 1}"),
      description: "description",
      max_health: 1,
      max_warm: 1,
      accuracy: 2,
      weight: 1.0,
      image_name: "default_helmet"
    }
  end

  @spec suit_factory() :: Loot.Suit.t()
  def suit_factory do
    %Loot.Suit{
      uuid: Ecto.UUID.generate(),
      name: sequence(:name, &"suit #{&1 + 1}"),
      description: "description",
      max_health: 1,
      max_warm: 1,
      max_weight: 1,
      efficiency: 2,
      weight: 1.0,
      image_name: "default_suit"
    }
  end

  @spec boots_factory() :: Loot.Boots.t()
  def boots_factory do
    %Loot.Boots{
      uuid: Ecto.UUID.generate(),
      name: sequence(:name, &"boots #{&1 + 1}"),
      description: "description",
      max_health: 1,
      max_warm: 1,
      efficiency: 2,
      weight: 1.0,
      image_name: "default_boots"
    }
  end

  @spec supply_factory() :: Loot.Supply.t()
  def supply_factory do
    %Loot.Supply{
      uuid: Ecto.UUID.generate(),
      name: sequence(:name, &"supply #{&1 + 1}"),
      description: "description",
      count: 1,
      consume_cost: 1,
      properties: build(:supply_properties),
      weight: 1.0,
      sound_name: "eat"
    }
  end

  @spec supply_properties_factory() :: Loot.Supply.Properties.t()
  def supply_properties_factory do
    %Loot.Supply.Properties{
      health: 10,
      thirst: 10,
      hunger: 10,
      radiation: 10,
      warm: 10
    }
  end

  @spec tool_factory() :: Loot.Tool.t()
  def tool_factory do
    %Loot.Tool{
      uuid: Ecto.UUID.generate(),
      type: :weapon_parts,
      name: sequence(:name, &"tool #{&1 + 1}"),
      description: "description",
      count: 1,
      properties: build(:tool_properties),
      stackable?: true,
      weight: 1.0,
      sound_name: "assemble"
    }
  end

  @spec tool_properties_factory() :: Loot.Tool.Properties.t()
  def tool_properties_factory do
    %Loot.Tool.Properties{
      level: 1
    }
  end

  @spec blueprint_factory() :: Loot.Blueprint.t()
  def blueprint_factory do
    %Loot.Blueprint{
      item: build(:weapon),
      tools: [build(:tool)]
    }
  end

  @spec player_factory() :: Player.t()
  def player_factory do
    helmet = build(:helmet)
    suit = build(:suit)
    boots = build(:boots)

    %Player{
      character: build(:character),
      view_direction: :up,
      inventory: [],
      helmet_uuid: helmet.uuid,
      suit_uuid: suit.uuid,
      boots_uuid: boots.uuid,
      max_weight: 10.0,
      max_health: 100,
      health: 50,
      accuracy: 5,
      efficiency: 1,
      max_warm: 100,
      warm: 100,
      hunger: 0,
      thirst: 0,
      radiation: 0,
      stand_on: Tiles.tile(:ice).atom_value,
      aim_mode?: false
    }
  end

  @spec planet_factory(map()) :: Planet.t()
  def planet_factory(opts \\ %{}) do
    {:ok, characters_pid} = Characters.start_link()

    %Planet{
      year: Map.get(opts, :year, 1000),
      current_coord: Map.get(opts, :current_coord, {4, 5}),
      predefined_cluster_coord: Map.get(opts, :predefined_cluster_coord, {400, 500}),
      land: Map.get(opts, :land, default_land()),
      moves_count: Map.get(opts, :moves_count, 0),
      great_red_spots: Map.get(opts, :great_red_spots, 0),
      characters_pid: characters_pid
    }
  end

  @spec object_factory() :: Object.t()
  def object_factory do
    %Object{
      name: "wall",
      high?: true,
      image_name: "wall",
      transforms: []
    }
  end

  @spec object_transform_factory() :: Object.Transform.t()
  def object_transform_factory do
    %Object.Transform{
      name: sequence(:name, &"transform_#{&1 + 1}") |> String.to_atom(),
      readable_name: "Delete",
      transforms_to: :nothing,
      transform_requirements: :change_confirmation,
      transform_sound_name: "equip"
    }
  end

  @spec action_factory() :: Action.t()
  def action_factory do
    %Action{
      subject: build(:enemy),
      action_type: :attack
    }
  end

  @spec event_factory() :: Event.t()
  def event_factory do
    %Event{
      uuid: Ecto.UUID.generate(),
      type: {:damaged, 10}
    }
  end

  @spec enemy_factory() :: Enemy.t()
  def enemy_factory do
    %Enemy{
      type: :monster,
      name: sequence(:name, &"Enemy #{&1 + 1}"),
      description: "description",
      health: 20,
      max_health: 30,
      damage: 5,
      move_distance: 1,
      accuracy: 5,
      radioactive?: false,
      healer?: false,
      heal_possibility: 0,
      heal_unit: 0,
      max_items: 5,
      stand_on: Tiles.tile(:ice).atom_value,
      image_name: "monster_semiworm"
    }
  end

  @spec character_factory() :: Character.t()
  def character_factory do
    %Character{
      name: sequence(:name, &"Character #{&1 + 1}"),
      gender: :male,
      profession: "Game developer",
      age_at_disaster: 20,
      years: 1..48,
      stories: ["Story 1", "Story 2"],
      special_stories: %{},
      short_phrases: [],
      current_age: 30
    }
  end

  @spec npc_factory() :: Npc.t()
  def npc_factory do
    character = build(:character)

    %Npc{
      character: character,
      story: Character.random_story(character),
      stand_on: Tiles.tile(:ice).atom_value
    }
  end

  ### PRIVATE ###

  defp default_land do
    s = Tiles.tile(:snow).atom_value
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
