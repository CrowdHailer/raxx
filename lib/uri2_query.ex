defmodule URI2.Query do
  @moduledoc """
  Utilities for working with url query strings.

  Namespaced under `URI2` as it is a replacement for the native `URI` module.
  Calls the original module until the query API is finalised.

  All functions are pure,
  They return try tuples when there is a possibility of failure

  """

  @doc """
  Returns the query as a list of keyvalue pairs.

  This parsing looses no information

  ## Examples

      iex> URI2.Query.parse("foo=1&bar=2")
      {:ok, [{"foo", "1"}, {"bar", "2"}]}

      iex> URI2.Query.parse("%ZZ")
      {:error, :invalid_query}


  *Directly using `URI.decode_next_query_pair/1` is not possible as it is private*
  """
  def parse(query_string) when is_binary(query_string) do
    try do
      {:ok, URI.query_decoder(query_string) |> Enum.to_list()}
    rescue
      error in ArgumentError ->
        {:error, :invalid_query}
    end
  end

  @doc """

  ## Examples

  iex> URI2.Query.build_nested([{"foo", "1"}, {"bar", "2"}])
  {:ok, %{"foo" => "1", "bar" => "2"}}

  iex> URI2.Query.build_nested([{"foo[]", "1"}, {"foo[]", "2"}])
  {:ok, %{"foo" => ["1", "2"]}}

  iex> URI2.Query.build_nested([{"foo[bar]", "1"}, {"foo[baz]", "2"}])
  {:ok, %{"foo" => %{"bar" => "1"}}}
  """
  def build_nested(key_value_pairs, nested \\ %{})
  def build_nested([], nested) do
    {:ok, nested}
  end
  def build_nested([{key, value} | rest], nested) do
    case :binary.split(key, "[") do
      [key] ->
        {:ok, nested} = put_single_value(nested, key, value)
        build_nested(rest, nested)
      [key, "]"] ->
        {:ok, nested} = put_array_entry(nested, key, value)
        build_nested(rest, nested)
      [key, rest] ->
        case :binary.split(rest, "]") do
          [subkey, ""] ->
            {:ok, nested} = put_sub_query(nested, key, [{subkey, value}])
        end
    end
  end

  defp put_sub_query(map, key, key_value_pairs) do
    case Map.get(map, key, %{}) do
      subquery = %{} ->
        {:ok, subquery} = build_nested(key_value_pairs, subquery)
        {:ok, Map.put(map, key, subquery)}
    end
  end

  defp put_single_value(map, key, value) do
    case Map.has_key?(map, key) do
      false ->
        {:ok, Map.put_new(map, key, value)}
    end
  end

  defp put_array_entry(map, key, value) do
    case Map.get(map, key, []) do
      values when is_list(values) ->
        {:ok, Map.put(map, key, values ++ [value])}
    end
  end
end
