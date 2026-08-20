defmodule Europa.Server.Characters.Profession do
  use TypedStruct

  alias Europa.Server.Characters.Character
  alias Europa.Server.Characters.Utils.FilesReader
  alias Europa.Tools.Types

  @filename "professions.json"
  @raw_data FilesReader.parse_professions_file(@filename)

  @professions_id Map.keys(@raw_data)

  @type id() :: unquote(Types.one_of(@professions_id))

  for {{_k, raw_profession}, i} <- @raw_data do
    fun_name = String.to_atom("__extract_strings_for_profession_#{i}")

    def unquote(fun_name)() do
      gettext(unquote(raw_profession.name))
    end
  end

  defmodule Property do
    use Gettext, backend: Europa.Gettext

    @allowed_properties [:heal, :resources_economy, :accuracy]
    @type property :: unquote(Types.one_of(@allowed_properties))

    typedstruct enforce: true do
      field :id, property()
      field :level, pos_integer()
    end

    @spec allowed_properties :: list(property())
    def allowed_properties do
      @allowed_properties
    end

    @spec from_map(map()) :: t()
    def from_map(raw_property) do
      %__MODULE__{
        id: Map.fetch!(raw_property, :id) |> String.to_existing_atom() |> validate_id!(),
        level: Map.fetch!(raw_property, :level) |> validate_level!()
      }
    end

    @spec property_description(property()) :: String.t()
    def property_description(property_id) do
      case property_id do
        :heal -> gettext("Healing the squad")
        :resources_economy -> gettext("Reducing resource consumption")
        :accuracy -> gettext("Shooting accuracy")
      end
    end

    defp validate_id!(id) when id in @allowed_properties do
      id
    end

    defp validate_id!(id),
      do: raise("unexpecred profession property id: #{inspect(id)}, allowed: #{inspect(@allowed_properties)}")

    defp validate_level!(level) when is_integer(level) and level > 0 do
      level
    end

    defp validate_level!(level),
      do: raise("unexpected profession property level, expected pos_integer, got: #{inspect(level)}")
  end

  typedstruct enforce: true do
    field :name, String.t()
    field :fractions, list(Character.fraction())
    field :properties, list(Property.t())
    field :not_pickable?, boolean(), default: false
  end

  @spec from_map(map()) :: t()
  def from_map(raw_profession) when is_map(raw_profession) do
    %__MODULE__{
      name: Map.fetch!(raw_profession, :name),
      fractions: Map.fetch!(raw_profession, :fractions) |> Enum.map(&String.to_atom/1) |> validate_fractions!(),
      properties: Map.fetch!(raw_profession, :properties) |> Enum.map(&Property.from_map/1) |> validate_properties!(),
      not_pickable?: Map.get(raw_profession, :not_pickable, false)
    }
  end

  @spec professions() :: %{optional(id()) => t()}
  def professions do
    @raw_data
    |> Enum.map(fn {id, data} ->
      {id, from_map(data)}
    end)
    |> Enum.into(%{})
  end

  defp validate_fractions!([_ | _] = fractions) do
    fractions
  end

  defp validate_fractions!([]), do: "raise empty fractions list"

  defp validate_properties!(properteis) when is_list(properteis) do
    if Enum.uniq_by(properteis, & &1.id) == properteis do
      properteis
    else
      raise "duplicated properties: #{inspect(properteis)}"
    end
  end
end
