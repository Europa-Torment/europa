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
    field :changes_to, atom()
    field :change_possibility, pos_integer()
    field :lethal?, boolean(), default: false
    field :lethal_event, atom()
    field :high_loot_possibility?, boolean(), default: false
  end
end
