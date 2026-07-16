defmodule Europa.Server.Compass do
  use TypedStruct

  alias Europa.Server.Planet

  import Europa.Tools.Conf

  @max_targets fetch_config!([__MODULE__, :max_targets])

  defmodule Target do
    alias Europa.Server.Compass

    import Europa.Tools.Conf

    @type uuid :: Ecto.UUID.t()
    @type description :: String.t()

    @max_description_length fetch_config!([Compass, :max_description_length])

    typedstruct enforce: true do
      field :uuid, uuid()
      field :coord, Planet.coord()
      field :description, description()
    end

    @spec new(Planet.coord(), description()) :: t()
    def new({x, y} = coord, description) when is_integer(x) and is_integer(y) and is_binary(description) do
      description =
        if String.length(description) > @max_description_length do
          String.slice(description, 0..(@max_description_length - 1)) <> "..."
        else
          description
        end

      %__MODULE__{
        uuid: Ecto.UUID.generate(),
        coord: coord,
        description: description
      }
    end
  end

  typedstruct do
    field :current_target, Target.t()
    field :targets, list(Target.t()), enforce: true, default: []
  end

  @spec new() :: t()
  def new do
    %__MODULE__{
      current_target: nil,
      targets: []
    }
  end

  @spec add_target(t(), Target.t()) :: {:ok, t()} | {:error, {:imit_reached, pos_integer()}}
  def add_target(%__MODULE__{} = compass, %Target{} = target) do
    if Enum.count(compass.targets) >= @max_targets do
      {:error, {:limit_reached, @max_targets}}
    else
      {:ok, struct!(compass, targets: [target | compass.targets])}
    end
  end

  @spec follow_target(t(), Target.uuid()) :: {:ok, t()} | {:error, :not_found}
  def follow_target(%__MODULE__{current_target: %Target{uuid: uuid}} = compass, target_uuid) when uuid == target_uuid do
    {:ok, compass}
  end

  def follow_target(%__MODULE__{} = compass, uuid) do
    with {:ok, %Target{} = target} <- find_target(compass, uuid) do
      {:ok, do_follow_target(compass, target)}
    end
  end

  @spec unfollow_target(t()) :: t()
  def unfollow_target(%__MODULE__{current_target: nil} = compass), do: compass

  def unfollow_target(%__MODULE__{current_target: current_target, targets: targets} = compass) do
    struct!(compass, current_target: nil, targets: [current_target | targets])
  end

  @spec delete_target(t(), Target.uuid()) :: {:ok, t()} | {:error, :not_found}
  def delete_target(%__MODULE__{current_target: %Target{uuid: uuid}} = compass, target_uuid) when uuid == target_uuid do
    {:ok, struct!(compass, current_target: nil)}
  end

  def delete_target(%__MODULE__{} = compass, uuid) do
    with {:ok, %Target{} = target} <- find_target(compass, uuid) do
      {:ok, do_delete_target(compass, target)}
    end
  end

  defp do_follow_target(%__MODULE__{current_target: nil} = compass, %Target{} = target) do
    compass
    |> do_delete_target(target)
    |> struct!(current_target: target)
  end

  defp do_follow_target(%__MODULE__{current_target: current_target} = compass, %Target{} = target) do
    {:ok, compass} =
      compass
      |> do_delete_target(target)
      |> struct!(current_target: target)
      |> add_target(current_target)

    compass
  end

  defp do_delete_target(%__MODULE__{} = compass, %Target{} = target) do
    updated_targets = List.delete(compass.targets, target)
    struct!(compass, targets: updated_targets)
  end

  defp find_target(%__MODULE__{targets: targets}, uuid) do
    case Enum.find(targets, fn target -> target.uuid == uuid end) do
      nil -> {:error, :not_found}
      target -> {:ok, target}
    end
  end
end
