defmodule Europa.Tools.TextGeneratorTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Europa.Tools.TextGenerator

  describe "generate_text/2" do
    @tag slow: true
    property "returns random text (great_red_spot)" do
      check all(m <- StreamData.integer(1..20)) do
        num_runs = 20
        generator = list_of(constant(:ok), min_length: num_runs, max_length: num_runs)

        check all(_ <- generator) do
          results = Enum.map(1..num_runs, fn _n -> TextGenerator.generate_text(:great_red_spot, year: m) end)

          first_text_count =
            Enum.count(results, fn text ->
              text == "first"
            end)

          second_text_count =
            Enum.count(results, fn text ->
              text == "second"
            end)

          first_text_proportion = first_text_count / num_runs
          second_text_proportion = second_text_count / num_runs

          assert first_text_proportion >= 0.01
          assert second_text_proportion >= 0.01
        end
      end
    end
  end
end
