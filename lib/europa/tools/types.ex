defmodule Europa.Tools.Types do
  def one_of(list) when is_list(list) do
    list
    |> Enum.map_join(" | ", &inspect/1)
    |> Code.string_to_quoted!()
  end
end
