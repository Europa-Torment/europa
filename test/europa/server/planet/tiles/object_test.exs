defmodule Europa.Server.Planet.Tiles.ObjectTest do
  use Europa.DataCase

  alias Europa.Server.Planet.Tiles
  alias Europa.Server.Planet.Tiles.Object

  @snow Tiles.tile(:snow).atom_value

  describe "stand_on/2" do
    setup do
      object = build(:object, stand_on: nil)
      {:ok, object: object}
    end

    test "changes stand_on", %{object: object} do
      assert %Object{stand_on: @snow} = Object.stand_on(object, @snow)
    end
  end
end
