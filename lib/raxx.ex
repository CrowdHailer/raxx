defmodule Raxx do
  @moduledoc """
  Tooling to work with HTTP.

  Several data structures are defined to model parts of the communication between client and server.

  - `Raxx.Request`: metadata sent by a client before sending content.
  - `Raxx.Response`: metadata sent by a server before sending content.
  - `Raxx.Data`: A part of a messages content.
  - `Raxx.Tail`: metadata set by client or server to conclude communication.

  This module contains functions to create and manipulate these structures.

  **See `Raxx.Server` for implementing a web application.**
  """

  @http_methods [
    :GET,
    :POST,
    :PUT,
    :PATCH,
    :DELETE,
    :HEAD,
    :OPTIONS
  ]

  @typedoc """
  Attribute value pair that can be serialized to an HTTP request or response
  """
  @type header :: {String.t(), String.t()}

  @typedoc """
  List of HTTP headers.
  """
  @type headers :: [header()]

  @typedoc """
  The body of a Raxx message.

  The body can be:
  - part of the message (`String.t()`).
  - empty (`false`).
  - present but unknown (`true`).
  """
  @type body :: boolean | String.t()

  @typedoc """
  Either a `Raxx.Request.t` or a `Raxx.Response.t`
  """
  @type message :: Raxx.Request.t() | Raxx.Response.t()

  @doc """
  Construct a `Raxx.Request`.

  An HTTP request must have a method and path.

  If the location argument is a relative path the scheme and authority values will be unset.
  When these values can be inferred from the location they will be set.

  The method must be an atom for one of the HTTP methods

  `#{inspect(@http_methods)}`

  The request will have no body or headers.
  These can be added with `set_header/3` and `set_body/2`.

  ## Examples

      iex> request(:HEAD, "/").method
      :HEAD

      iex> request(:GET, "/").path
      []

      iex> request(:GET, "/foo/bar").path
      ["foo", "bar"]

      iex> request(:GET, "https:///").scheme
      :https

      iex> request(:GET, "https://example.com").authority
      "example.com"

      iex> request(:GET, "/?foo=bar").query
      %{"foo" => "bar"}

      iex> request(:GET, "/?foo[bob]=bar").query
      %{"foo" => %{"bob" => "bar"}}

      iex> request(:GET, "/").headers
      []

      iex> request(:GET, "/").body
      false
  """
  @spec request(Raxx.Request.method(), String.t() | URI.t()) :: Raxx.Request.t()
  def request(method, url) when is_binary(url) do
    url = URI.parse(url)

    if url.query do
      {:ok, query} = URI2.Query.decode(url.query)
      request(method, %{url | query: query})
    else
      request(method, url)
    end
  end

  def request(method, url) when method in @http_methods do
    scheme =
      if url.scheme do
        url.scheme |> String.to_existing_atom()
      end

    segments = split_path(url.path || "/")

    struct(
      Raxx.Request,
      scheme: scheme,
      authority: url.authority,
      method: method,
      path: segments,
      query: url.query,
      headers: [],
      body: false
    )
  end

  @doc """
  Construct a `Raxx.Response`.

  The responses HTTP status code can be provided as an integer,
  or will be translated from a known atom.

  The response will have no body or headers.
  These can be added with `set_header/3` and `set_body/2`.

  ## Examples

      iex> response(200).status
      200

      iex> response(:no_content).status
      204

      iex> response(200).headers
      []

      iex> response(200).body
      false
  """
  @spec response(Raxx.Response.status_code() | atom) :: Raxx.Response.t()
  def response(status_code) when is_integer(status_code) do
    struct(Raxx.Response, status: status_code, headers: [], body: false)
  end

  filepath = Path.join(__DIR__, "status.rfc7231")
  @external_resource filepath
  {:ok, file} = File.read(filepath)
  status_lines = String.split(String.trim(file), ~r/\R/)

  statuses =
    status_lines
    |> Enum.map(fn status_line ->
         {code, " " <> reason_phrase} = Integer.parse(status_line)
         {code, reason_phrase}
       end)

  for {status_code, reason_phrase} <- statuses do
    reason =
      reason_phrase
      |> String.downcase()
      |> String.replace(" ", "_")
      |> String.to_atom()

    def response(unquote(reason)) do
      response(unquote(status_code))
    end
  end

  @doc """
  The RFC7231 specified reason phrase for each known HTTP status code

  ## Examples

      iex> reason_phrase(200)
      "OK"

      iex> reason_phrase(500)
      "Internal Server Error"
  """
  @spec reason_phrase(integer) :: String.t()
  for {status_code, reason_phrase} <- statuses do
    def reason_phrase(unquote(status_code)) do
      unquote(reason_phrase)
    end
  end

  @doc """
  Construct a `Raxx.Data`

  Wrap a piece of data as being part of a message's body.

  ## Examples

      iex> data("Hi").data
      "Hi"

  """
  @spec data(String.t()) :: Raxx.Data.t()
  def data(data) do
    %Raxx.Data{data: data}
  end

  @doc """
  Construct a `Raxx.Tail`

  ## Examples

      iex> tail([{"digest", "opaque-data"}]).headers
      [{"digest", "opaque-data"}]

      iex> tail().headers
      []
  """
  @spec tail([{String.t(), String.t()}]) :: Raxx.Tail.t()
  def tail(headers \\ []) do
    %Raxx.Tail{headers: headers}
  end

  @doc """
  Does the message struct contain all the data to be sent.

  ## Examples

      iex> request(:GET, "/")
      ...> |> complete?()
      true

      iex> response(:ok)
      ...> |> set_body("Hello, World!")
      ...> |> complete?()
      true

      iex> response(:ok)
      ...> |> set_body(true)
      ...> |> complete?()
      false
  """
  @spec complete?(message()) :: boolean
  def complete?(%{body: body}) when is_binary(body) do
    true
  end

  def complete?(%{body: body}) do
    !body
  end

  @doc """
  Add a query value to a request

  ## Examples

      iex> request(:GET, "/")
      ...> |> set_query(%{"value" => "1"})
      ...> |> Map.get(:query)
      %{"value" => "1"}
  """
  @spec set_query(Raxx.Request.t(), %{binary => binary}) :: Raxx.Request.t()
  def set_query(request = %Raxx.Request{query: nil}, query) do
    %{request | query: query}
  end

  @doc """
  Set the value of a header field.

  ## Examples

      iex> request(:GET, "/")
      ...> |> set_header("referer", "example.com")
      ...> |> set_header("accept", "text/html")
      ...> |> Map.get(:headers)
      [{"referer", "example.com"}, {"accept", "text/html"}]
  """
  @spec set_header(Raxx.Request.t(), String.t(), String.t()) :: Raxx.Request.t()
  @spec set_header(Raxx.Response.t(), String.t(), String.t()) :: Raxx.Response.t()
  def set_header(message = %{headers: headers}, name, value) do
    if String.downcase(name) != name do
      raise "Header keys must be lowercase"
    end

    if :proplists.is_defined(name, headers) do
      raise "Headers should not be duplicated"
    end

    %{message | headers: headers ++ [{name, value}]}
  end

  @doc """
  Sets multiple headers in one go

  ## Examples

      iex> request(:GET, "/")
      ...> |> set_headers([{"referer", "example.com"}, {"Authorization", "Bearer 1234567890"}])
      ...> |> Map.get(:headers)
      [{"referer", "example.com"}, {"accept", "text/html"}, {"Authorization", "Bearer 1234567890"}]
  """
  def set_headers(message = %{headers: _headers}, []),
    do: message
  def set_headers(message = %{headers: _headers}, [{name, value} | rest] = header_list),
    do: set_headers(set_header(message, name, value), rest)

  @doc """
  Add a complete body to a message.

  ## Examples

      iex> request(:GET, "/")
      ...> |> set_body("Hello")
      ...> |> Map.get(:body)
      "Hello"
  """
  @spec set_body(Raxx.Request.t(), body) :: Raxx.Request.t()
  @spec set_body(Raxx.Response.t(), body) :: Raxx.Response.t()
  def set_body(message = %{body: false}, body) do
    %{message | body: body}
  end

  @doc """
  Split a path on forward slashes.

  ## Examples

      iex> split_path("/foo/bar")
      ["foo", "bar"]

  """
  @spec split_path(String.t()) :: [String.t()]
  def split_path(path_string) do
    path_string
    |> String.split("/", trim: true)
  end

  @doc """
  Can application be run by compatable server?

  ## Examples

      iex> is_application?({Raxx.ServerTest.DefaultServer, %{}})
      true

      iex> is_application?({GenServer, %{}})
      false

      iex> is_application?({NotAModule, %{}})
      false
  """
  @spec is_application?({module(), any()}) :: boolean()
  def is_application?({module, _initial_state}) do
    Raxx.Server.is_implemented?(module)
  end

  @doc """
  Verify application can be run by compatable server?

  ## Examples

      iex> verify_application({Raxx.ServerTest.DefaultServer, %{}})
      {:ok, {Raxx.ServerTest.DefaultServer, %{}}}

      iex> verify_application({GenServer, %{}})
      {:error, "module `GenServer` does not implement `Raxx.Server` behaviour."}

      iex> verify_application({NotAModule, %{}})
      {:error, "module `NotAModule` is not available."}
  """
  @spec verify_application({module(), any()}) :: {:ok, {module(), any()}} | {:error, String.t()}
  def verify_application({module, initial_state}) do
    case Code.ensure_compiled?(module) do
      true ->
        module.module_info[:attributes]
        |> Keyword.get(:behaviour, [])
        |> Enum.member?(Raxx.Server)
        |> case do
             true ->
               {:ok, {module, initial_state}}

             false ->
               {
                 :error,
                 "module `#{Macro.to_string(module)}` does not implement `Raxx.Server` behaviour."
               }
           end

      false ->
        {:error, "module `#{Macro.to_string(module)}` is not available."}
    end
  end

  ######## COPIED FROM PLUG ########

  @doc ~S"""
  Escapes the given HTML to string.

      iex> html_escape("foo")
      "foo"

      iex> html_escape("<foo>")
      "&lt;foo&gt;"

      iex> html_escape("quotes: \" & \'")
      "quotes: &quot; &amp; &#39;"
  """
  @spec html_escape(String.t()) :: String.t()
  def html_escape(data) when is_binary(data) do
    IO.iodata_to_binary(to_iodata(data, 0, data, []))
  end

  @doc ~S"""
  Escapes the given HTML to iodata.

      iex> html_escape_to_iodata("foo")
      "foo"

      iex> html_escape_to_iodata("<foo>")
      [[[] | "&lt;"], "foo" | "&gt;"]

      iex> html_escape_to_iodata("quotes: \" & \'")
      [[[[], "quotes: " | "&quot;"], " " | "&amp;"], " " | "&#39;"]

  """
  @spec html_escape_to_iodata(String.t()) :: iodata
  def html_escape_to_iodata(data) when is_binary(data) do
    to_iodata(data, 0, data, [])
  end

  escapes = [
    {?<, "&lt;"},
    {?>, "&gt;"},
    {?&, "&amp;"},
    {?", "&quot;"},
    {?', "&#39;"}
  ]

  for {match, insert} <- escapes do
    defp to_iodata(<<unquote(match), rest::bits>>, skip, original, acc) do
      to_iodata(rest, skip + 1, original, [acc | unquote(insert)])
    end
  end

  defp to_iodata(<<_char, rest::bits>>, skip, original, acc) do
    to_iodata(rest, skip, original, acc, 1)
  end

  defp to_iodata(<<>>, _skip, _original, acc) do
    acc
  end

  for {match, insert} <- escapes do
    defp to_iodata(<<unquote(match), rest::bits>>, skip, original, acc, len) do
      part = binary_part(original, skip, len)
      to_iodata(rest, skip + len + 1, original, [acc, part | unquote(insert)])
    end
  end

  defp to_iodata(<<_char, rest::bits>>, skip, original, acc, len) do
    to_iodata(rest, skip, original, acc, len + 1)
  end

  defp to_iodata(<<>>, 0, original, _acc, _len) do
    original
  end

  defp to_iodata(<<>>, skip, original, acc, len) do
    [acc | binary_part(original, skip, len)]
  end
end
