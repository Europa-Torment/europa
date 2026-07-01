defmodule Europa.Server.Planet.Region do
  use TypedStruct

  alias Europa.Server.Planet

  typedstruct enforce: true do
    field :water_tile, Planet.tile()
  end
end
