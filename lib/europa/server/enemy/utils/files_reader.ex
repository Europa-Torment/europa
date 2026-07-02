defmodule Europa.Server.Enemy.Utils.FilesReader do
  @templates_path "/enemies/"
  @filename "enemies.json"

  @spec parse_file() :: list({attrs :: map(), random_weight :: number()})
  def parse_file do
    priv_dir = :code.priv_dir(:europa)
    path = Path.join([priv_dir, @templates_path, @filename])

    path
    |> File.read!()
    |> Jason.decode!(keys: :atoms)
    |> Enum.map(fn attrs -> {attrs, attrs.random_weight} end)
  end
end
