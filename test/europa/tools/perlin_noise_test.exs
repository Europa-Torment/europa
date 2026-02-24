defmodule Europa.Tools.PerlinNoiseTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Europa.Tools.PerlinNoise

  describe "noise/2" do
    test "returns same output fof same input" do
      x = 0.124
      y = 0.235

      assert PerlinNoise.noise(x, y) == PerlinNoise.noise(x, y)
    end

    property "returns noise numers" do
      check all(n <- StreamData.integer(1..100)) do
        x = n * 0.1
        y = x / 2

        noise = PerlinNoise.noise(x, y)

        assert noise >= -1.0 && noise <= 1.0
      end
    end
  end
end
