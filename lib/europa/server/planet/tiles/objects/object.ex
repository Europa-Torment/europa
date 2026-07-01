defmodule Europa.Server.Planet.Tiles.Objects.Object do
  use TypedStruct

  alias Europa.Server.Planet
  alias Europa.Server.Planet.Tiles
  alias Europa.Server.Loot.Tool

  @type transform_requirements :: list(Tool.t()) | nil

  typedstruct do
    field :name, String.t(), enforce: true
    field :high?, boolean(), default: false
    field :warm?, boolean(), default: false
    field :radioactive?, boolean(), default: false
    field :gif_tile?, boolean(), default: false
    field :image_name, String.t(), enforce: true
    field :stand_on, Planet.tile()
    field :transforms_to_tile, Planet.tile()
    field :transform_sound_name, String.t()
    field :transform_requirements, transform_requirements()
  end

  @spec stand_on(t(), Planet.tile()) :: t()
  def stand_on(%__MODULE__{} = object, tile) do
    struct!(object, stand_on: tile)
  end

  @spec transform(t()) :: Planet.tile() | t()
  def transform(%__MODULE__{transforms_to_tile: nil} = object), do: object
  def transform(%__MODULE__{transforms_to_tile: tile_name}), do: Tiles.tile(tile_name).atom_value

  @spec set_transform_requirements(t(), transform_requirements()) :: t()
  def set_transform_requirements(%__MODULE__{} = object, required_tools) do
    struct!(object, transform_requirements: required_tools)
  end
end
