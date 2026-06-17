defmodule Europa.Server.Loot.Weapon.Ammo do
  use TypedStruct

  alias Europa.Server.Loot
  alias Europa.Server.Loot.Weapon

  typedstruct enforce: true do
    field :uuid, Loot.uuid()
    field :caliber, Weapon.caliber()
    field :weight, Loot.Item.weight()
    field :count, pos_integer()
  end

  @spec new(map()) :: t()
  def new(attrs) when is_map(attrs) do
    %__MODULE__{
      uuid: Ecto.UUID.generate(),
      caliber: Map.fetch!(attrs, :caliber),
      weight: Map.fetch!(attrs, :weight),
      count: Map.fetch!(attrs, :count)
    }
  end

  @spec decrease_count(t(), n :: pos_integer()) :: t()
  def decrease_count(%__MODULE__{} = ammo, n) when n > 0 do
    updated_value = (ammo.count - n) |> max(0)
    struct!(ammo, count: updated_value)
  end

  @spec weight(Weapon.caliber()) :: Loot.Item.weight()
  def weight(caliber) when is_binary(caliber) do
    get_weights()
    |> Map.fetch!(caliber)
  end

  defp get_weights do
    Loot.get_items(:ammo)
    |> Enum.map(fn {%{caliber: caliber, weight: weight}, _} -> {caliber, weight} end)
    |> Enum.into(%{})
  end
end

defimpl Europa.Server.Loot.Item, for: Europa.Server.Loot.Weapon.Ammo do
  use Gettext, backend: Europa.Gettext

  alias Europa.Server.Loot
  alias Europa.Server.Loot.Weapon.Ammo
  alias Europa.Server.Errors
  alias Europa.Tools.NumberHelpers

  @spec item_type(Ammo.t()) :: :ammo
  def item_type(%Ammo{}), do: :ammo

  @spec negative_attrs(Ammo.t()) :: list(atom())
  def negative_attrs(%Ammo{}) do
    []
  end

  @spec composed_name(Ammo.t()) :: String.t()
  def composed_name(%Ammo{} = ammo) do
    "AMMO: #{ammo.caliber} (#{ammo.count})"
  end

  @spec readable_attrs(Ammo.t()) :: list()
  def readable_attrs(%Ammo{} = ammo) do
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

  @spec stackable?(Ammo.t()) :: true
  def stackable?(%Ammo{}), do: true

  @spec disassemblable?(Ammo.t()) :: false
  def disassemblable?(%Ammo{}), do: false

  @spec disassemble(Ammo.t()) :: {:error, Errors.NotApplicableError.t()}
  def disassemble(%Ammo{}) do
    {:error, %Errors.NotApplicableError{}}
  end

  @spec player_stats_changes(Ammo.t()) :: map()
  def player_stats_changes(%Ammo{}), do: %{}

  @spec weight(Ammo.t()) :: Loot.Item.weight()
  def weight(%Ammo{weight: weight, count: count}) do
    weight * count
  end
end
