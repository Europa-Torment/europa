defmodule Europa.Server.Planet.Region do
  use TypedStruct

  alias Europa.Server.Planet
  alias Europa.Server.Loot

  typedstruct do
    field :water_tile, Planet.tile()
    field :ice_tile, Planet.tile()
    field :snow_tile, Planet.tile()
    field :not_spawnable?, boolean(), default: false
    field :noise_threshold, number()
    field :enemy_generate_possibility, pos_integer()
    field :predefined_possibility, pos_integer()
    field :specific_item_boxes, list(Loot.item_box_type()), default: []
  end
end
