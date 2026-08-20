defmodule Europa.Tools.NumberHelpers do
  @spec round(number(), number()) :: number()
  def round(number, precision) when is_float(number) do
    Float.round(number, precision)
  end

  def round(number, _), do: number

  @spec harmonic_mean(list(number)) :: integer()
  def harmonic_mean(numbers) do
    if Enum.any?(numbers, &(&1 == 0 or &1 == 0.0)) do
      0
    else
      count = Enum.count(numbers)

      sum =
        numbers
        |> Enum.map(&(1 / &1))
        |> Enum.sum()

      round(count / sum)
    end
  end
end
