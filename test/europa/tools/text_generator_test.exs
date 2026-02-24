defmodule Europa.Tools.TextGeneratorTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Europa.Tools.TextGenerator

  describe "generate_text/2" do
    @tag slow: true
    property "returns random text (ititial_story)" do
      check all(m <- StreamData.integer(1..100)) do
        num_runs = 100
        generator = list_of(constant(:ok), min_length: num_runs, max_length: num_runs)

        check all(_ <- generator) do
          results = Enum.map(1..num_runs, fn _n -> TextGenerator.generate_text(:initial_story, year: m) end)

          first_intro_count =
            Enum.count(results, fn text ->
              [intro, _] = String.split(text, "\n")
              intro == "Now is #{m} year"
            end)

          second_who_are_you_count =
            Enum.count(results, fn text ->
              [_, who_are_you] = String.split(text, "\n")
              who_are_you == "second"
            end)

          first_intro_proportion = first_intro_count / num_runs
          second_who_are_you_proportion = second_who_are_you_count / num_runs

          assert first_intro_proportion >= 0.1
          assert second_who_are_you_proportion >= 0.1
        end
      end
    end
  end
end
