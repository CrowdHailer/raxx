defmodule EEx.HTML do
  @moduledoc """
  Conveniences for generating HTML.
  """

  @doc ~S"""
  Escapes the given HTML to string.
      iex> EEx.HTML.escape("foo")
      "foo"
      iex> EEx.HTML.escape("<foo>")
      "&lt;foo&gt;"
      iex> EEx.HTML.escape("quotes: \" & \'")
      "quotes: &quot; &amp; &#39;"
  """
  @spec escape(String.t()) :: String.t()
  def escape(data) when is_binary(data) do
    IO.iodata_to_binary(to_iodata(data, 0, data, []))
  end

  @doc ~S"""
  Escapes the given HTML to iodata.
      iex> EEx.HTML.escape_to_iodata("foo")
      "foo"
      iex> EEx.HTML.escape_to_iodata("<foo>")
      [[[] | "&lt;"], "foo" | "&gt;"]
      iex> EEx.HTML.escape_to_iodata("quotes: \" & \'")
      [[[[], "quotes: " | "&quot;"], " " | "&amp;"], " " | "&#39;"]
  """
  @spec escape_to_iodata(String.t()) :: iodata
  def escape_to_iodata(data) when is_binary(data) do
    to_iodata(data, 0, data, [])
  end

  escapes = [
    {?<, "&lt;"},
    {?>, "&gt;"},
    {?&, "&amp;"},
    {?", "&quot;"},
    {?', "&#39;"}
  ]

  for {match, insert} <- escapes do
    defp to_iodata(<<unquote(match), rest::bits>>, skip, original, acc) do
      to_iodata(rest, skip + 1, original, [acc | unquote(insert)])
    end
  end

  defp to_iodata(<<_char, rest::bits>>, skip, original, acc) do
    to_iodata(rest, skip, original, acc, 1)
  end

  defp to_iodata(<<>>, _skip, _original, acc) do
    acc
  end

  for {match, insert} <- escapes do
    defp to_iodata(<<unquote(match), rest::bits>>, skip, original, acc, len) do
      part = binary_part(original, skip, len)
      to_iodata(rest, skip + len + 1, original, [acc, part | unquote(insert)])
    end
  end

  defp to_iodata(<<_char, rest::bits>>, skip, original, acc, len) do
    to_iodata(rest, skip, original, acc, len + 1)
  end

  defp to_iodata(<<>>, 0, original, _acc, _len) do
    original
  end

  defp to_iodata(<<>>, skip, original, acc, len) do
    [acc | binary_part(original, skip, len)]
  end
end
