defmodule Europa.Server.Planet.Storm do
  use TypedStruct

  alias Europa.Server.Planet

  import Europa.Tools.Conf
  import Europa.Tools.Randomizer

  @level_from fetch_config!([__MODULE__, :level, :from])
  @level_to fetch_config!([__MODULE__, :level, :to])

  @temperature_from fetch_config!([__MODULE__, :temperature, :from])
  @temperature_to fetch_config!([__MODULE__, :temperature, :to])

  @duration_from fetch_config!([__MODULE__, :duration, :from])
  @duration_to fetch_config!([__MODULE__, :duration, :to])

  @intensy_possibility fetch_config!([__MODULE__, :intensy_possibility])

  typedstruct enforce: true do
    field :temperature, integer()
    field :level, pos_integer()
    field :max_level, pos_integer()
    field :duration, pos_integer()
    field :direction, Planet.direction()
  end

  @spec new() :: t()
  def new do
    %__MODULE__{
      level: 1,
      max_level: Enum.random(@level_from..@level_to),
      temperature: Enum.random(@temperature_from..@temperature_to//-1),
      duration: Enum.random(@duration_from..@duration_to),
      direction: Planet.allowed_directions() |> Enum.random()
    }
  end

  @spec tick(t()) :: {:ok, t()} | :ended
  def tick(%__MODULE__{duration: duration} = storm) when duration > 0 do
    level =
      if m_to_n?(1, @intensy_possibility) do
        min(storm.level + 1, storm.max_level)
      else
        storm.level
      end

    direction =
      if m_to_n?(1, 100) do
        Planet.allowed_directions() |> Enum.random()
      else
        storm.direction
      end

    {:ok, struct!(storm, duration: duration - 1, level: level, direction: direction)}
  end

  def tick(%__MODULE__{duration: 0, level: level} = storm) when level > 1 do
    {:ok, struct!(storm, level: level - 1)}
  end

  def tick(_) do
    :ended
  end
end
