defmodule Europa.Tools.AttrsDeterminatorTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Europa.Tools.AttrsDeterminator

  describe "determine_attrs/1" do
    test "returns predetermined value" do
      assert AttrsDeterminator.determine_attrs(%{attr: "value"}) == %{attr: "value"}
      assert AttrsDeterminator.determine_attrs(%{attr: 1}) == %{attr: 1}
    end

    test "determines nested attrs" do
      assert %{attr: "value", attr2: attr2, attr3: %{attr4: attr4, attr5: %{attr6: "value 6"}}} =
               AttrsDeterminator.determine_attrs(%{
                 attr: "value",
                 attr2: %{from: 1, to: 2},
                 attr3: %{attr4: %{from: 1, to: 2}, attr5: %{attr6: "value 6"}}
               })

      assert attr2 in 1..2
      assert attr4 in 1..2
    end

    property "returns random value from range" do
      check all(n <- StreamData.integer(2..100)) do
        assert %{attr: m} = AttrsDeterminator.determine_attrs(%{attr: %{from: 1, to: n}})
        assert m in 1..n
      end
    end

    property "returns value that depends on another attr's value" do
      assert AttrsDeterminator.determine_attrs(%{a: %{attr: :b}, b: 5}) == %{a: 5, b: 5}
      assert AttrsDeterminator.determine_attrs(%{a: %{attr: "b"}, b: 5}) == %{a: 5, b: 5}

      check all(n <- StreamData.integer(2..100)) do
        assert %{b: ^n, a: a} = AttrsDeterminator.determine_attrs(%{a: %{from: 1, to: %{attr: :b}}, b: n})
        assert a in 1..n

        assert %{b: _, a: a} = AttrsDeterminator.determine_attrs(%{a: %{from: %{attr: :b}, to: n}, b: n - 1})
        assert a in (n - 1)..n
      end
    end
  end
end
