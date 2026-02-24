defmodule Europa.Tools.Randomizer do
  @spec random_number(pos_integer()) :: pos_integer()
  def random_number(max) do
    :rand.uniform(max)
  end

  @spec m_to_n(pos_integer(), pos_integer()) :: pos_integer()
  def m_to_n(m, n) when is_integer(m) and is_integer(n) and m < n do
    Enum.random(m..n)
  end

  def m_to_n(m, n) when is_integer(m) and is_integer(n) and m == n do
    m
  end

  @spec m_to_n?(pos_integer(), pos_integer()) :: boolean()
  def m_to_n?(m, n) when is_integer(m) and is_integer(n) and m < n and m > 0 and n > 0 do
    number = :rand.uniform(n)

    if m == 1 do
      number == 1
    else
      number in 1..m
    end
  end

  def m_to_n?(m, n) when is_integer(m) and is_integer(n) and m > 0 and n > 0 and m >= n do
    true
  end
end
