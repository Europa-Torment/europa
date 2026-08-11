defmodule Europa.Server.Player.Diseases.Utils.FilesReader do
  @templates_path "/player/"

  @spec parse_file(filename :: String.t()) :: list(map())
  def parse_file(filename) do
    priv_dir = :code.priv_dir(:europa)
    path = Path.join([priv_dir, @templates_path, filename])

    path
    |> File.read!()
    |> Jason.decode!(keys: :atoms)
  end
end
