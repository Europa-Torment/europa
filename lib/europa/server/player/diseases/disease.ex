defmodule Europa.Server.Player.Diseases.Disease do
  use TypedStruct
  use Gettext, backend: Europa.Gettext

  @type id :: atom()

  defmodule Debuffs do
    @player_stats_attrs [:efficiency, :accuracy, :max_health, :max_warm]

    typedstruct do
      field :damage, integer()
      field :extra_moves_count, integer()
      field :efficiency, integer()
      field :accuracy, integer()
      field :max_health, integer()
      field :max_warm, integer()
    end

    @spec player_stats_attrs() :: list(atom())
    def player_stats_attrs, do: @player_stats_attrs

    @spec from_map(map()) :: t() | no_return()
    def from_map(attrs) do
      %__MODULE__{
        damage: Map.get(attrs, :damage) |> integer_or_nil!(),
        extra_moves_count: Map.get(attrs, :extra_moves_count) |> integer_or_nil!(),
        efficiency: Map.get(attrs, :efficiency) |> integer_or_nil!(),
        accuracy: Map.get(attrs, :accuracy) |> integer_or_nil!(),
        max_health: Map.get(attrs, :max_health) |> integer_or_nil!(),
        max_warm: Map.get(attrs, :max_warm) |> integer_or_nil!()
      }
    end

    defp integer_or_nil!(value) when is_integer(value) or is_nil(value), do: value

    defp integer_or_nil!(value) do
      raise "expected integer or nil, got: #{inspect(value)}"
    end
  end

  typedstruct enforce: true do
    field :id, id()
    field :name, String.t()
    field :progression_possibility, pos_integer()
    field :debuffs, Debuffs.t()
    field :satisfaction, non_neg_integer()
    field :moves_to_recovery, non_neg_integer()
  end

  @spec from_map(map()) :: t()
  def from_map(attrs) do
    %__MODULE__{
      id: Map.fetch!(attrs, :id) |> String.to_atom(),
      name: Map.fetch!(attrs, :name),
      progression_possibility: Map.fetch!(attrs, :progression_possibility) |> pos_integer!(),
      debuffs: Map.fetch!(attrs, :debuffs) |> Debuffs.from_map(),
      satisfaction: 100,
      moves_to_recovery: Map.fetch!(attrs, :moves_to_recovery) |> pos_integer!()
    }
  end

  @spec readable_name(t()) :: String.t()
  def readable_name(%__MODULE__{name: name}) do
    Gettext.gettext(Europa.Gettext, name)
  end

  @spec readable_debuffs(t()) :: list()
  def readable_debuffs(%__MODULE__{} = disease) do
    disease
    |> significant_debuffs()
    |> Enum.sort()
    |> Enum.map(fn {property, value} ->
      name =
        case property do
          :damage -> gettext("Periodically damage")
          :extra_moves_count -> gettext("Additional moves count")
          :efficiency -> gettext("Efficiency")
          :accuracy -> gettext("Accuracy")
          :max_health -> gettext("Max health")
          :max_warm -> gettext("Max warm")
        end

      {property, name, value}
    end)
  end

  @spec player_stats_changes(t()) :: map()
  def player_stats_changes(%__MODULE__{} = disease) do
    attr_names = Debuffs.player_stats_attrs()

    disease
    |> significant_debuffs()
    |> Map.take(attr_names)
  end

  @spec change_satisfaction(t(), integer()) :: t()
  def change_satisfaction(%__MODULE__{} = disease, value) when is_integer(value) do
    new_value = min(disease.satisfaction + value, 100) |> max(0)
    struct!(disease, satisfaction: new_value)
  end

  @spec increase_moves_to_recovery(t(), pos_integer()) :: t()
  def increase_moves_to_recovery(%__MODULE__{} = disease, value) when is_integer(value) and value > 0 do
    struct!(disease, moves_to_recovery: disease.moves_to_recovery + value)
  end

  @spec progress_recovery(t()) :: t()
  def progress_recovery(%__MODULE__{} = disease) do
    struct!(disease, moves_to_recovery: max(disease.moves_to_recovery - 1, 0))
  end

  defp significant_debuffs(%__MODULE__{debuffs: debuffs}) do
    debuffs
    |> Map.from_struct()
    |> Enum.filter(fn {_k, v} -> not is_nil(v) end)
    |> Enum.into(%{})
  end

  defp pos_integer!(value) when is_integer(value) and value > 0 do
    value
  end

  defp pos_integer!(value) do
    raise "expected pos_integer, got: #{inspect(value)}"
  end
end
