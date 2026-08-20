defmodule Europa.Server.Characters.ProfessionTest do
  use Europa.DataCase, async: true

  alias Europa.Server.Characters.Profession

  describe "professions/0" do
    test "returns all professions" do
      assert Profession.professions() |> Enum.any?(fn {k, v} -> is_atom(k) && profession?(v) end)
    end
  end

  describe "from_map/1" do
    test "builds profession from map" do
      raw_profession = %{
        name: "Test",
        fractions: ["wcc", "ssb"],
        properties: [
          %{id: "heal", level: 1},
          %{id: "resources_economy", level: 2},
          %{id: "accuracy", level: 3}
        ],
        not_pickable: true
      }

      expected_profession = %Profession{
        name: "Test",
        fractions: [:wcc, :ssb],
        properties: [
          %Profession.Property{id: :heal, level: 1},
          %Profession.Property{id: :resources_economy, level: 2},
          %Profession.Property{id: :accuracy, level: 3}
        ],
        not_pickable?: true
      }

      assert Profession.from_map(raw_profession) == expected_profession
    end
  end

  describe "property_description/1" do
    test "returns string" do
      for property <- Profession.Property.allowed_properties() do
        assert Profession.Property.property_description(property) |> is_binary()
      end
    end
  end

  defp profession?(%Profession{}), do: true
  defp profession?(_), do: false
end
