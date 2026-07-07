defmodule Europa.Server.Planet.Tiles.Objects.Object do
  use TypedStruct
  use Gettext, backend: Europa.Gettext

  alias Europa.Server.Planet
  alias Europa.Server.Planet.Tiles
  alias Europa.Server.Planet.Tiles.Objects
  alias Europa.Server.Loot.Tool

  @type transform_requirements :: {:tools, list(Tool.t())} | :change_confirmation | nil
  @type transform_confirmation_info ::
          {:required_tools, list(Tool.t())} | {:change, from_name :: String.t(), to_name :: String.t() | :delete} | nil

  @type transforms_to :: {:tile, Tiles.name()} | {:object, Objects.name()} | :nothing

  typedstruct do
    field :name, String.t(), enforce: true
    field :high?, boolean(), default: false
    field :warm?, boolean(), default: false
    field :radioactive?, boolean(), default: false
    field :movable?, boolean(), default: false
    field :gif_tile?, boolean(), default: false
    field :image_name, String.t(), enforce: true
    field :stand_on, Planet.tile()
    field :transforms_to, transforms_to()
    field :transform_sound_name, String.t()
    field :transform_requirements, transform_requirements()
  end

  @spec stand_on(t(), Planet.tile()) :: t()
  def stand_on(%__MODULE__{} = object, tile) do
    struct!(object, stand_on: tile)
  end

  @spec transform(t()) :: Planet.tile() | t()
  def transform(%__MODULE__{transforms_to: nil} = object), do: object
  def transform(%__MODULE__{transforms_to: {:tile, tile_name}}), do: Tiles.tile(tile_name).atom_value
  def transform(%__MODULE__{transforms_to: {:object, object_name}}), do: Objects.object(object_name)
  def transform(%__MODULE__{transforms_to: :nothing, stand_on: stand_on}), do: stand_on

  @spec transform_confirmation(t()) :: transform_confirmation_info()
  def transform_confirmation(%__MODULE__{transform_requirements: {:tools, tools}}), do: {:required_tools, tools}

  def transform_confirmation(
        %__MODULE__{transform_requirements: :change_confirmation, transforms_to: transforms_to} = object
      )
      when not is_nil(transforms_to) do
    transforms_to_name =
      case transforms_to do
        :nothing -> :delete
        {:tile, tile_name} -> Tiles.tile(tile_name).readable_name
        {:object, object_name} -> Objects.object(object_name).name
      end

    {:change, object.name, transforms_to_name}
  end

  def transform_confirmation(_), do: nil

  @spec set_transform_requirements(t(), transform_requirements()) :: t()
  def set_transform_requirements(%__MODULE__{} = object, requirements) do
    struct!(object, transform_requirements: requirements)
  end
end
