defmodule Europa.Server.Loot.Weapon do
  use TypedStruct

  alias Europa.Tools.Types
  alias Europa.Server
  alias Europa.Server.Loot
  alias Europa.Server.Loot.Weapon.Ammo

  import Europa.Tools.Conf

  @allowed_shooting_types [:bullet, :burst, :shot]

  @burst_bullets_per_shot fetch_config!([:weapons, :burst_bullets_per_shot])

  @type shooting_type() :: unquote(Types.one_of(@allowed_shooting_types))
  @type caliber() :: String.t()
  @type level() :: pos_integer()

  typedstruct enforce: true do
    field :uuid, Loot.uuid()
    field :equiped, boolean(), default: false
    field :name, String.t()
    field :shot_cost, Server.move_cost()
    field :reload_cost, Server.move_cost()
    field :magazine_size, pos_integer()
    field :accuracy, pos_integer()
    field :rounds_loaded, integer()
    field :shooting_type, shooting_type()
    field :damage, pos_integer()
    field :caliber, caliber()
    field :shooting_distance, pos_integer()
    field :level, level()
    field :parts_count, pos_integer()
    field :weight, Loot.Item.weight()
    field :image_name, String.t()
    field :sound_name, String.t()
  end

  @spec new(map()) :: t()
  def new(attrs) when is_map(attrs) do
    %__MODULE__{
      uuid: Ecto.UUID.generate(),
      equiped: false,
      name: Map.fetch!(attrs, :name),
      shot_cost: Map.fetch!(attrs, :shot_cost),
      reload_cost: Map.fetch!(attrs, :reload_cost),
      magazine_size: Map.fetch!(attrs, :magazine_size),
      accuracy: Map.fetch!(attrs, :accuracy),
      rounds_loaded: Map.fetch!(attrs, :rounds_loaded),
      shooting_type: Map.fetch!(attrs, :shooting_type) |> String.to_atom(),
      damage: Map.fetch!(attrs, :damage),
      caliber: Map.fetch!(attrs, :caliber),
      shooting_distance: Map.fetch!(attrs, :shooting_distance),
      level: Map.fetch!(attrs, :level),
      parts_count: Map.fetch!(attrs, :parts_count),
      weight: Map.fetch!(attrs, :weight),
      image_name: Map.fetch!(attrs, :image_name),
      sound_name: Map.fetch!(attrs, :sound_name)
    }
  end

  @spec decrease_rounds_loaded(t(), n :: pos_integer()) :: t()
  def decrease_rounds_loaded(%__MODULE__{} = weapon, n \\ 1) when n > 0 do
    updated_value = (weapon.rounds_loaded - n) |> max(0)
    struct!(weapon, rounds_loaded: updated_value)
  end

  @spec add_rounds(t(), rounds_count :: pos_integer()) :: t()
  def add_rounds(%__MODULE__{} = weapon, rounds_count) when rounds_count > 0 do
    struct!(weapon, rounds_loaded: weapon.rounds_loaded + rounds_count)
  end

  @spec rounds_per_shot(t()) :: pos_integer()
  def rounds_per_shot(%__MODULE__{} = weapon) do
    if weapon.shooting_type == :burst do
      min(@burst_bullets_per_shot, weapon.rounds_loaded)
    else
      1
    end
  end

  @spec check_reload_needed(t()) :: :ok | {:error, :full_magazine}
  def check_reload_needed(%__MODULE__{} = weapon) do
    case rounds_to_full_magazine(weapon) do
      {:ok, _rounds_needed} ->
        :ok

      error ->
        error
    end
  end

  @spec rounds_to_full_magazine(t()) :: {:ok, pos_integer()} | {:error, :full_magazine}
  def rounds_to_full_magazine(%__MODULE__{} = weapon) do
    if weapon.magazine_size == weapon.rounds_loaded do
      {:error, :full_magazine}
    else
      {:ok, weapon.magazine_size - weapon.rounds_loaded}
    end
  end

  @spec unload(t()) :: {:ok, {t(), Ammo.t()}} | {:error, :empty_magazine}
  def unload(%__MODULE__{rounds_loaded: 0}) do
    {:error, :empty_magazine}
  end

  def unload(%__MODULE__{} = weapon) do
    ammo = Ammo.new(%{caliber: weapon.caliber, count: weapon.rounds_loaded, weight: Ammo.weight(weapon.caliber)})
    updated_weapon = decrease_rounds_loaded(weapon, weapon.rounds_loaded)

    {:ok, {updated_weapon, ammo}}
  end
end

defimpl Europa.Server.Loot.Item, for: Europa.Server.Loot.Weapon do
  use Gettext, backend: Europa.Gettext

  alias Europa.Server.Loot
  alias Europa.Server.Loot.Weapon
  alias Europa.Server.Loot.Tool

  @spec item_type(Weapon.t()) :: :weapon
  def item_type(%Weapon{}), do: :weapon

  @spec negative_attrs(Weapon.t()) :: list(atom())
  def negative_attrs(%Weapon{}) do
    [:reload_cost, :shot_cost, :weight]
  end

  @spec composed_name(Weapon.t()) :: String.t()
  def composed_name(%Weapon{} = weapon) do
    [
      weapon.name,
      " (",
      "D:#{weapon.damage} ",
      "A:#{weapon.accuracy} ",
      "SD:#{weapon.shooting_distance} ",
      "C:#{weapon.caliber}",
      ")"
    ]
    |> to_string()
  end

  @spec readable_attrs(Weapon.t()) :: list()
  def readable_attrs(%Weapon{} = weapon) do
    [
      {:name, gettext("Name"), weapon.name},
      {:damage, gettext("Damage"), weapon.damage},
      {:accuracy, gettext("Accuracy"), weapon.accuracy},
      {:shooting_distance, gettext("Shooting distance"), weapon.shooting_distance},
      {:shooting_type, gettext("Shooting type"), weapon.shooting_type},
      {:shot_cost, gettext("Shot cost"), weapon.shot_cost},
      {:reload_cost, gettext("Reload cost"), weapon.reload_cost},
      {:magazine_size, gettext("Magazine"), weapon.magazine_size},
      {:rounds_loaded, gettext("Loaded"), weapon.rounds_loaded},
      {:caliber, gettext("Caliber"), weapon.caliber},
      {:weight, gettext("Weight"), weapon.weight}
    ]
  end

  @spec equip(Weapon.t()) :: {:ok, Weapon.t()}
  def equip(%Weapon{} = weapon) do
    {:ok, struct!(weapon, equiped: true)}
  end

  @spec unequip(Weapon.t()) :: {:ok, Weapon.t()}
  def unequip(%Weapon{} = weapon) do
    {:ok, struct!(weapon, equiped: false)}
  end

  @spec equipable?(Weapon.t()) :: true
  def equipable?(%Weapon{}), do: true

  @spec consumable?(Weapon.t()) :: false
  def consumable?(%Weapon{}), do: false

  @spec stackable?(Weapon.t()) :: false
  def stackable?(%Weapon{}), do: false

  @spec disassemblable?(Weapon.t()) :: true
  def disassemblable?(%Weapon{}), do: true

  @spec disassemble(Weapon.t()) :: list(Tool.t())
  def disassemble(%Weapon{} = weapon) do
    {:ok, Tool.from_weapon(weapon)}
  end

  @spec weight(Weapon.t()) :: Loot.Item.weight()
  def weight(%Weapon{weight: weight}) do
    weight
  end

  @spec player_stats_changes(Weapon.t()) :: map()
  def player_stats_changes(%Weapon{} = weapon) do
    %{
      accuracy: weapon.accuracy
    }
  end
end
