defmodule Europa.Server.Planet.Region do
  use TypedStruct

  alias Europa.Server.Planet

  typedstruct do
    field :water_tile, Planet.tile()
    field :ice_tile, Planet.tile()
    field :snow_tile, Planet.tile()
    field :not_spawnable?, boolean(), default: false
  end
end
