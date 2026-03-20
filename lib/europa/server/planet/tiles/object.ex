defmodule Europa.Server.Planet.Tiles.Object do
  use TypedStruct

  alias Europa.Server.Planet

  typedstruct do
    field :name, String.t(), enforce: true
    field :high?, boolean(), default: false
    field :warm?, boolean(), default: false
    field :image_name, String.t(), enforce: true
    field :stand_on, Planet.tile()
  end

  @spec stand_on(t(), Planet.tile()) :: t()
  def stand_on(%__MODULE__{} = object, tile) do
    struct!(object, stand_on: tile)
  end
end
