defmodule Europa.Tools.FilesCacheTest do
  use ExUnit.Case

  alias Europa.Tools.FilesCache

  @path "some/fake/path/file.json"
  @path2 "some/fake/path/file2.json"

  @file_content %{a: 1}

  test "puts and gets file content" do
    assert :ok = FilesCache.put(@path, @file_content)
    assert FilesCache.get(@path) == {:ok, @file_content}
  end

  test "returns error when file not cached" do
    assert {:error, :no_cache} = FilesCache.get(@path2)
  end
end
