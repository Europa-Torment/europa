defmodule Europa.Server.Characters.Utils.FilesReader do
  @templates_path "/characters/"

  @spec parse_file(filename :: String.t()) :: list(map())
  def parse_file(filename) do
    priv_dir = :code.priv_dir(:europa)
    path = Path.join([priv_dir, @templates_path, filename])

    path
    |> File.read!()
    |> Jason.decode!()
  end
end
