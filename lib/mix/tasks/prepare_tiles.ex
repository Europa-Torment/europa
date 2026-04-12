defmodule Mix.Tasks.PrepareTiles do
  # coveralls-ignore-start
  @moduledoc "Tile images generator"
  use Mix.Task

  @shortdoc "Calls generator"
  def run(_) do
    Europa.Tools.TilesImagesGenerator.generate_tiles!()
  end
  # coveralls-ignore-stop
end
