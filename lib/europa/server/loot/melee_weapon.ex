defmodule Europa.Server.Loot.MeleeWeapon do
  use TypedStruct

  alias Europa.Server
  alias Europa.Server.Loot

  typedstruct enforce: true do
    field :id, atom()
    field :uuid, Loot.uuid()
    field :subtype, Loot.item_subtype()
    field :equipped, boolean(), default: false
    field :name, String.t()
    field :description, String.t()
    field :damage, pos_integer()
    field :hit_cost, Server.move_cost()
    field :weight, Loot.Item.weight()
    field :image_name, String.t()
    field :sound_name, String.t()
  end

  @spec new(map()) :: t()
  def new(attrs) when is_map(attrs) do
    %__MODULE__{
      id: Map.fetch!(attrs, :id) |> String.to_atom(),
      uuid: Ecto.UUID.generate(),
      subtype: Map.fetch!(attrs, :subtype) |> String.to_atom(),
      equipped: false,
      name: Map.fetch!(attrs, :name),
      description: Map.fetch!(attrs, :description),
      damage: Map.fetch!(attrs, :damage),
      hit_cost: Map.fetch!(attrs, :hit_cost),
      weight: Map.fetch!(attrs, :weight),
      image_name: Map.fetch!(attrs, :image_name),
      sound_name: Map.fetch!(attrs, :sound_name)
    }
  end
end

defimpl Europa.Server.Loot.Item, for: Europa.Server.Loot.MeleeWeapon do
  use Gettext, backend: Europa.Gettext

  alias Europa.Server.Loot
  alias Europa.Server.Loot.MeleeWeapon
  alias Europa.Server.Player
  alias Europa.Server.PlayerManager

  @spec id(MeleeWeapon.t()) :: atom()
  def id(%MeleeWeapon{id: id}), do: id

  @spec item_type(MeleeWeapon.t()) :: :melee_weapon
  def item_type(%MeleeWeapon{}), do: :melee_weapon

  @spec item_subtype(MeleeWeapon.t()) :: Loot.item_subtype()
  def item_subtype(%MeleeWeapon{subtype: subtype}), do: subtype

  @spec negative_attrs(MeleeWeapon.t()) :: list(atom())
  def negative_attrs(%MeleeWeapon{}) do
    [:hit_cost, :weight]
  end

  @spec composed_name(MeleeWeapon.t()) :: String.t()
  def composed_name(%MeleeWeapon{} = weapon) do
    [
      weapon.name,
      " (",
      "D:#{weapon.damage}",
      ")"
    ]
    |> to_string()
  end

  @spec description(MeleeWeapon.t()) :: String.t()
  def description(%MeleeWeapon{description: description}), do: description

  @spec readable_attrs(MeleeWeapon.t(), Player.t()) :: list()
  def readable_attrs(%MeleeWeapon{} = weapon, %Player{} = player) do
    [
      {:name, gettext("Name"), weapon.name},
      {:damage, gettext("Damage"), PlayerManager.melee_weapon_damage(player, weapon)},
      {:hit_cost, gettext("Hit cost"), weapon.hit_cost},
      {:weight, gettext("Weight"), weapon.weight}
    ]
  end

  @spec equip(MeleeWeapon.t()) :: {:ok, MeleeWeapon.t()}
  def equip(%MeleeWeapon{} = weapon) do
    {:ok, struct!(weapon, equipped: true)}
  end

  @spec unequip(MeleeWeapon.t()) :: {:ok, MeleeWeapon.t()}
  def unequip(%MeleeWeapon{} = weapon) do
    {:ok, struct!(weapon, equipped: false)}
  end

  @spec equipable?(MeleeWeapon.t()) :: true
  def equipable?(%MeleeWeapon{}), do: true

  @spec consumable?(MeleeWeapon.t()) :: false
  def consumable?(%MeleeWeapon{}), do: false

  @spec usable?(MeleeWeapon.t()) :: false
  def usable?(%MeleeWeapon{}), do: false

  @spec stackable?(MeleeWeapon.t()) :: false
  def stackable?(%MeleeWeapon{}), do: false

  @spec weight(MeleeWeapon.t()) :: Loot.Item.weight()
  def weight(%MeleeWeapon{weight: weight}) do
    weight
  end

  @spec player_stats_changes(MeleeWeapon.t()) :: map()
  def player_stats_changes(%MeleeWeapon{}) do
    %{}
  end
end
