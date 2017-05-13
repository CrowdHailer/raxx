defmodule Cookie do

  @doc """
  Parse cookies as given in a `cookie` header.

  ## Examples

      iex> parse("key1=value1, key2=value2")
      %{"key1" => "value1", "key2" => "value2"}

      # TODO check the occasions when cookies separated by semi-colon
      iex> parse("key1=value1; key2=value2")
      %{"key1" => "value1", "key2" => "value2"}

      # `$` is invalid lead character for cooke, comment?
      # Invalid cookies are dropped
      iex> parse("$key1=value1, key2=value2; $key3=value3")
      %{"key2" => "value2"}

      # Spaces in a cookie key are invalid
      iex> parse("key space=value")
      %{}

      # Spaces in a cookie value are preserved
      iex> parse("key=value space")
      %{"key" => "value space"}

      # Other spaces are cleaned
      iex> parse("  key1=value1 , key2=value2  ")
      %{"key1" => "value1", "key2" => "value2"}

      # Empty cookie string returns no cookies
      iex> parse("")
      %{}

      iex> parse("key, =, value")
      %{}

      # Cookie value can be empty string
      iex> parse("key=")
      %{"key" => ""}

      iex> parse("key1=;;key2=")
      %{"key1" => "", "key2" => ""}
  """
  def parse(string) do
    do_decode(:binary.split(string, [";", ","], [:global]), %{})
  end

  defp do_decode([], acc),
    do: acc
  defp do_decode([h|t], acc) do
    case decode_kv(h) do
      {k, v} -> do_decode(t, Map.put(acc, k, v))
      false  -> do_decode(t, acc)
    end
  end

  defp decode_kv(""),
    do: false
  defp decode_kv(<< ?$, _ :: binary >>),
    do: false
  defp decode_kv(<< h, t :: binary >>) when h in [?\s, ?\t],
    do: decode_kv(t)
  defp decode_kv(kv),
    do: decode_key(kv, "")

  defp decode_key("", _key),
    do: false
  defp decode_key(<< ?=, _ :: binary >>, ""),
    do: false
  defp decode_key(<< ?=, t :: binary >>, key),
    do: decode_value(t, "", key, "")
  defp decode_key(<< h, _ :: binary >>, _key) when h in [?\s, ?\t, ?\r, ?\n, ?\v, ?\f],
    do: false
  defp decode_key(<< h, t :: binary >>, key),
    do: decode_key(t, << key :: binary, h >>)

  defp decode_value("", _spaces, key, value),
    do: {key, value}
  defp decode_value(<< ?\s, t :: binary >>, spaces, key, value),
    do: decode_value(t, << spaces :: binary, ?\s >>, key, value)
  defp decode_value(<< h, _ :: binary >>, _spaces, _key, _value) when h in [?\t, ?\r, ?\n, ?\v, ?\f],
    do: false
  defp decode_value(<< h, t :: binary >>, spaces, key, value),
    do: decode_value(t, "", key, << value :: binary, spaces :: binary , h >>)
end
