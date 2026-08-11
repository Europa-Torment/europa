defmodule Europa.Server.Loot.Supply do
  use TypedStruct

  alias Europa.Server
  alias Europa.Server.Loot
  alias Europa.Server.Player.Diseases
  alias Europa.Server.Player.Diseases.Disease
  alias Europa.Server.Player.Buff

  @type disease_possibility :: {Disease.id(), possibility :: pos_integer(), satisfaction :: pos_integer()}

  defmodule Properties do
    typedstruct do
      field :health, integer() | nil
      field :warm, integer() | nil
      field :hunger, integer() | nil
      field :thirst, integer() | nil
      field :radiation, integer() | nil
    end

    @spec new(map()) :: t()
    def new(attrs) when is_map(attrs) do
      %__MODULE__{
        health: Map.get(attrs, :health),
        warm: Map.get(attrs, :warm),
        hunger: Map.get(attrs, :hunger),
        thirst: Map.get(attrs, :thirst),
        radiation: Map.get(attrs, :radiation)
      }
    end
  end

  typedstruct enforce: true do
    field :id, atom()
    field :uuid, Loot.uuid()
    field :subtype, Loot.item_subtype()
    field :name, String.t()
    field :description, String.t()
    field :count, pos_integer()
    field :consume_cost, Server.move_cost()
    field :properties, Properties.t()
    field :diseases, list(disease_possibility())
    field :buffs, list(Buff.t())
    field :weight, Loot.Item.weight()
    field :sound_name, String.t()
  end

  @spec new(map()) :: t()
  def new(attrs) when is_map(attrs) do
    %__MODULE__{
      id: Map.fetch!(attrs, :id) |> String.to_atom(),
      uuid: Ecto.UUID.generate(),
      subtype: Map.fetch!(attrs, :subtype) |> String.to_atom(),
      name: Map.fetch!(attrs, :name),
      description: Map.fetch!(attrs, :description),
      count: Map.fetch!(attrs, :count),
      consume_cost: Map.fetch!(attrs, :consume_cost),
      properties: Map.fetch!(attrs, :properties) |> Properties.new(),
      diseases: Map.get(attrs, :diseases, []) |> parse_diseases(),
      buffs: Map.get(attrs, :buffs, []) |> parse_buffs(),
      weight: Map.fetch!(attrs, :weight),
      sound_name: Map.fetch!(attrs, :sound_name)
    }
  end

  defp parse_diseases(diseases) when is_list(diseases) do
    Enum.map(diseases, fn %{id: id, possibility: possibility, satisfaction: satisfaction} = disease ->
      id = String.to_atom(id)
      %Disease{} = Diseases.get_by_id(id)

      unless is_integer(possibility) && possibility > 0 && is_integer(satisfaction) && satisfaction > 0 do
        raise "invalid disease, expected pos_integer possibility and pos_integer satisfaction, got: #{inspect(disease)}"
      end

      {id, possibility, satisfaction}
    end)
  end

  defp parse_buffs(buffs) when is_list(buffs) do
    Enum.map(buffs, &Buff.from_map/1)
  end
end

defimpl Europa.Server.Loot.Item, for: Europa.Server.Loot.Supply do
  use Gettext, backend: Europa.Gettext

  alias Europa.Server.Loot
  alias Europa.Server.Loot.Supply
  alias Europa.Server.Errors
  alias Europa.Tools.NumberHelpers
  alias Europa.Server.Player
  alias Europa.Server.Player.Diseases
  alias Europa.Server.Player.Diseases.Disease

  @spec id(Supply.t()) :: atom()
  def id(%Supply{id: id}), do: id

  @spec item_type(Supply.t()) :: :supply
  def item_type(%Supply{}), do: :supply

  @spec item_subtype(Supply.t()) :: Loot.item_subtype()
  def item_subtype(%Supply{subtype: subtype}), do: subtype

  @spec negative_attrs(Supply.t()) :: list(atom())
  def negative_attrs(%Supply{}) do
    [:consume_cost]
  end

  @spec composed_name(Supply.t()) :: String.t()
  def composed_name(%Supply{} = supply) do
    properties =
      if significant_properties(supply.properties) |> Enum.empty?() do
        " "
      else
        [
          " (",
          properties_for_composed_name(supply.properties),
          ") "
        ]
        |> Enum.join("")
      end

    [
      supply.name,
      properties,
      "(#{supply.count})"
    ]
    |> to_string()
  end

  @spec description(Supply.t()) :: String.t()
  def description(%Supply{description: description}), do: description

  @spec readable_attrs(Supply.t(), Player.t()) :: list()
  def readable_attrs(%Supply{} = supply, _player) do
    significant_properties =
      significant_properties(supply.properties) |> Enum.map(fn {name, value} -> {name, value, :permanent} end)

    buffs = Enum.map(supply.buffs, &{&1.stat_name, &1.value, &1.duration})

    properties_attrs =
      (significant_properties ++ buffs)
      |> Enum.sort()
      |> Enum.map(fn {property, value, duration} ->
        name = Player.readable_stat_name(property)

        value =
          if duration == :permanent do
            value
          else
            "#{value} (" <> gettext("for %{count} moves", count: duration) <> ")"
          end

        {property, name, value}
      end)

    diseases_info =
      if Enum.empty?(supply.diseases) do
        []
      else
        disiases_names =
          Enum.map_join(supply.diseases, ", ", fn {disease_id, possibility, _} ->
            disease = Diseases.get_by_id(disease_id)
            Disease.readable_name(disease) <> " (#{possibility}%)"
          end)

        [{:diseases, gettext("May cause diseases"), disiases_names}]
      end

    diseases_satisfaction_info =
      if Enum.empty?(supply.diseases) do
        []
      else
        disiases_info =
          Enum.map_join(supply.diseases, ", ", fn {disease_id, _, satisfaction} ->
            disease = Diseases.get_by_id(disease_id)
            Disease.readable_name(disease) <> " (#{satisfaction}%)"
          end)

        [{:diseases_satisfaction, gettext("Relief of diseases"), disiases_info}]
      end

    properties_attrs ++
      diseases_info ++
      diseases_satisfaction_info ++
      [
        {:count, gettext("Count"), supply.count},
        {:consume_cost, gettext("Consume cost"), supply.consume_cost},
        {:weight, gettext("Weight"), NumberHelpers.round(supply.count * supply.weight, 2)}
      ]
  end

  @spec equip(Supply.t()) :: {:error, Errors.NotApplicableError.t()}
  def equip(%Supply{}) do
    {:error, %Errors.NotApplicableError{}}
  end

  @spec unequip(Supply.t()) :: {:error, Errors.NotApplicableError.t()}
  def unequip(%Supply{}) do
    {:error, %Errors.NotApplicableError{}}
  end

  @spec equipable?(Supply.t()) :: false
  def equipable?(%Supply{}), do: false

  @spec consumable?(Supply.t()) :: true
  def consumable?(%Supply{}), do: true

  @spec usable?(Supply.t()) :: false
  def usable?(%Supply{}), do: false

  @spec stackable?(Supply.t()) :: true
  def stackable?(%Supply{}), do: true

  @spec weight(Supply.t()) :: Loot.Item.weight()
  def weight(%Supply{weight: weight, count: count}) do
    weight * count
  end

  @spec player_stats_changes(Supply.t()) :: map()
  def player_stats_changes(%Supply{properties: properties}) do
    properties
    |> significant_properties()
    |> Enum.into(%{})
  end

  defp properties_for_composed_name(%Supply.Properties{} = properties) do
    properties
    |> significant_properties()
    |> Enum.map_join(", ", fn {property, value} ->
      case property do
        :health -> "H:#{value}"
        :warm -> "W:#{value}"
        :hunger -> "HG:#{value}"
        :thirst -> "TH:#{value}"
        :radiation -> "RD:#{value}"
      end
    end)
  end

  defp significant_properties(%Supply.Properties{} = properties) do
    properties
    |> Map.from_struct()
    |> Enum.filter(fn {_k, value} -> value != nil end)
  end
end
