defmodule Europa.Server.Player.Buff do
  use TypedStruct

  typedstruct enforce: true do
    field :stat_name, atom()
    field :value, integer()
    field :duration, non_neg_integer()
  end

  @spec from_map(map()) :: t()
  def from_map(attrs) do
    %__MODULE__{
      stat_name: Map.fetch!(attrs, :stat_name) |> String.to_atom(),
      value: Map.fetch!(attrs, :value) |> integer!(),
      duration: Map.fetch!(attrs, :duration) |> pos_integer!()
    }
  end

  @spec decrease_duration(t()) :: t()
  def decrease_duration(%__MODULE__{} = buff) do
    struct!(buff, duration: max(buff.duration - 1, 0))
  end

  defp integer!(value) when is_integer(value), do: value

  defp integer!(value) do
    raise "expected integer, got: #{inspect(value)}"
  end

  defp pos_integer!(value) when is_integer(value) and value > 0, do: value

  defp pos_integer!(value) do
    raise "expected pos_integer, got: #{inspect(value)}"
  end
end
