defmodule Europa.Tools.Conf do
  @app_name :europa

  @spec fetch_config!([atom(), ...] | atom()) :: any()
  def fetch_config!(key) when is_atom(key) do
    fetch_config!([key])
  end

  def fetch_config!([first_key | rest_keys]) do
    @app_name
    |> Application.fetch_env!(first_key)
    |> do_fetch_config!(rest_keys)
  end

  @spec get_config(atom(), any()) :: any()
  def get_config(key, default_value \\ nil) when is_atom(key) do
    @app_name
    |> Application.get_env(key, default_value)
  end

  ### PRIVATE ###

  defp do_fetch_config!(config, []), do: config

  defp do_fetch_config!(config, [key | rest_keys]) do
    new_config = Keyword.fetch!(config, key)
    do_fetch_config!(new_config, rest_keys)
  end
end
