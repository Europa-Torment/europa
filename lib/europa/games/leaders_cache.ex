defmodule Europa.Games.LeadersCache do
  alias Europa.Games

  import Europa.Tools.Conf

  @cache_name :games_leaders
  @cache_ttl_ms fetch_config!([__MODULE__, :ttl_ms])

  @spec child_spec(keyword()) :: Supervisor.child_spec()
  def child_spec(_args \\ []) do
    Supervisor.child_spec({Cachex, @cache_name}, id: @cache_name)
  end

  @spec put(Games.leaders_category(), Games.leaders()) :: {:ok, boolean()}
  def put(category, leaders) when is_list(leaders) do
    Cachex.put(@cache_name, category, leaders, expire: @cache_ttl_ms)
  end

  @spec get(Games.leaders_category()) :: {:ok, Games.leaders()} | :no_cache
  def get(category) do
    case Cachex.get(@cache_name, category) do
      {:ok, nil} -> :no_cache
      {:ok, leaders} -> {:ok, leaders}
    end
  end
end
