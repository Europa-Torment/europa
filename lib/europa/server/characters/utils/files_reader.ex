defmodule Europa.Server.Characters.Utils.FilesReader do
  @templates_path "/characters/"

  @spec parse_characters_file(filename :: String.t()) :: list(map())
  def parse_characters_file(filename) do
    priv_dir = :code.priv_dir(:europa)
    path = Path.join([priv_dir, @templates_path, filename])

    path
    |> File.read!()
    |> Jason.decode!()
  end

  @spec parse_professions_file(filename :: String.t()) :: map()
  def parse_professions_file(filename) do
    priv_dir = :code.priv_dir(:europa)
    path = Path.join([priv_dir, @templates_path, filename])

    path
    |> File.read!()
    |> Jason.decode!(keys: :atoms)
  end
end
