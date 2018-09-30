defmodule Macroware do
  defmacro __using__(_) do
    quote do
      defoverridable call: 1

      def call(value) do
        super(value + 1)
      end
    end
  end
end

defmodule MacroServer do
  def call(i) do
    i
  end

  for _ <- 1..1000 do
    use Macroware
  end
end

1000 = MacroServer.call(0)

defmodule Middleware do
  def call(value, [next | rest]) do
    next.call(value + 1, rest)
  end
end

defmodule Server do
  def call(value, []) do
    value
  end
end

stack = for(_ <- 1..999, do: Middleware) ++ [Server]
1000 = Middleware.call(0, stack)

Benchee.run(%{
  "macro" => fn -> MacroServer.call(0) end,
  "stack" => fn -> Middleware.call(0, stack) end
})
