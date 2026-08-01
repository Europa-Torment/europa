defmodule Europa.Server.Loot.Weapon.Ammo do
  use TypedStruct

  alias Europa.Server.Loot
  alias Europa.Server.Loot.Weapon

  typedstruct enforce: true do
    field :id, atom()
    field :uuid, Loot.uuid()
    field :subtype, Loot.item_subtype()
    field :caliber, Weapon.caliber()
    field :description, String.t()
    field :weight, Loot.Item.weight()
    field :count, pos_integer()
  end

  @spec new(map()) :: t()
  def new(attrs) when is_map(attrs) do
    %__MODULE__{
      id: Map.fetch!(attrs, :id) |> String.to_atom(),
      uuid: Ecto.UUID.generate(),
      subtype: Map.fetch!(attrs, :subtype) |> String.to_atom(),
      caliber: Map.fetch!(attrs, :caliber),
      description: Map.fetch!(attrs, :description),
      weight: Map.fetch!(attrs, :weight),
      count: Map.fetch!(attrs, :count)
    }
  end
end

defimpl Europa.Server.Loot.Item, for: Europa.Server.Loot.Weapon.Ammo do
  use Gettext, backend: Europa.Gettext

  alias Europa.Server.Loot
  alias Europa.Server.Loot.Weapon.Ammo
  alias Europa.Server.Errors
  alias Europa.Tools.NumberHelpers
  alias Europa.Seerver.Player

  @spec id(Ammo.t()) :: atom()
  def id(%Ammo{id: id}), do: id

  @spec item_type(Ammo.t()) :: :ammo
  def item_type(%Ammo{}), do: :ammo

  @spec item_subtype(Ammo.t()) :: Loot.item_subtype()
  def item_subtype(%Ammo{subtype: subtype}), do: subtype

  @spec negative_attrs(Ammo.t()) :: list(atom())
  def negative_attrs(%Ammo{}) do
    []
  end

  @spec composed_name(Ammo.t()) :: String.t()
  def composed_name(%Ammo{} = ammo) do
    "AMMO: #{ammo.caliber} (#{ammo.count})"
  end

  @spec description(Ammo.t()) :: String.t()
  def description(%Ammo{description: description}), do: description

  @spec readable_attrs(Ammo.t(), Player.t()) :: list()
  def readable_attrs(%Ammo{} = ammo, _player) do
    [
      {:caliber, gettext("Caliber"), ammo.caliber},
      {:count, gettext("Count"), ammo.count},
      {:weight, gettext("Weight"), NumberHelpers.round(ammo.count * ammo.weight, 2)}
    ]
  end

  @spec equip(Ammo.t()) :: {:error, Errors.NotApplicableError.t()}
  def equip(%Ammo{}) do
    {:error, %Errors.NotApplicableError{}}
  end

  @spec unequip(Ammo.t()) :: {:error, Errors.NotApplicableError.t()}
  def unequip(%Ammo{}) do
    {:error, %Errors.NotApplicableError{}}
  end

  @spec equipable?(Ammo.t()) :: false
  def equipable?(%Ammo{}), do: false

  @spec consumable?(Ammo.t()) :: false
  def consumable?(%Ammo{}), do: false

  @spec usable?(Ammo.t()) :: false
  def usable?(%Ammo{}), do: false

  @spec stackable?(Ammo.t()) :: true
  def stackable?(%Ammo{}), do: true

  @spec player_stats_changes(Ammo.t()) :: map()
  def player_stats_changes(%Ammo{}), do: %{}

  @spec weight(Ammo.t()) :: Loot.Item.weight()
  def weight(%Ammo{weight: weight, count: count}) do
    weight * count
  end
end
