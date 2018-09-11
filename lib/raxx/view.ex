defmodule Raxx.View do
  @moduledoc ~S"""
  Generate views from `.eex` template files.

  Using this module will add the functions `html` and `render` to a module.

  To create layouts that can be reused across multiple pages check out `Raxx.Layout`.

  ## Example

      # greet.html.eex
      <p>Hello, <%= name %></p>

      # layout.html.eex
      <h1>Greetings</h1>
      <%= __content__ %>

      # greet.ex
      defmodule Greet do
        use Raxx.View,
          arguments: [:name],
          layout: "layout.html.eex"
      end

      # iex -S mix
      Greet.html("Alice")
      # => "<h1>Greetings</h1>\n<p>Hello, Alice</p>"

      Raxx.response(:ok)
      |> Greet.render("Bob")
      # => %Raxx.Response{
      #      status: 200,
      #      headers: [{"content-type", "text/html"}],
      #      body: "<h1>Greetings</h1>\n<p>Hello, Alice</p>"
      #    }

  ## Options

    - **arguments:** A list of atoms for variables used in the template.
      This will be the argument list for the html function.
      The render function takes one additional argument to this list,
      a response struct.

    - **template (optional):** The eex file containing a main content template.
      If not given the template file will be generated from the file of the calling module.
      i.e. `path/to/file.ex` -> `path/to/file.html.eex`

    - **layout (optional):** An eex file containing a layout template.
      This template can use all the same variables as the main template.
      In addition it must include the content using `<%= __content__ %>`

  ## Safety

  ### [XSS (Cross Site Scripting) Prevention](https://www.owasp.org/index.php/XSS_(Cross_Site_Scripting)_Prevention_Cheat_Sheet#RULE_.231_-_HTML_Escape_Before_Inserting_Untrusted_Data_into_HTML_Element_Content)

  All content interpolated into a view is escaped.

      iex> Greet.html("<script>")
      # => "<h1>Greetings</h1>\n<p>Hello, &lt;script&gt;</p>"

  Values in the template can be marked as secure using the `EEx.HTML.raw/1` function.
  *raw is automatically imported to the template scope*.

      # greet.html.eex
      <p>Hello, <%= raw name %></p>

  ### JavaScript

  >  Including untrusted data inside any other JavaScript context is quite dangerous, as it is extremely easy to switch into an execution context with characters including (but not limited to) semi-colon, equals, space, plus, and many more, so use with caution.
  [XSS Prevention Cheat Sheet](https://www.owasp.org/index.php/XSS_(Cross_Site_Scripting)_Prevention_Cheat_Sheet#RULE_.233_-_JavaScript_Escape_Before_Inserting_Untrusted_Data_into_JavaScript_Data_Values)

  **DONT DO THIS**
  ```eex
  <script type="text/javascript">
    console.log('Hello, ' + <%= name %>)
  </script>
  ```

  Use `javascript_variables/1` for injecting variables into any JavaScript environment.
  """
  defmacro __using__(options) do
    {options, []} = Module.eval_quoted(__CALLER__, options)

    {arguments, options} = Keyword.pop_first(options, :arguments, [])

    {page_template, options} =
      Keyword.pop_first(options, :template, Raxx.View.template_for(__CALLER__.file))

    page_template = Path.expand(page_template, Path.dirname(__CALLER__.file))

    {layout_template, remaining_options} = Keyword.pop_first(options, :layout)

    if remaining_options != [] do
      keys =
        Keyword.keys(remaining_options)
        |> Enum.map(&inspect/1)
        |> Enum.join(", ")

      raise ArgumentError, "Unexpected options for #{inspect(unquote(__MODULE__))}: [#{keys}]"
    end

    layout_template =
      if layout_template do
        Path.expand(layout_template, Path.dirname(__CALLER__.file))
      end

    arguments = Enum.map(arguments, fn a when is_atom(a) -> {a, [line: 1], nil} end)

    compiled_page = EEx.compile_file(page_template, engine: EEx.HTMLEngine)

    # This step would not be necessary if the compiler could return a wrapped value.
    safe_compiled_page =
      quote do
        EEx.HTML.raw(unquote(compiled_page))
      end

    compiled_layout =
      if layout_template do
        EEx.compile_file(layout_template, engine: EEx.HTMLEngine)
      else
        {:__content__, [], nil}
      end

    {compiled, has_page?} =
      Macro.prewalk(compiled_layout, false, fn
        {:__content__, _opts, nil}, _acc ->
          {safe_compiled_page, true}

        ast, acc ->
          {ast, acc}
      end)

    if !has_page? do
      raise ArgumentError, "Layout missing content, add `<%= __content__ %>` to template"
    end

    quote do
      import EEx.HTML, only: [raw: 1]
      import unquote(__MODULE__), only: [javascript_variables: 1]

      if unquote(layout_template) do
        @external_resource unquote(layout_template)
        @file unquote(layout_template)
      end

      @external_resource unquote(page_template)
      @file unquote(page_template)
      def render(request, unquote_splicing(arguments)) do
        request
        |> Raxx.set_header("content-type", "text/html")
        |> Raxx.set_body(html(unquote_splicing(arguments)).data)
      end

      def html(unquote_splicing(arguments)) do
        EEx.HTML.raw(unquote(compiled))
      end
    end
  end

  @doc false
  def template_for(file) do
    case String.split(file, ~r/\.ex(s)?$/) do
      [path_and_name, ""] ->
        path_and_name <> ".html.eex"

      _ ->
        raise "#{__MODULE__} needs to be used from a `.ex` or `.exs` file"
    end
  end

  @doc """
  Safety inject server variables into a pages JavaScript.

  ## Example

  ```eex
  <%= javascript_variables name: "Cynthia" %>
  <script type="text/javascript">
    console.log('Hello, ' + name)
  </script>
  ```
  """
  case Code.ensure_loaded(Jason) do
    {:module, _} ->
      @javascript_variables_template "<div style='display:none;'><%= encoded %></div><script>const{<%= key_string %>}=JSON.parse(document.currentScript.previousElementSibling.textContent)</script>"

      def javascript_variables(variables) do
        variables = Enum.into(variables, %{})

        # NOTE Jason does provide an ecode to iodata option, however escaping does not support that yet.
        {:ok, json} = Jason.encode(variables)
        encoded = EEx.HTML.escape(json)

        key_string =
          variables
          |> Map.keys()
          |> Enum.map(&Atom.to_string/1)
          |> Enum.join(", ")

        EEx.HTML.raw(
          unquote(EEx.compile_string(@javascript_variables_template, engine: EEx.HTMLEngine))
        )
      end

    {:error, :nofile} ->
      def javascript_variables(_variables) do
        raise "`javascript_variables/1` requires the Jason encoder, add `{:jason, \"~> 1.0.0\"}` to `mix.exs`"
      end
  end
end
