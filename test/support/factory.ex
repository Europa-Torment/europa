defmodule Europa.Support.Factory do
  # coveralls-ignore-start
  use ExMachina.Ecto, repo: Europa.Repo

  alias Europa.Server.Chat
  alias Europa.Server.Loot
  alias Europa.Server.Player
  alias Europa.Server.Player.Diseases.Disease
  alias Europa.Server.Player.Buff
  alias Europa.Server.Planet
  alias Europa.Server.Planet.Storm
  alias Europa.Server.Planet.Tiles
  alias Europa.Server.Planet.Tiles.Objects.Object
  alias Europa.Server.Enemy
  alias Europa.Server.Npc
  alias Europa.Server.Action
  alias Europa.Server.Event
  alias Europa.Server.Compass
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
      id: sequence(:id, &:"weapon_#{&1 + 1}"),
      uuid: Ecto.UUID.generate(),
      subtype: :pistol,
      equipped: false,
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
      weight: 1.0,
      image_name: "default_pistol",
      sound_name: "pistol"
    }
  end

  @spec ammo_factory() :: Loot.Weapon.Ammo.t()
  def ammo_factory do
    %Loot.Weapon.Ammo{
      id: sequence(:id, &:"ammo_#{&1 + 1}"),
      uuid: Ecto.UUID.generate(),
      subtype: :pistol,
      caliber: ".40 S&W",
      description: "description",
      weight: 1.0,
      count: 10
    }
  end

  @spec melee_weapon_factory() :: Loot.MeleeWeapon.t()
  def melee_weapon_factory do
    %Loot.MeleeWeapon{
      id: sequence(:id, &:"melee_weapon_#{&1 + 1}"),
      uuid: Ecto.UUID.generate(),
      subtype: :melee_weapon,
      equipped: false,
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
      id: sequence(:id, &:"helmet_#{&1 + 1}"),
      uuid: Ecto.UUID.generate(),
      subtype: :helmet,
      name: sequence(:name, &"helmet #{&1 + 1}"),
      description: "description",
      max_health: 1,
      max_warm: 1,
      accuracy: 2,
      weight: 1.0,
      image_name: "civil_helmet"
    }
  end

  @spec suit_factory() :: Loot.Suit.t()
  def suit_factory do
    %Loot.Suit{
      id: sequence(:id, &:"suit_#{&1 + 1}"),
      uuid: Ecto.UUID.generate(),
      subtype: :suit,
      name: sequence(:name, &"suit #{&1 + 1}"),
      description: "description",
      max_health: 1,
      max_warm: 1,
      max_weight: 1,
      efficiency: 2,
      weight: 1.0,
      image_name: "civil_suit"
    }
  end

  @spec boots_factory() :: Loot.Boots.t()
  def boots_factory do
    %Loot.Boots{
      id: sequence(:id, &:"boots_#{&1 + 1}"),
      uuid: Ecto.UUID.generate(),
      subtype: :boots,
      name: sequence(:name, &"boots #{&1 + 1}"),
      description: "description",
      max_health: 1,
      max_warm: 1,
      efficiency: 2,
      weight: 1.0,
      image_name: "civil_boots"
    }
  end

  @spec supply_factory() :: Loot.Supply.t()
  def supply_factory do
    %Loot.Supply{
      id: sequence(:id, &:"supply_#{&1 + 1}"),
      uuid: Ecto.UUID.generate(),
      subtype: :food,
      name: sequence(:name, &"supply #{&1 + 1}"),
      description: "description",
      count: 1,
      consume_cost: 1,
      properties: build(:supply_properties),
      diseases: [],
      buffs: [],
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

  @spec implant_factory() :: Loot.Implant.t()
  def implant_factory do
    %Loot.Implant{
      id: sequence(:id, &:"implant_#{&1 + 1}"),
      uuid: Ecto.UUID.generate(),
      subtype: :implant,
      name: sequence(:name, &"implant #{&1 + 1}"),
      description: "description",
      properties: build(:implant_properties),
      weight: 1.0
    }
  end

  @spec implant_properties_factory() :: Loot.Implant.Properties.t()
  def implant_properties_factory do
    %Loot.Implant.Properties{
      max_health: 11,
      max_warm: 15,
      accuracy: 20,
      efficiency: 30,
      max_weight: 50,
      shoot_damage: 2,
      shotgun_damage: 3,
      melee_damage: 1
    }
  end

  @spec tool_factory() :: Loot.Tool.t()
  def tool_factory do
    %Loot.Tool{
      id: sequence(:id, &:"tool_#{&1 + 1}"),
      uuid: Ecto.UUID.generate(),
      subtype: :common,
      name: sequence(:name, &"tool #{&1 + 1}"),
      description: "description",
      count: 1,
      properties: build(:tool_properties),
      stackable?: true,
      weight: 1.0,
      sound_name: "assemble"
    }
  end

  @spec resource_factory() :: Loot.Resource.t()
  def resource_factory do
    %Loot.Resource{
      id: sequence(:id, &:"resource_#{&1 + 1}"),
      uuid: Ecto.UUID.generate(),
      subtype: :common,
      name: sequence(:name, &"resource #{&1 + 1}"),
      description: "description",
      count: 1,
      weight: 1.0
    }
  end

  @spec tool_properties_factory() :: Loot.Tool.Properties.t()
  def tool_properties_factory do
    %Loot.Tool.Properties{
      level: 1
    }
  end

  @spec blueprint_factory() :: Loot.Blueprints.Blueprint.t()
  def blueprint_factory do
    %Loot.Blueprints.Blueprint{
      item: build(:weapon),
      resources: [build(:resource)]
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
      aim_mode?: false,
      max_implants: 3,
      ambient_temperature: 0,
      diseases: [],
      buffs: []
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
      characters_pid: characters_pid,
      player_fraction: Map.get(opts, :player_fraction, :neutral),
      storm: Map.get(opts, :storm)
    }
  end

  @spec storm_factory() :: Storm.t()
  def storm_factory do
    %Storm{
      level: 1,
      max_level: 2,
      temperature: -100,
      duration: 10,
      direction: :up
    }
  end

  @spec compass_factory() :: Compass.t()
  def compass_factory do
    %Compass{
      current_target: nil,
      targets: []
    }
  end

  @spec compass_target_factory() :: Compass.Target.t()
  def compass_target_factory do
    %Compass.Target{
      uuid: Ecto.UUID.generate(),
      coord: {1, 2},
      description: "Something"
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
      uuid: Ecto.UUID.generate(),
      type: :monster,
      name: sequence(:name, &"Enemy #{&1 + 1}"),
      description: "description",
      health: 20,
      max_health: 30,
      damage: 5,
      move_distance: 1,
      accuracy: 5,
      radioactive?: false,
      cold?: false,
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
      fraction: :neutral,
      enemy_fractions: [],
      not_playable?: false,
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
      uuid: Ecto.UUID.generate(),
      character: character,
      story: Character.random_story(character),
      stand_on: Tiles.tile(:ice).atom_value,
      view_direction: :down,
      weapon: build(:weapon),
      health: 100,
      accuracy: 50
    }
  end

  @spec disease_factory() :: Disease.t()
  def disease_factory do
    %Disease{
      id: sequence(:id, &:"disease_#{&1 + 1}"),
      name: sequence(:name, &"disease_#{&1 + 1}"),
      progression_possibility: 1,
      satisfaction: 100,
      moves_to_recovery: 100,
      debuffs: build(:disease_debuffs)
    }
  end

  @spec disease_debuffs_factory() :: Disease.Debuffs.t()
  def disease_debuffs_factory do
    %Disease.Debuffs{
      damage: 1,
      extra_moves_count: 1,
      efficiency: -1,
      accuracy: -1,
      max_health: -1,
      max_warm: -1
    }
  end

  @spec buff_factory() :: Buff.t()
  def buff_factory do
    %Buff{
      stat_name: :max_health,
      value: 10,
      duration: 20
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
