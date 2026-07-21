defmodule Europa.Server.Loot.Implant do
  use TypedStruct

  alias Europa.Server.Loot

  defmodule Properties do
    typedstruct do
      field :max_health, integer() | nil
      field :max_warm, integer() | nil
      field :max_weight, integer() | nil
      field :accuracy, integer() | nil
      field :shotgun_damage, integer() | nil
      field :shoot_damage, integer() | nil
      field :melee_damage, integer() | nil
    end

    @spec new(map()) :: t()
    def new(attrs) when is_map(attrs) do
      %__MODULE__{
        max_health: Map.get(attrs, :max_health),
        max_warm: Map.get(attrs, :max_warm),
        max_weight: Map.get(attrs, :max_weight),
        accuracy: Map.get(attrs, :accuracy),
        shotgun_damage: Map.get(attrs, :shotgun_damage),
        shoot_damage: Map.get(attrs, :shoot_damage),
        melee_damage: Map.get(attrs, :melee_damage)
      }
    end
  end

  typedstruct enforce: true do
    field :uuid, Loot.uuid()
    field :name, String.t()
    field :description, String.t()
    field :properties, Properties.t()
    field :equipped, boolean(), default: false
    field :weight, Loot.Item.weight()
  end

  @spec new(map()) :: t()
  def new(attrs) when is_map(attrs) do
    %__MODULE__{
      uuid: Ecto.UUID.generate(),
      name: Map.fetch!(attrs, :name),
      description: Map.fetch!(attrs, :description),
      properties: Map.fetch!(attrs, :properties) |> Properties.new(),
      equipped: false,
      weight: Map.fetch!(attrs, :weight)
    }
  end
end

defimpl Europa.Server.Loot.Item, for: Europa.Server.Loot.Implant do
  use Gettext, backend: Europa.Gettext

  alias Europa.Server.Loot
  alias Europa.Server.Loot.Implant
  alias Europa.Server.Errors
  alias Europa.Server.Player

  @spec item_type(Implant.t()) :: :implant
  def item_type(%Implant{}), do: :implant

  @spec negative_attrs(Implant.t()) :: list(atom())
  def negative_attrs(%Implant{}) do
    []
  end

  @spec composed_name(Implant.t()) :: String.t()
  def composed_name(%Implant{} = implant) do
    properties =
      if significant_properties(implant.properties) |> Enum.empty?() do
        " "
      else
        [
          " (",
          properties_for_composed_name(implant.properties),
          ") "
        ]
        |> Enum.join("")
      end

    [
      implant.name,
      properties
    ]
    |> to_string()
  end

  @spec description(Implant.t()) :: String.t()
  def description(%Implant{description: description}), do: description

  @spec readable_attrs(Implant.t(), Player.t()) :: list()
  def readable_attrs(%Implant{} = implant, _player) do
    properties_attrs =
      implant.properties
      |> significant_properties()
      |> Enum.sort()
      |> Enum.map(fn {property, value} ->
        name =
          case property do
            :max_health -> gettext("Max health")
            :max_warm -> gettext("Max warm")
            :max_weight -> gettext("Max weight")
            :accuracy -> gettext("Accuracy")
            :shoot_damage -> gettext("Shoot damage")
            :shotgun_damage -> gettext("Shotgun damage")
            :melee_damage -> gettext("Melee weapon damage")
          end

        {property, name, value}
      end)

    properties_attrs ++
      [
        {:weight, gettext("Weight"), implant.weight}
      ]
  end

  @spec equip(Implant.t()) :: {:error, Errors.NotApplicableError.t()}
  def equip(%Implant{} = implant) do
    {:ok, struct!(implant, equipped: true)}
  end

  @spec unequip(Implant.t()) :: {:error, Errors.NotApplicableError.t()}
  def unequip(%Implant{} = implant) do
    {:ok, struct!(implant, equipped: false)}
  end

  @spec equipable?(Implant.t()) :: true
  def equipable?(%Implant{}), do: true

  @spec consumable?(Implant.t()) :: false
  def consumable?(%Implant{}), do: false

  @spec usable?(Implant.t()) :: false
  def usable?(%Implant{}), do: false

  @spec stackable?(Implant.t()) :: false
  def stackable?(%Implant{}), do: false

  @spec disassemblable?(Implant.t()) :: false
  def disassemblable?(%Implant{}), do: false

  @spec disassemble(Implant.t()) :: {:error, Errors.NotApplicableError.t()}
  def disassemble(%Implant{}) do
    {:error, %Errors.NotApplicableError{}}
  end

  @spec weight(Implant.t()) :: Loot.Item.weight()
  def weight(%Implant{weight: weight}) do
    weight
  end

  @spec player_stats_changes(Implant.t()) :: map()
  def player_stats_changes(%Implant{properties: properties}) do
    properties
    |> significant_properties()
    |> Enum.into(%{})
  end

  defp properties_for_composed_name(%Implant.Properties{} = properties) do
    properties
    |> significant_properties()
    |> Enum.map_join(", ", fn {property, value} ->
      case property do
        :max_health -> "H:#{value}"
        :max_warm -> "W:#{value}"
        :max_weight -> "WM:#{value}"
        :accuracy -> "A:#{value}"
        :shotgun_damage -> "SHD:#{value}"
        :shoot_damage -> "SG:#{value}"
        :melee_damage -> "MD:#{value}"
      end
    end)
  end

  defp significant_properties(%Implant.Properties{} = properties) do
    properties
    |> Map.from_struct()
    |> Enum.filter(fn {_k, value} -> value != nil end)
  end
end
