defmodule Raxx.Request do
  @moduledoc """
  HTTP requests to a Raxx application are encapsulated in a `Raxx.Request` struct.

  A request has all the properties of the url it was sent to.
  In addition it has optional content, in the body.
  As well as a variable number of headers that contain meta data.

  Where appropriate URI properties are named from this definition.

  > scheme:[//[user:password@]host[:port]][/]path[?query][#fragment]

  from [wikipedia](https://en.wikipedia.org/wiki/Uniform_Resource_Identifier#Syntax)

  The contents are itemised below:

  | **scheme** | `http` or `https`, depending on the transport used. |
  | **host** | The location of the hosting server, as a binary. e.g. `www.example.com`. |
  | **port** | The connection port on the server, as an integer. |
  | **method** | The HTTP request method, such as “GET” or “POST”, as a binary. This cannot ever be an empty string, and is always uppercase. |
  | **mount** | The segments of the request URL's “path”, that have already been matched. Same as rack path_info. This may be an empty array, if the requested URL targets the application root. |
  | **path** | The remainder of the request URL's “path”, split into segments. It designates the virtual “location” of the request's target within the application. This may be an empty array, if the requested URL targets the application root. |
  | **query** | The query parameters from the URL search string, formatted as a map of strings. |
  | **headers** | The headers from the HTTP request as a map of strings. Note all headers will be downcased, e.g. `%{"content-type" => "text/plain"}` |
  | **body** | The body content sent with the request |

  ## Examples

      iex> get("http://example.com:80/some/path?query=foo", "Hello, World!", [{"content-type", "tex/plain"}])
      %Raxx.Request{body: "Hello, World!",
          headers: [{"content-type", "tex/plain"}], host: "example.com",
          method: :GET, mount: [], path: ["some", "path"], port: 80,
          query: %{"query" => "foo"}, scheme: "http"}

  """

  @type request :: %__MODULE__{
    scheme: binary,
    host: binary,
    port: :inet.port_number,
    method: binary,
    mount: [binary],
    path: [binary],
    query: %{binary => binary},
    headers: [{binary, binary}],
    body: binary
  }

  defstruct [
    scheme: nil,
    host: nil,
    port: nil,
    method: nil,
    mount: [],
    path: [],
    query: %{},
    headers: [],
    body: nil
  ]

  @doc """
  Create a `GET` request for the given url.

  Optional content and headers can be added to the request.

  ## Examples

      iex> get("/?foo=bar").query
      %{"foo" => "bar"}

      iex> get({"/", %{foo: "bar"}}).query
      %{"foo" => "bar"}

      iex> get("/", "Hello, World!").body
      "Hello, World!"

      iex> get("/", [{"referer", "/home"}]).headers
      [{"referer", "/home"}]
  """
  def get(url, content \\ "", headers \\ []) do
    build(:GET, url, content, headers)
  end

  @doc """
  Create a `POST` request for the given url.

  See `get/3` for examples on adding content and headers
  """
  def post(url, content \\ "", headers \\ []) do
    build(:POST, url, content, headers)
  end

  @doc """
  Create a `PUT` request for the given url.

  See `get/3` for examples on adding content and headers
  """
  def put(url, content \\ "", headers \\ []) do
    build(:PUT, url, content, headers)
  end

  @doc """
  Create a `PATCH` request for the given url.

  See `get/3` for examples on adding content and headers
  """
  def patch(url, content \\ "", headers \\ []) do
    build(:PATCH, url, content, headers)
  end

  @doc """
  Create a `DELETE` request for the given url.

  See `get/3` for examples on adding content and headers
  """
  def delete(url, content \\ "", headers \\ []) do
    build(:DELETE, url, content, headers)
  end

  @doc """
  Create a `OPTIONS` request for the given url.

  See `get/3` for examples on adding content and headers
  """
  def options(url, content \\ "", headers \\ []) do
    build(:OPTIONS, url, content, headers)
  end

  @doc """
  Create a `HEAD` request for the given url.

  See `get/3` for examples on adding content and headers
  """
  def head(url, content \\ "", headers \\ []) do
    build(:HEAD, url, content, headers)
  end

  # This should be the `Raxx.request` function
  defp build(method, url, body, headers) when is_binary(url) do
    url = URI.parse(url)
    url = %{url | query: Plug.Conn.Query.decode(url.query || "")}
    build(method, url, body, headers)
  end
  defp build(method, {url, query}, body, headers) do
    # DEBT check url string for query
    url = URI.parse(url)
    url_query = Plug.Conn.Query.decode(url.query || "")
    query = query |> Plug.Conn.Query.encode |> Plug.Conn.Query.decode
    query = Map.merge(url_query, query)
    url = %{url | query: query}
    build(method, url, body, headers)
  end
  # This pattern match cannot be an iolist, it contains a tuple.
  # It is therefore assumed to be body content
  defp build(method, url, body = [{_, _} | _], headers) do
    build(method, url, "", body ++ headers)
  end
  defp build(method, url, %{headers: headers, body: body}, extra_headers) do
    build(method, url, body, headers ++ extra_headers)
  end
  defp build(method, url, body, headers) do
    struct(Raxx.Request,
      scheme: url.scheme,
      host: url.host,
      port: url.port,
      method: method,
      path: Raxx.Request.split_path(url.path),
      query: url.query,
      headers: headers,
      body: body
    )
  end

  @doc false
  def split_path(path_string) do
    path_string
    |> String.split("/")
    |> Enum.reject(&empty_string?/1)
  end

  defp empty_string?("") do
    true
  end
  defp empty_string?(str) when is_binary(str) do
    false
  end
end
