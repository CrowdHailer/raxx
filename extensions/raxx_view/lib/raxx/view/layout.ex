defmodule Raxx.View.Layout do
  @moduledoc """
  Create a general template that can be reused by views.

  Using this module will create a module that can be used as a view.
  All functions created in the layout module will be available in the layout template
  and the content template

  ## Example

  ### Creating a new layout

      # www/layout.html.eex
      <h1>My Site</h1>
      <%= __content__ %>

      # www/layout.ex
      defmodule WWW.Layout do
        use Raxx.View.Layout,
          layout: "layout.html.eex"

        def format_datetime(datetime) do
          DateTime.to_iso8601(datetime)
        end
      end

  ### Creating a view

      # www/show_user.html.eex
      <h2><%= user.username %></h2>
      <p>signed up at <%= format_datetime(user.interted_at) %></p>

      # www/show_user.ex
      defmodule WWW.ShowUser do
        use Raxx.SimpleServer
        use WWW.Layout,
          template: "show_user.html.eex",
          arguments: [:user]

        @impl Raxx.Server
        def handle_request(_request, _state) do
          user = # fetch user somehow

          response(:ok)
          |> render(user)
        end
      end

  ## Options

  - **layout (optional):** The eex file containing the layout template.
    If not given the template file will be generated from the file of the calling module.
    i.e. `path/to/file.ex` -> `path/to/file.html.eex`

  - **imports (optional):** A list of modules to import into the template.
    The default behaviour is to import only the layout module into each view.
    Set this option to false to import no functions.
  """
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
      import EExHTML
      import Raxx.View, only: [partial: 2, partial: 3]

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
