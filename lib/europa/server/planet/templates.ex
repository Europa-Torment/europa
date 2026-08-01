defmodule Europa.Server.Planet.Templates do
  @moduledoc """
  Template generator for predefined planet areas.

  The template files are located in `/priv/planet`.

  Template format:

  ```
  {
    "name": "Template name",
    "with_borders": true,
    "default_stand_on_tile": "snow",
    "random_weight": 1.0,
    "modificators": [
      {
        "name": "broken",
        "possibility": {"from": 1, "to": 5}
      }
    ],
    "content": [
      [
        {"type": "object", "name": "wall_left_up", "or": [{"type": "object", "name": "broken_wall", "when": {"modificators": ["broken"], "possibility": {"from": 1, "to": 3}}}]}
      ],
      [
        {"type": "loot", "name": "furniture", "stand_on": {"type": "tile", "name": "floor"}},
        {"type": "enemy", "or": [{"type": "npc", "when": {"possibility": {"from": 1, "to": 10}}}, {"type": "object", "name": "fire_vehicle", "when": {"possibility": {"from": 1, "to": 5}}}, {"type": "loot", "name": "bag", "when": {"possibility": {"from": 1, "to": 5}}}]}

      ]
    ]
  }
  ```

  Where:

  `modificators` - global modifiers for the entire template. Useful for creating complete variations of a template, such as a burning house.

  `possibility` {"from": 1, "to": 5}` - probability of application (in this case 1 in 5).

  `with_borders` - the need to add a border of empty objects around the template. This is necessary to prevent the templates from being inserted too close to each other.

  `default_stand_on_tile` - default stand_on tile (for units without explicitly specifying)

  `content` - content of the template. A list of lists, where each nested list represents a row (x coordinate) of the template. Each element of the nested list represents a separate game tile (in this module this is called as "unit").

  `random_weight` - probability of template selection.

  Possible units:

  * `{"type": "object", "name": "object_name"}` - represents `%Europa.Server.Planet.Tiles.Objects.Object{}` object with given name.
  * `{"type": "tile", "name": "tile_name"}` - represents `%Europa.Server.Planet.Tiles.Tile{}` tile with given name.
  * `{"type": "loot", "name": "item_box_name"}` - represents `%Europa.Server.Loot.ItemBox{}` item box with given name (type).
  * `{"type": "enemy"}` - represents `%Europa.Server.Enemy{}` enemy.
  * `{"type": "npc"}` - represents `%Europa.Server.Npc{}` NPC.

  Each unit (except `tile`) supports `stand_on` field:

  ```
  {"type": "loot", "name": "furniture", "stand_on": {"type": "tile", "name": "floor"}},
  ```

  Which is describes where given `unit` stands on, with any other unit as value.
  Please verify templates in templates editor from admin panel, which is allows you to check that all your `unit+stand_on_unit+...` combinations are exists and there is image for this combination.
  Nesting on several levels is possible, for example: an enemy stands on the corpse of a monster that stands in the snow.

  Any `unit` can be changed to any other `unit` described in `or` field:

  ```
  {"type": "object", "name": "wall_left_up", "or": [{"type": "object", "name": "broken_wall", "when": {"modificators": ["broken"], "possibility": {"from": 1, "to": 3}}}]}
  ```

  `or` field is a list of units with described `when` field which is sets conditions to change original `unit` to this one.

  In this case: original unit `"wall_left_up"` can be changed to unit `"broken_wall"` when two conditions are met:

  1. There is modificator called `"broken"` in template.
  2. Possibility 1 in 3 is met.

  If any of conditions is not met, then origial `unit` will be used.

  Note that `or` is a list of `units`, that means that there are multiple possible changes for given `unit`.
  Checks are performed in turn for each possible `unit`; if the conditions of the first are not met, then the conditions of the second are checked, and so on.

  It is possible to have only one condition:

  ```
  "when": {"modificators": ["broken"]}
  ```

  or

  ```
  "when": {"possibility": {"from": 1, "to": 3}}
  ```

  Please look at `/priv/planet` folder to get examples of exists game templates.
  """
  use TypedStruct

  alias Europa.Server.Planet
  alias Europa.Server.Planet.Tiles
  alias Europa.Server.Planet.Tiles.Objects
  alias Europa.Server.Planet.Templates.Utils.FilesReader
  alias Europa.Tools.Types

  import Europa.Tools.Conf
  import Europa.Tools.Randomizer

  @templates_path fetch_config!([__MODULE__, :templates_path])

  @categories %{
    building: %{dir: "/buildings", weight: 1.0},
    situation: %{dir: "/situations", weight: 0.3}
  }

  @templates FilesReader.parse_files(@templates_path, @categories)

  @type category() :: unquote(@categories |> Map.keys() |> Types.one_of())
  @type subcategory() :: String.t()

  @type npc :: {:npc, Tiles.Tile.t() | nil}
  @type template() :: list(list(Planet.tile() | npc()))

  @skip Objects.object(:skip)

  defmodule Template do
    alias Europa.Server.Planet.Templates.Template.Possibility
    alias Europa.Server.Planet.Tiles.Objects
    alias Europa.Server.Planet.Tiles
    alias Europa.Server.Planet.Tiles.Objects.Object
    alias Europa.Server.Loot
    alias Europa.Server.Enemy
    alias Europa.Server.Planet

    import Europa.Tools.Randomizer

    typedstruct module: Possibility, enforce: true do
      field :from, pos_integer()
      field :to, pos_integer()
    end

    defmodule Modificator do
      @type name() :: String.t()

      typedstruct enforce: true do
        field :name, name()
        field :possibility, Possibility.t()
      end

      @spec from_map(map()) :: t()
      def from_map(%{name: name, possibility: %{from: from, to: to}})
          when is_binary(name) and is_integer(from) and is_integer(to) and from <= to do
        %__MODULE__{
          name: name,
          possibility: %Possibility{from: from, to: to}
        }
      end

      def from_map(raw_modificator), do: raise("invalid modificator: #{inspect(raw_modificator)}")
    end

    defmodule Unit do
      alias Europa.Tools.Types
      alias Europa.Server.Planet.Tiles
      alias Europa.Server.Planet.Tiles.Objects
      alias Europa.Server.Loot

      @allowed_types [:object, :tile, :loot, :npc, :enemy]

      @type unit_type() :: unquote(Types.one_of(@allowed_types))

      defmodule Condition do
        typedstruct do
          field :modificators, list(Modificator.name())
          field :possibility, Possibility.t()
        end

        @spec from_map(map()) :: t()
        def from_map(raw_condition) when is_map(raw_condition) do
          modificators = Map.get(raw_condition, :modificators) |> parse_modificators()
          possibility = Map.get(raw_condition, :possibility) |> parse_possibility()

          if modificators || possibility do
            %__MODULE__{
              modificators: modificators,
              possibility: possibility
            }
          else
            raise "empty when condition"
          end
        end

        def from_map(raw_condition) do
          raise "unexpected when condition, expected map, got: #{inspect(raw_condition)}"
        end

        defp parse_modificators([]), do: nil
        defp parse_modificators(nil), do: nil

        defp parse_modificators(modificators) when is_list(modificators) do
          if Enum.all?(modificators, &is_binary/1) do
            modificators
          else
            raise "unexpected modificators, expected list of strings, got: #{inspect(modificators)}"
          end
        end

        defp parse_modificators(modificators),
          do: raise("unexpected modificators, expected list of strings, got: #{inspect(modificators)}")

        defp parse_possibility(%{from: from, to: to}) when is_integer(from) and is_integer(to) and from <= to do
          %Possibility{from: from, to: to}
        end

        defp parse_possibility(nil), do: nil

        defp parse_possibility(possibility) do
          raise "invalid possibility #{inspect(possibility)}"
        end
      end

      typedstruct do
        field :type, unit_type(), enforce: true
        field :name, atom()
        field :stand_on, t()
        field :or, list(t()), default: []
        field :when, Condition.t()
      end

      @spec from_map(map()) :: t() | no_return()
      def from_map(raw_unit) when is_map(raw_unit) do
        type = Map.get(raw_unit, :type) |> parse_type()

        %__MODULE__{
          type: type,
          name: Map.get(raw_unit, :name) |> parse_name(type),
          stand_on: Map.get(raw_unit, :stand_on) |> parse_stand_on(),
          or: Map.get(raw_unit, :or) |> parse_or(),
          when: Map.get(raw_unit, :when) |> parse_condition()
        }
      end

      def from_map(raw_unit), do: raise("invalid unit: #{inspect(raw_unit)}")

      defp parse_type(type) when is_binary(type) do
        type = String.to_atom(type)

        if type in @allowed_types do
          type
        else
          raise "invalid unit type: #{type}, allowed only: #{inspect(@allowed_types)}"
        end
      end

      defp parse_type(type), do: raise("invalid unit type: #{inspect(type)}")

      defp parse_name(name, :tile) when is_binary(name) do
        name = String.to_atom(name)
        %Tiles.Tile{} = Tiles.tile(name)
        name
      rescue
        _ -> reraise("unexist tile #{name}", __STACKTRACE__)
      end

      defp parse_name(name, :object) when is_binary(name) do
        name = String.to_atom(name)
        %Objects.Object{} = Objects.object(name)
        name
      rescue
        _ -> reraise("unexist object #{name}", __STACKTRACE__)
      end

      defp parse_name(name, :loot) when is_binary(name) do
        name = String.to_atom(name)

        %Loot.ItemBox{} = Loot.generate_item_box(name)
        name
      rescue
        _ -> reraise("invalid loot type: #{name}", __STACKTRACE__)
      end

      defp parse_name(nil, _), do: nil

      defp parse_name(name, type) do
        raise "unit #{type} is not supports name field, given name: #{inspect(name)}"
      end

      defp parse_or([]), do: []
      defp parse_or(nil), do: []
      defp parse_or(units) when is_list(units), do: Enum.map(units, &from_map/1)

      defp parse_or(units) do
        raise "unexpected or, expected list of units, got: #{inspect(units)}"
      end

      defp parse_stand_on(nil), do: nil
      defp parse_stand_on(unit) when is_map(unit), do: from_map(unit)

      defp parse_stand_on(unit) do
        raise "unexpected stand_on unit: #{inspect(unit)}"
      end

      defp parse_condition(nil), do: nil

      defp parse_condition(raw_condition) when is_map(raw_condition) do
        Condition.from_map(raw_condition)
      end

      defp parse_condition(raw_condition) do
        raise "unexpected when condition: #{inspect(raw_condition)}"
      end
    end

    @derive Jason.Encoder
    typedstruct do
      field :name, String.t(), enforce: true
      field :modificators, list(Modificator.t()), default: []
      field :with_borders?, boolean(), default: true
      field :default_stand_on_tile, Unit.t()
      field :content, list(list(Unit.t()))
    end

    @spec from_map(map()) :: {:ok, t()} | {:error, String.t()}
    def from_map(raw_template) when is_map(raw_template) do
      template =
        %__MODULE__{
          name: Map.fetch!(raw_template, :name),
          modificators: Map.get(raw_template, :modificators) |> parse_modificators(),
          with_borders?: Map.get(raw_template, :with_borders, true),
          default_stand_on_tile: Map.get(raw_template, :default_stand_on_tile) |> parse_default_stand_on_tile(),
          content: Map.fetch!(raw_template, :content) |> parse_content()
        }

      {:ok, template}
    rescue
      error -> {:error, Exception.message(error)}
    end

    @spec determine(t()) :: Planet.land()
    def determine(%__MODULE__{} = template) do
      modificators = determine_modificators(template)

      default_stand_on_tile =
        if template.default_stand_on_tile do
          determine_unit(template.default_stand_on_tile, modificators, nil)
        else
          nil
        end

      Enum.map(template.content, fn row ->
        Enum.map(row, fn unit ->
          unit_to_planet_tile(unit, modificators, default_stand_on_tile)
        end)
      end)
    end

    defp determine_modificators(%__MODULE__{modificators: nil}), do: []

    defp determine_modificators(%__MODULE__{modificators: modificators}) do
      Enum.reduce(modificators, [], fn %Modificator{name: name, possibility: %Possibility{from: from, to: to}}, acc ->
        if m_to_n?(from, to) do
          [name | acc]
        else
          acc
        end
      end)
    end

    defp unit_to_planet_tile(%Unit{or: nil} = unit, modificators, default_stand_on_tile) do
      determine_unit(unit, modificators, default_stand_on_tile)
    end

    defp unit_to_planet_tile(%Unit{or: conditions} = unit, modificators, default_stand_on_tile) do
      other_unit = Enum.find(conditions, fn possible_unit -> conditions_met?(possible_unit, modificators) end)

      if other_unit do
        unit_to_planet_tile(other_unit, modificators, default_stand_on_tile)
      else
        determine_unit(unit, modificators, default_stand_on_tile)
      end
    end

    defp determine_unit(%Unit{type: :object, name: name, stand_on: stand_on}, modificators, default_stand_on_tile) do
      stand_on = determine_stand_on(stand_on, modificators, default_stand_on_tile)
      Objects.object(name) |> Object.stand_on(stand_on)
    end

    defp determine_unit(%Unit{type: :tile, name: name}, _, _) do
      Tiles.tile(name).atom_value
    end

    defp determine_unit(%Unit{type: :npc, stand_on: stand_on}, modificators, default_stand_on_tile) do
      stand_on = determine_stand_on(stand_on, modificators, default_stand_on_tile)
      {:npc, stand_on}
    end

    defp determine_unit(%Unit{type: :loot, name: name, stand_on: stand_on}, modificators, default_stand_on_tile) do
      stand_on = determine_stand_on(stand_on, modificators, default_stand_on_tile)
      Loot.generate_item_box(name, stand_on)
    end

    defp determine_unit(%Unit{type: :enemy, stand_on: stand_on}, modificators, default_stand_on_tile) do
      stand_on = determine_stand_on(stand_on, modificators, default_stand_on_tile)

      Enemy.generate_enemy()
      |> Enemy.stand_on(stand_on)
    end

    defp determine_stand_on(nil, _, default_stand_on_tile), do: default_stand_on_tile

    defp determine_stand_on(%Unit{} = unit, modificators, default_stand_on_tile),
      do: unit_to_planet_tile(unit, modificators, default_stand_on_tile)

    defp conditions_met?(%Unit{when: nil}, _modificators), do: true

    defp conditions_met?(
           %Unit{
             when: %Unit.Condition{modificators: required_modificators, possibility: %Possibility{from: from, to: to}}
           },
           modificators
         ) do
      m_to_n?(from, to) && modificators_met?(required_modificators, modificators)
    end

    defp conditions_met?(
           %Unit{
             when: %Unit.Condition{modificators: required_modificators, possibility: nil}
           },
           modificators
         ) do
      modificators_met?(required_modificators, modificators)
    end

    defp modificators_met?(nil, _), do: true
    defp modificators_met?(_, nil), do: true

    defp modificators_met?(required_modificators, template_modificators) do
      Enum.all?(required_modificators, &(&1 in template_modificators))
    end

    defp parse_modificators(nil), do: []

    defp parse_modificators(modificators) when is_list(modificators) do
      Enum.map(modificators, &Modificator.from_map/1)
    end

    defp parse_modificators(_), do: raise("invalid modificators")

    defp parse_default_stand_on_tile(nil), do: nil

    defp parse_default_stand_on_tile(tile_name) when is_binary(tile_name) do
      tile_name = String.to_atom(tile_name)
      %Tiles.Tile{} = Tiles.tile(tile_name)
      %Unit{type: :tile, name: tile_name}
    end

    defp parse_default_stand_on_tile(tile_name) do
      raise("Invalid default_stand_on_tile, expected string, got: #{inspect(tile_name)}")
    end

    defp parse_content([h | _t] = raw_content) when is_list(h) do
      Enum.map(raw_content, fn row ->
        Enum.map(row, fn raw_unit ->
          Unit.from_map(raw_unit)
        end)
      end)
    end

    defp parse_content(_), do: raise("invalid content")
  end

  @spec build_empty_template() :: Template.t()
  def build_empty_template do
    %Template{
      name: "New template",
      modificators: nil,
      content: [
        []
      ]
    }
  end

  @spec generate_random(list(subcategory())) :: template()
  def generate_random(subcategories \\ []) do
    @categories
    |> Enum.map(fn {category, %{weight: weight}} -> {category, weight} end)
    |> WeightedRandom.take_one()
    |> generate(subcategories)
  end

  @spec generate(category(), list(subcategory())) :: template()
  def generate(category, subcategories \\ []) do
    {:ok, template} =
      category
      |> get_templates_with_subcategories(subcategories)
      |> WeightedRandom.take_one()
      |> Template.from_map()

    template
    |> Template.determine()
    |> add_borders(template.with_borders?)
  end

  ### Private ###

  defp get_templates_with_subcategories(category_name, []) do
    category = Map.fetch!(@templates, category_name)
    Map.fetch!(category, "base_templates")
  end

  defp get_templates_with_subcategories(category_name, subcategories) do
    category = Map.fetch!(@templates, category_name)

    category
    |> Map.take(subcategories)
    |> Enum.map(fn {_, t} -> t end)
    |> List.flatten()
  end

  defp add_borders([], _), do: []
  defp add_borders(template, false), do: template

  defp add_borders(template, _) do
    max_len = template |> Enum.map(&length/1) |> Enum.max()

    padded =
      Enum.map(template, fn row ->
        diff = max_len - length(row)
        left = div(diff, 2)
        right = diff - left
        List.duplicate(@skip, left) ++ row ++ List.duplicate(@skip, right)
      end)
      |> Enum.map(fn row -> [@skip | row] ++ [@skip] end)

    border = List.duplicate(@skip, max_len + 2)
    [border | padded] ++ [border]
  end
end
