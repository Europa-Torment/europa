defmodule Europa.Server.Loot.MeleeWeapon do
  use TypedStruct

  alias Europa.Server
  alias Europa.Server.Loot

  typedstruct enforce: true do
    field :uuid, Loot.uuid()
    field :equiped, boolean(), default: false
    field :name, String.t()
    field :damage, pos_integer()
    field :hit_cost, Server.move_cost()
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

  @spec item_type(MeleeWeapon.t()) :: :melee_weapon
  def item_type(%MeleeWeapon{}), do: :melee_weapon

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

  @spec readable_attrs(MeleeWeapon.t()) :: list()
  def readable_attrs(%MeleeWeapon{} = weapon) do
    [
      {:name, gettext("Name"), weapon.name},
      {:damage, gettext("Damage"), weapon.damage},
      {:hit_cost, gettext("Hit cost"), weapon.hit_cost},
      {:weight, gettext("Weight"), weapon.weight}
    ]
  end

  @spec equip(MeleeWeapon.t()) :: {:ok, MeleeWeapon.t()}
  def equip(%MeleeWeapon{} = weapon) do
    {:ok, struct!(weapon, equiped: true)}
  end

  @spec unequip(MeleeWeapon.t()) :: {:ok, MeleeWeapon.t()}
  def unequip(%MeleeWeapon{} = weapon) do
    {:ok, struct!(weapon, equiped: false)}
  end

  @spec equipable?(MeleeWeapon.t()) :: true
  def equipable?(%MeleeWeapon{}), do: true

  @spec consumable?(MeleeWeapon.t()) :: false
  def consumable?(%MeleeWeapon{}), do: false

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
