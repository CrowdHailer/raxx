# TODO remove this in next breaking release
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
      _error in ArgumentError ->
        {:error, :invalid_query}
    end
  end

  @doc """
  Decode a query string into a nested map of values

      iex> URI2.Query.decode("percentages[]=15&percentages[]=99+%21")
      {:ok, %{"percentages" => ["15", "99 !"]}}
  """
  def decode(query_string) when is_binary(query_string) do
    case parse(query_string) do
      {:ok, key_value_pairs} ->
        build_nested(key_value_pairs)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Use bracket notation for nested queries.

  Note this is not a formal part of the query specification.

  ## Examples

      iex> URI2.Query.build_nested([{"foo", "1"}, {"bar", "2"}])
      {:ok, %{"foo" => "1", "bar" => "2"}}

      iex> URI2.Query.build_nested([{"foo[]", "1"}, {"foo[]", "2"}])
      {:ok, %{"foo" => ["1", "2"]}}

      iex> URI2.Query.build_nested([{"foo[bar]", "1"}, {"foo[baz]", "2"}])
      {:ok, %{"foo" => %{"bar" => "1", "baz" => "2"}}}

      iex> URI2.Query.build_nested([{"foo[bar][baz]", "1"}])
      {:ok, %{"foo" => %{"bar" => %{"baz" => "1"}}}}

      iex> URI2.Query.build_nested([{"foo[bar][]", "1"}, {"foo[bar][]", "2"}])
      {:ok, %{"foo" => %{"bar" => ["1", "2"]}}}

      # I think this case does not work because it is ambiguous whether the second kv item should be added to the first list item.
      # iex> URI2.Query.build_nested([{"foo[][bar]", "1"}, {"foo[][baz]", "2"}])
      # {:ok, %{"foo" => [%{"bar" => "1"}, %{"baz" => "2"}]}}
  """
  def build_nested(key_value_pairs, nested \\ %{})

  def build_nested([], nested) do
    {:ok, nested}
  end

  def build_nested([{key, value} | key_value_pairs], nested) do
    updated =
      case :binary.split(key, "[") do
        [key] ->
          put_single_value(nested, key, value)

        [key, "]"] ->
          put_array_entry(nested, key, value)

        [key, rest] ->
          case :binary.split(rest, "]") do
            [subkey, rest] ->
              put_sub_query(nested, key, [{subkey <> rest, value}])
          end
      end

    case updated do
      {:ok, nested} ->
        build_nested(key_value_pairs, nested)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp put_sub_query(map, key, key_value_pairs) do
    case Map.get(map, key, %{}) do
      subquery = %{} ->
        {:ok, subquery} = build_nested(key_value_pairs, subquery)
        {:ok, Map.put(map, key, subquery)}

      other ->
        {:error, {:key_already_defined_as, other}}
    end
  end

  defp put_single_value(map, key, value) do
    case Map.has_key?(map, key) do
      false ->
        {:ok, Map.put_new(map, key, value)}

      true ->
        {:error, {:key_already_defined_as, Map.get(map, key)}}
    end
  end

  defp put_array_entry(map, key, value) do
    case Map.get(map, key, []) do
      values when is_list(values) ->
        {:ok, Map.put(map, key, values ++ [value])}

      other ->
        {:error, {:key_already_defined_as, other}}
    end
  end
end
