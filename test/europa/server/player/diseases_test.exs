defmodule Europa.Server.Player.DiseasesTest do
  use Europa.DataCase, async: true

  alias Europa.Server.Player.Diseases
  alias Europa.Server.Player.Diseases.Disease

  describe "diseases/0" do
    test "reutrns list of diseases" do
      assert Diseases.diseases()
             |> Enum.all?(fn
               %Disease{} -> true
               _ -> false
             end)
    end
  end

  describe "get_by_id/1" do
    test "returns disease by given id" do
      disease = Diseases.diseases() |> List.first()
      assert Diseases.get_by_id(disease.id) == disease
    end

    test "raises when disease with diven id is not exists" do
      assert_raise RuntimeError, fn ->
        Diseases.get_by_id(:fake)
      end
    end
  end
end
