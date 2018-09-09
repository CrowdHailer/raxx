defmodule EEx.HTML do
  @moduledoc """
  Conveniences for generating HTML.

  ## Usage

  This module adds `~E` sigil for safe HTML escaped content.
  Content within an `~E` sigil should be EEx content.

  ## Examples

      iex> name = "John"
      iex> content = ~E"<h1>Hello, <%= name %></h1>"
      %EEx.HTML.Safe{data: [[[[] | "<h1>Hello, "], "John"] | "</h1>"]}
      iex> String.Chars.to_string(content)
      "<h1>Hello, John</h1>"

      iex> name = "<script>"
      iex> content = ~E"<h1>Hello, <%= name %></h1>"
      %EEx.HTML.Safe{data: [[[[] | "<h1>Hello, "], [[[] | "&lt;"], "script" | "&gt;"]] | "</h1>"]}
      iex> String.Chars.to_string(content)
      "<h1>Hello, &lt;script&gt;</h1>"
  """
  alias __MODULE__.Safe

  @doc """
  Escape the HTML content derived from the given term.

  The content is returned wrapped in an `EEx.HTML.Safe` struct so it is not reescaped by templates etc.
  """
  # Short circuit escaping the content, if already wrapped as safe.
  def escape(content = %Safe{}) do
    content
  end

  def escape(term) do
    data = Safe.to_iodata(term)
    raw(data)
  end

  @doc """
  Mark some content as safe so that it can be used in a template.
  """
  def raw(content = %Safe{}) do
    content
  end

  def raw(iodata) do
    %Safe{data: iodata}
  end

  # NOTE uppercase sigil ignores `#{}`
  @doc """
  This module adds `~E` sigil for safe HTML escaped content.
  """
  defmacro sigil_E({:<<>>, [line: line], [template]}, []) do
    ast = EEx.compile_string(template, engine: EEx.HTMLEngine, line: line + 1)

    quote do
      EEx.HTML.raw(unquote(ast))
    end
  end

  @doc ~S"""
  Escapes the given HTML to string.
      iex> EEx.HTML.escape_to_binary("foo")
      "foo"
      iex> EEx.HTML.escape_to_binary("<foo>")
      "&lt;foo&gt;"
      iex> EEx.HTML.escape_to_binary("quotes: \" & \'")
      "quotes: &quot; &amp; &#39;"
  """
  @spec escape_to_binary(String.t()) :: String.t()
  def escape_to_binary(data) when is_binary(data) do
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
