defmodule Europa.Server.Planet.Tiles.Objects do
  use Gettext, backend: Europa.Gettext

  alias Europa.Server.Planet.Tiles
  alias Europa.Server.Planet.Tiles.Objects.Object

  @objects %{
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
    door_up: %Object{
      name: gettext("door"),
      image_name: "door_horizontal",
      high?: true,
      transforms_to_tile: :open_up_door,
      transform_sound_name: "open_door"
    },
    door_down: %Object{
      name: gettext("door"),
      image_name: "door_horizontal",
      high?: true,
      transforms_to_tile: :open_down_door,
      transform_sound_name: "open_door"
    },
    door_left: %Object{
      name: gettext("door"),
      image_name: "door_left",
      high?: true,
      transforms_to_tile: :open_left_door,
      transform_sound_name: "open_door"
    },
    door_right: %Object{
      name: gettext("door"),
      image_name: "door_right",
      high?: true,
      transforms_to_tile: :open_right_door,
      transform_sound_name: "open_door"
    },
    bonefire: %Object{name: gettext("bonefire"), image_name: "bonefire", warm?: true},
    fire_shuttle: %Object{name: gettext("burning shuttle"), image_name: "fire_shuttle", gif_tile?: true, warm?: true}
  }

  @spec object(atom()) :: Object.t()
  def object(name), do: Map.fetch!(@objects, name)
end
