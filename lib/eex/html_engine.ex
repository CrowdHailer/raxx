defmodule EEx.HTMLEngine do
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
