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
  | **authority** | The location of the hosting server, as a binary. e.g. `www.example.com`. Plus an optional port number, separated from the hostname by a colon |
  | **method** | The HTTP request method, such as “GET” or “POST”, as a binary. This cannot ever be an empty string, and is always uppercase. |
  | **mount** | The segments of the request URL's “path”, that have already been matched. Same as rack path_info. This may be an empty array, if the requested URL targets the application root. |
  | **path** | The remainder of the request URL's “path”, split into segments. It designates the virtual “location” of the request's target within the application. This may be an empty array, if the requested URL targets the application root. |
  | **query** | The query parameters from the URL search string, formatted as a map of strings. |
  | **headers** | The headers from the HTTP request as a map of strings. Note all headers will be downcased, e.g. `%{"content-type" => "text/plain"}` |
  | **body** | The body content sent with the request |

  ## Examples

      iex> get("http://example.com:8080/some/path?query=foo")
      ...> |> set_header("content-type", "text/plain")
      ...> |> set_body("Hello, World!")
      %Raxx.Request{body: "Hello, World!",
          headers: [{"content-type", "text/plain"}], authority: "example.com:8080",
          method: :GET, mount: [], path: ["some", "path"],
          query: %{"query" => "foo"}, scheme: :http}

  """

  @type request :: %__MODULE__{
    scheme: binary,
    authority: binary,
    method: binary,
    mount: [binary],
    path: [binary],
    query: %{binary => binary},
    headers: [{binary, binary}],
    body: binary,
  }

  defstruct [
    scheme: nil,
    authority: nil,
    method: nil,
    mount: [],
    path: [],
    query: %{},
    headers: [],
    body: nil,
  ]

  @doc """
  Create a `GET` request for the given url.

  Optional content and headers can be added to the request.

  ## Examples

      iex> get("/").path
      []

      iex> get("/foo/bar").path
      ["foo", "bar"]

      iex> get("https:///").scheme
      :https

      iex> get("https://example.com").authority
      "example.com"

      iex> get("/?foo=bar").query
      %{"foo" => "bar"}
  """
  def get(url) do
    new(:GET, url)
  end

  @doc """
  Create a `POST` request for the given url.

  See `get/1` for examples on adding content and headers
  """
  def post(url) do
    new(:POST, url)
  end

  @doc """
  Create a `PUT` request for the given url.

  See `get/1` for examples on adding content and headers
  """
  def put(url) do
    new(:PUT, url)
  end

  @doc """
  Create a `PATCH` request for the given url.

  See `get/1` for examples on adding content and headers
  """
  def patch(url) do
    new(:PATCH, url)
  end

  @doc """
  Create a `DELETE` request for the given url.

  See `get/1` for examples on adding content and headers
  """
  def delete(url) do
    new(:DELETE, url)
  end

  @doc """
  Create a `OPTIONS` request for the given url.

  See `get/1` for examples on adding content and headers
  """
  def options(url) do
    new(:OPTIONS, url)
  end

  @doc """
  Create a `HEAD` request for the given url.

  See `get/1` for examples on adding content and headers
  """
  def head(url) do
    new(:HEAD, url)
  end

  @doc """
  Add a query value to a request

  Examples
      # TODO
      # iex> get({"/", %{foo: "bar"}}).query
      # %{"foo" => "bar"}
  """
  def set_query(request, query) do
    %{request | query: query}
  end

  @doc """
      # iex> get("/", [{"referer", "/home"}]).headers
      # [{"referer", "/home"}]
  """
  def set_header(request = %{headers: headers}, name, value) do
    # TODO check lowercase
    %{request | headers: headers ++ [{name, value}]}
  end

  def set_body(request, body) do
    # TODO raise if body already set
    %{request | body: body}
  end
  defp new(method, url) when is_binary(url) do
    url = URI.parse(url)
    url = %{url | query: Plug.Conn.Query.decode(url.query || "")}
    new(method, url)
  end
  defp new(method, url) do
    scheme = if url.scheme do
      url.scheme |> String.to_existing_atom()
    end
    segments = Raxx.Request.split_path(url.path || "/")
    struct(Raxx.Request,
      scheme: scheme,
      authority: url.authority,
      method: method,
      path: segments,
      query: url.query,
      headers: [],
      body: false
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

  @doc """
  Just the request contain all content the will be part of the request stream.
  """
  def complete?(%__MODULE__{body: body}) when is_binary(body) do
    true
  end
  def complete?(%__MODULE__{body: body}) do
    !body
  end
end
