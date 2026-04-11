defmodule Mix.Tasks.PrepareTiles do
  @moduledoc "Tile images generator"
  use Mix.Task

  @shortdoc "Calls generator"
  def run(_) do
    Europa.Tools.TilesImagesGenerator.generate_tiles!()
  end
end
