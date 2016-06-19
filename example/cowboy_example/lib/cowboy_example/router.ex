defmodule CowboyExample.Router do
  import Raxx.Response

  def call(%{path: [], method: "GET"}, _opts) do
    "Home page"
  end

  # TODO move to stats controller.
  def call(%{
    host: host,
    port: port,
    method: method,
    path: path = ["stats" | rest],
    query: query,
    headers: headers,
    }, _opts) do
    """
    <p>
      All the request information
    </p>
    <table>
      <tr>
        <td>host</td><td>#{host}</td>
      </tr>
      <tr>
        <td>port</td><td>#{port}</td>
      </tr>
      <tr>
        <td>method</td><td>#{method}</td>
      </tr>
      <tr>
        <td>path</td><td>#{path}</td>
      </tr>
      <tr>
        <td>query</td><td>#{(quote do: unquote(query)) |> Macro.to_string}</td>
      </tr>
      <tr>
        <td>headers</td><td>#{as_string(headers)}</td>
      </tr>
    </table>
    """
  end

  def as_string(term) do
    (quote do: unquote(term)) |> Macro.to_string
  end

  def call(_request, _opts) do
    not_found("Page not found")
  end
end
