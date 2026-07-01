defmodule Europa.Server.Planet.Tiles.Tile do
  use TypedStruct

  typedstruct do
    field :atom_value, atom(), enforce: true
    field :blood_version, atom()
    field :readable_name, String.t(), enforce: true
    field :move_cost, pos_integer()
    field :movable?, boolean(), enforce: true
    field :image_name, String.t(), enforce: true
    field :gif_tile?, boolean(), default: false
    field :high?, boolean(), default: false
    field :warm?, boolean(), default: false
    field :radioactive?, boolean(), default: false
  end
end
