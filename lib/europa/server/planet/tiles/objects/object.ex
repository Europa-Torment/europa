defmodule Europa.Server.Planet.Tiles.Objects.Object do
  use TypedStruct
  use Gettext, backend: Europa.Gettext

  alias Europa.Server.Planet
  alias Europa.Server.Planet.Tiles
  alias Europa.Server.Planet.Tiles.Objects
  alias Europa.Server.Loot
  alias Europa.Server.Loot.Tool

  @type transform_confirmation_info ::
          {:required_tools, list(Tool.t())} | {:change, from_name :: String.t(), to_name :: String.t() | :delete} | nil

  defmodule Transform do
    @type transforms_to ::
            {:tile, Tiles.name()} | {:object, Objects.name()} | {:item_box, Loot.item_box_type()} | :nothing

    @type transform_requirements :: {:tools, list(Tool.t())} | :change_confirmation | nil

    @type name :: atom()

    typedstruct do
      field :name, name(), enforce: true
      field :readable_name, String.t(), enforce: true
      field :message, String.t()
      field :transforms_to, transforms_to(), enforce: true
      field :transform_sound_name, String.t(), enforce: true
      field :transform_requirements, transform_requirements()
      field :transform_cost, pos_integer()
    end

    @spec set_transform_requirements(t(), transform_requirements()) :: t()
    def set_transform_requirements(%__MODULE__{} = transform, requirements) do
      struct!(transform, transform_requirements: requirements)
    end
  end

  typedstruct do
    field :name, String.t(), enforce: true
    field :high?, boolean(), default: false
    field :warm?, boolean(), default: false
    field :radioactive?, boolean(), default: false
    field :movable?, boolean(), default: false
    field :gif_tile?, boolean(), default: false
    field :image_name, String.t(), enforce: true
    field :stand_on, Planet.tile()
    field :transforms, list(Transform.t()), default: []
  end

  @spec stand_on(t(), Planet.tile()) :: t()
  def stand_on(%__MODULE__{} = object, tile) do
    struct!(object, stand_on: tile)
  end

  @spec fetch_transform!(t(), Transform.name()) :: Transform.t()
  def fetch_transform!(%__MODULE__{} = object, transform_name) do
    %Transform{} = get_transform(object, transform_name)
  end

  @spec get_transform(t(), Transform.name()) :: Transform.t() | nil
  def get_transform(%__MODULE__{transforms: transforms}, transform_name) do
    Enum.find(transforms, fn transform -> transform.name == transform_name end)
  end

  @spec transform(t(), name :: atom()) :: Planet.tile() | t()
  def transform(%__MODULE__{transforms: []} = object, _name), do: object

  def transform(%__MODULE__{stand_on: stand_on} = object, transform_name) do
    case get_transform(object, transform_name) do
      %Transform{transforms_to: {:tile, tile_name}} -> Tiles.tile(tile_name).atom_value
      %Transform{transforms_to: {:object, object_name}} -> Objects.object(object_name)
      %Transform{transforms_to: {:item_box, item_box_name}} -> Loot.generate_item_box(item_box_name)
      %Transform{transforms_to: :nothing} -> stand_on
      _ -> object
    end
  end

  @spec transform_confirmation(t(), Transform.name()) :: transform_confirmation_info()
  def transform_confirmation(%__MODULE__{transforms: []}, _transform_name), do: nil

  def transform_confirmation(%__MODULE__{} = object, transform_name) do
    case get_transform(object, transform_name) do
      %Transform{transform_requirements: {:tools, tools}} ->
        {:required_tools, tools}

      %Transform{transform_requirements: :change_confirmation, transforms_to: transforms_to} ->
        change_confirmation(object, transforms_to)

      _ ->
        nil
    end
  end

  def transform_confirmation(_, _), do: nil

  defp change_confirmation(%__MODULE__{} = object, transforms_to) do
    transforms_to_name =
      case transforms_to do
        :nothing -> :delete
        {:tile, tile_name} -> Tiles.tile(tile_name).readable_name
        {:object, object_name} -> Objects.object(object_name).name
        {:item_box, item_box_name} -> Loot.generate_item_box(item_box_name).readable_name
      end

    {:change, object.name, transforms_to_name}
  end

  @spec add_transform(t(), Transform.t()) :: t()
  def add_transform(%__MODULE__{} = object, %Transform{} = transform) do
    struct!(object, transforms: object.transforms ++ [transform])
  end
end
