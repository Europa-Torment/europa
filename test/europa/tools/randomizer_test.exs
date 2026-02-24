defmodule Europa.Tools.RandomizerTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Europa.Tools.Randomizer

  describe "random_number/1" do
    property "returns random number from 1 to n" do
      check all(n <- StreamData.integer(1..100)) do
        assert Randomizer.random_number(n) in 1..n
      end
    end
  end

  describe "m_to_n/2" do
    property "returns random number from m to n" do
      check all(m <- StreamData.integer(1..100)) do
        n = m * 2
        assert Randomizer.m_to_n(m, n) in m..n
      end
    end
  end

  describe "m_to_n?/2" do
    property "returns true in m from n cases" do
      check all(m <- StreamData.integer(1..100)) do
        n = m * 2
        num_runs = 500
        generator = list_of(constant(:ok), min_length: num_runs, max_length: num_runs)

        check all(_ <- generator) do
          results = Enum.map(1..num_runs, fn _ -> Randomizer.m_to_n?(m, n) end)
          trues_count = Enum.count(results, fn x -> x == true end)

          trues_proportion = trues_count / num_runs

          assert trues_proportion >= 0.35
          assert trues_proportion <= 0.75
        end
      end
    end
  end
end
