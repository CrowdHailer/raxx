defmodule EEx.HTMLEngine do
  @moduledoc """
  An engine for templating HTML content.

  Interpolated values are HTML escaped,
  unless the term implements the `EEx.HTML.Safe` protocol.

  Values returned are `io_lists` for performance reasons.

  ## Examples

      iex> EEx.eval_string("foo <%= bar %>", [bar: "baz"], engine: EEx.HTMLEngine)
      ...> |> IO.iodata_to_binary()
      "foo baz"

      iex> EEx.eval_string("foo <%= bar %>", [bar: "<script>"], engine: EEx.HTMLEngine)
      ...> |> IO.iodata_to_binary()
      "foo &lt;script&gt;"

      iex> EEx.eval_string("foo <%= bar %>", [bar: EEx.HTML.raw("<script>")], engine: EEx.HTMLEngine)
      ...> |> IO.iodata_to_binary()
      "foo <script>"

      iex> EEx.eval_string("foo <%= @bar %>", [assigns: %{bar: "<script>"}], engine: EEx.HTMLEngine)
      ...> |> IO.iodata_to_binary()
      "foo &lt;script&gt;"
  """
  use EEx.Engine

  def init(_options) do
    quote do: []
  end

  def handle_begin(_previous) do
    quote do: []
  end

  def handle_end(quoted) do
    quoted
  end

  def handle_text(buffer, text) do
    quote do
      [unquote(buffer) | unquote(text)]
    end
  end

  def handle_body(quoted) do
    quoted
  end

  def handle_expr(buffer, "=", expr) do
    expr = Macro.prewalk(expr, &EEx.Engine.handle_assign/1)

    quote do
      [unquote(buffer), EEx.HTML.escape(unquote(expr)).data]
    end
  end

  def handle_expr(buffer, "", expr) do
    expr = Macro.prewalk(expr, &EEx.Engine.handle_assign/1)

    quote do
      tmp2 = unquote(buffer)
      unquote(expr)
      tmp2
    end
  end

  def handle_expr(buffer, type, expr) do
    super(buffer, type, expr)
  end
end
