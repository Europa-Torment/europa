defmodule Europa.Tools.TypesTest do
  use ExUnit.Case, async: true

  alias Europa.Tools.Types

  describe "one_of/1" do
    test "returns union of possible tupes" do
      assert Types.one_of([:a, :b, :c]) |> Macro.to_string() == ":a | :b | :c"
    end
  end
end
