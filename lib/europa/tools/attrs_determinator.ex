defmodule Europa.Tools.AttrsDeterminator do
  import Europa.Tools.Randomizer

  @doc """
  Takes `map` of raw attrs in format:

  ```
  %{
    first_attr: {from: 1, to: 10},
    second_attr: 10,
    third_attr: "value",
    fourth_atr: {from: 2, to: {attr: "first_attr"}},
    fifth: {attr: "second_attr"}
  }
  ```
  and returns `map` with determined exact values.

  If field already has exact value (string, integer or boolean) it keeps as is.
  If field has value `{from: 1, to: 10}` then random number from range `1..10` will taken.
  If field has value `{attr: "attr_name"}` then `attr_name` field value will taken.
  """
  @spec determine_attrs(map()) :: map()
  def determine_attrs(attrs) when is_map(attrs) do
    attrs
    |> Map.to_list()
    |> do_determine_attrs(%{})
  end

  defp do_determine_attrs([], attrs) do
    attrs
  end

  defp do_determine_attrs([{attr_name, attr_params} = h | t], attrs) do
    case determine_attr(attrs, attr_params) do
      :not_yet_defined ->
        # put attr to end of list to wait until dependent attr will determined
        do_determine_attrs(t ++ [h], attrs)

      value ->
        updated_attrs = Map.put(attrs, attr_name, value)
        do_determine_attrs(t, updated_attrs)
    end
  end

  defp determine_attr(_attrs, value) when is_number(value) or is_binary(value) or is_boolean(value) do
    value
  end

  defp determine_attr(attrs, %{attr: dep_attr}) do
    case get_raw_attr(attrs, dep_attr) do
      :not_yet_defined -> :not_yet_defined
      attr -> attr
    end
  end

  defp determine_attr(_attrs, %{from: from, to: to}) when is_integer(from) and is_integer(to) do
    m_to_n(from, to)
  end

  defp determine_attr(attrs, %{from: %{attr: dep_attr_from}, to: %{attr: dep_attr_to}}) do
    case {get_raw_attr(attrs, dep_attr_from), get_raw_attr(attrs, dep_attr_to)} do
      {from, to} when from == :not_yet_defined or to == :not_yet_defined -> :not_yet_defined
      {from, to} -> m_to_n(from, to)
    end
  end

  defp determine_attr(attrs, %{from: from, to: %{attr: dep_attr}}) when is_integer(from) do
    case get_raw_attr(attrs, dep_attr) do
      :not_yet_defined -> :not_yet_defined
      attr -> m_to_n(from, attr)
    end
  end

  defp determine_attr(attrs, %{from: %{attr: dep_attr}, to: to}) when is_integer(to) do
    case get_raw_attr(attrs, dep_attr) do
      :not_yet_defined -> :not_yet_defined
      attr -> m_to_n(attr, to)
    end
  end

  # nested attrs
  defp determine_attr(_attrs, attr) when is_map(attr) do
    determine_attrs(attr)
  end

  defp get_raw_attr(attrs, attr_name) when is_binary(attr_name) do
    attr_name = String.to_atom(attr_name)
    get_raw_attr(attrs, attr_name)
  end

  defp get_raw_attr(attrs, attr_name) when is_map(attrs) and is_atom(attr_name) do
    case Map.get(attrs, attr_name) do
      nil -> :not_yet_defined
      attr -> attr
    end
  end
end
