defmodule Europa.Games.LeadersCacheTest do
  use Europa.DataCase

  alias Europa.Games.LeadersCache

  import Europa.Tools.Conf

  @cache_ttl_ms fetch_config!([LeadersCache, :ttl_ms])
  @category :kills
  @leaders [{{"username", 1000}, 1}]

  test "puts and gets" do
    assert {:ok, true} = LeadersCache.put(@category, @leaders)
    assert {:ok, @leaders} = LeadersCache.get(@category)
  end

  test "respects ttl" do
    assert {:ok, true} = LeadersCache.put(@category, @leaders)
    assert {:ok, @leaders} = LeadersCache.get(@category)

    :timer.sleep(@cache_ttl_ms + 100)
    assert LeadersCache.get(@category) == :no_cache
  end
end
