defmodule Raxx.Layout do
  @moduledoc false

  defmacro __using__(options) do
    :elixir_errors.warn(__ENV__.line, __ENV__.file, """
    The module `#{inspect(__MODULE__)}` is deprecated use `Raxx.View.Layout` instead.
    """)

    quote do
      use Raxx.View.Layout, unquote(options)
    end
  end
end
