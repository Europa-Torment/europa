defmodule Europa.Tools.NumberHelpersTest do
  use ExUnit.Case, async: true

  alias Europa.Tools.NumberHelpers

  describe "round/2" do
    test "rounds float" do
      assert NumberHelpers.round(1.33333, 2) == 1.33
    end

    test "returns unchanged integer" do
      assert NumberHelpers.round(0, 2) == 0
      assert NumberHelpers.round(1, 2) == 1
    end
  end
end
