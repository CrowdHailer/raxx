defmodule Raxx.Layout do
  defmacro __using__(options) do
    {options, []} = Module.eval_quoted(__CALLER__, options)
    {imports, options} = Keyword.pop_first(options, :imports)

    imports =
      case imports do
        nil ->
          [__CALLER__.module]

        false ->
          []

        imports when is_list(imports) ->
          imports
      end

    {layout_template, remaining_options} =
      Keyword.pop_first(options, :layout, Raxx.View.template_for(__CALLER__.file))

    if remaining_options != [] do
      keys =
        Keyword.keys(remaining_options)
        |> Enum.map(&inspect/1)
        |> Enum.join(", ")

      raise ArgumentError, "Unexpected options for #{inspect(unquote(__MODULE__))}: [#{keys}]"
    end

    layout_template = Path.expand(layout_template, Path.dirname(__CALLER__.file))

    quote do
      defmacro __using__(options) do
        imports = unquote(imports)
        layout_template = unquote(layout_template)

        imports =
          for i <- imports do
            quote do
              import unquote(i)
            end
          end

        quote do
          unquote(imports)
          use Raxx.View, Keyword.merge([layout: unquote(layout_template)], unquote(options))
        end
      end
    end
  end
end
