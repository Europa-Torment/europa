defmodule Europa.Server.Planet.Tiles.Objects do
  use Gettext, backend: Europa.Gettext

  alias Europa.Server.Planet.Tiles
  alias Europa.Server.Planet.Tiles.Objects.Object
  alias Europa.Server.Loot.Tool
  alias Europa.Tools.Types

  @objects %{
    # object used to leave space unoccupied
    skip: %Object{name: gettext(""), image_name: "", high?: false, movable?: true},
    wall_up: %Object{name: gettext("wall"), image_name: "wall_up", high?: true},
    wall_down: %Object{name: gettext("wall"), image_name: "wall_down", high?: true},
    wall_right: %Object{name: gettext("wall"), image_name: "wall_right", high?: true},
    wall_right_up: %Object{name: gettext("wall"), image_name: "wall_right_up", high?: true},
    wall_right_down: %Object{name: gettext("wall"), image_name: "wall_right_down", high?: true},
    wall_left: %Object{name: gettext("wall"), image_name: "wall_left", high?: true},
    wall_left_up: %Object{name: gettext("wall"), image_name: "wall_left_up", high?: true},
    wall_left_down: %Object{name: gettext("wall"), image_name: "wall_left_down", high?: true},
    wall_vertical_inside: %Object{
      name: gettext("wall"),
      image_name: "wall_vertical_inside",
      high?: true,
      stand_on: Tiles.tile(:floor).atom_value
    },
    broken_wall: %Object{name: gettext("broken wall"), image_name: "broken_wall", high?: false, movable?: true},
    door_up: %Object{
      name: gettext("door"),
      image_name: "door_horizontal",
      high?: true,
      transforms_to: {:tile, :open_up_door},
      transform_sound_name: "open_door"
    },
    door_down: %Object{
      name: gettext("door"),
      image_name: "door_horizontal",
      high?: true,
      transforms_to: {:tile, :open_down_door},
      transform_sound_name: "open_door"
    },
    door_left: %Object{
      name: gettext("door"),
      image_name: "door_left",
      high?: true,
      transforms_to: {:tile, :open_left_door},
      transform_sound_name: "open_door"
    },
    door_right: %Object{
      name: gettext("door"),
      image_name: "door_right",
      high?: true,
      transforms_to: {:tile, :open_right_door},
      transform_sound_name: "open_door"
    },
    bonfire: %Object{
      name: gettext("bonfire"),
      image_name: "bonfire",
      warm?: true,
      gif_tile?: true,
      transforms_to: :nothing,
      transform_requirements: :change_confirmation,
      transform_sound_name: "equip"
    },
    bonfire_base: %Object{
      name: gettext("extinguished bonfire"),
      image_name: "bonfire_base",
      warm?: false,
      transforms_to: {:object, :bonfire},
      transform_requirements: {:tools, [Tool.generate_matches()]},
      transform_sound_name: "matches"
    },
    fire_shuttle: %Object{
      name: gettext("burning shuttle"),
      image_name: "fire_shuttle",
      gif_tile?: true,
      warm?: true,
      transforms_to: {:item_box, :crashed_shuttle},
      transform_requirements: {:tools, [Tool.generate_fire_extinguisher()]},
      transform_sound_name: "fire_extinguisher"
    }
  }

  @object_names Enum.map(@objects, fn {name, _} -> name end)
  @type name :: unquote(Types.one_of(@object_names))

  @spec objects() :: %{required(name()) => Object.t()}
  def objects do
    @objects
  end

  @spec object(name()) :: Object.t()
  def object(name), do: Map.fetch!(@objects, name)
end
