defmodule Europa.Server.Loot.Weapon do
  use TypedStruct

  alias Europa.Tools.Types
  alias Europa.Server.Loot
  alias Europa.Server.Loot.Weapon.Ammo

  import Europa.Tools.Conf

  @allowed_shooting_types [:bullet, :burst, :shot]

  @burst_bullets_per_shot fetch_config!([:weapons, :burst_bullets_per_shot])

  @type shooting_type() :: unquote(Types.one_of(@allowed_shooting_types))
  @type caliber() :: String.t()

  typedstruct enforce: true do
    field :uuid, Loot.uuid()
    field :equiped, boolean(), default: false
    field :name, String.t()
    field :shot_cost, pos_integer()
    field :reload_cost, pos_integer()
    field :magazine_size, pos_integer()
    field :accuracy, pos_integer()
    field :rounds_loaded, integer()
    field :shooting_type, shooting_type()
    field :damage, pos_integer()
    field :caliber, caliber()
    field :shooting_distance, pos_integer()
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
      image_name: Map.fetch!(attrs, :image_name),
      sound_name: Map.fetch!(attrs, :sound_name)
    }
  end

  @spec decrease_rounds_loaded(t(), n :: pos_integer()) :: t()
  def decrease_rounds_loaded(%__MODULE__{} = weapon, n \\ 1) when n > 0 do
    updated_value = (weapon.rounds_loaded - n) |> max(0)
    struct(weapon, rounds_loaded: updated_value)
  end

  @spec add_rounds(t(), rounds_count :: pos_integer()) :: t()
  def add_rounds(%__MODULE__{} = weapon, rounds_count) when rounds_count > 0 do
    struct(weapon, rounds_loaded: weapon.rounds_loaded + rounds_count)
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
    ammo = Ammo.new(%{caliber: weapon.caliber, count: weapon.rounds_loaded})
    updated_weapon = decrease_rounds_loaded(weapon, weapon.rounds_loaded)

    {:ok, {updated_weapon, ammo}}
  end
end

defimpl Europa.Server.Loot.Item, for: Europa.Server.Loot.Weapon do
  use Gettext, backend: Europa.Gettext

  alias Europa.Server.Loot.Weapon

  @spec item_type(Weapon.t()) :: :weapon
  def item_type(%Weapon{}), do: :weapon

  @spec composed_name(Weapon.t()) :: String.t()
  def composed_name(%Weapon{} = weapon) do
    [
      weapon.name,
      " (",
      "D:#{weapon.damage} ",
      "A:#{weapon.accuracy} ",
      "SD:#{weapon.shooting_distance} ",
      "T:#{weapon.shooting_type} ",
      "C:#{weapon.caliber} ",
      "M:#{weapon.magazine_size} ",
      "L:#{weapon.rounds_loaded} ",
      "SC:#{weapon.shot_cost} ",
      "RC:#{weapon.reload_cost}",
      ")"
    ]
    |> to_string()
  end

  @spec readable_attrs(Weapon.t()) :: list()
  def readable_attrs(%Weapon{} = weapon) do
    [
      {gettext("Name"), weapon.name},
      {gettext("Damage"), weapon.damage},
      {gettext("Accuracy"), weapon.accuracy},
      {gettext("Shooting distance"), weapon.shooting_distance},
      {gettext("Shooting type"), weapon.shooting_type},
      {gettext("Shot cost"), weapon.shot_cost},
      {gettext("Reload cost"), weapon.reload_cost},
      {gettext("Magazine"), weapon.magazine_size},
      {gettext("Loaded"), weapon.rounds_loaded},
      {gettext("Caliber"), weapon.caliber}
    ]
  end

  @spec equip(Weapon.t()) :: {:ok, Weapon.t()}
  def equip(%Weapon{} = weapon) do
    {:ok, struct(weapon, equiped: true)}
  end

  @spec unequip(Weapon.t()) :: {:ok, Weapon.t()}
  def unequip(%Weapon{} = weapon) do
    {:ok, struct(weapon, equiped: false)}
  end

  @spec equipable?(Weapon.t()) :: true
  def equipable?(%Weapon{}), do: true

  @spec consumable?(Weapon.t()) :: false
  def consumable?(%Weapon{}), do: false

  @spec player_stats_changes(Weapon.t()) :: map()
  def player_stats_changes(%Weapon{} = weapon) do
    %{
      accuracy: weapon.accuracy
    }
  end
end
