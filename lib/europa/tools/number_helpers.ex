defmodule Europa.Tools.NumberHelpers do
  @spec round(number(), number()) :: number()
  def round(number, precision) when is_float(number) do
    Float.round(number, precision)
  end

  def round(number, _), do: number
end
