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
  - part of the message (`binary`).
  - empty (`false`).
  - present but unknown (`true`).
  """
  @type body :: boolean | binary

  @typedoc """
  Either a `Raxx.Request.t` or a `Raxx.Response.t`
  """
  @type message :: Raxx.Request.t() | Raxx.Response.t()

  @typedoc """
  Set of all components that make up a message to or from server.
  """
  @type part :: Raxx.Request.t() | Raxx.Response.t() | Raxx.Data.t() | Raxx.Tail.t()

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

      iex> request(:GET, "/foo/bar").raw_path
      "/foo/bar"

      iex> request(:GET, "https:///").scheme
      :https

      iex> request(:GET, "https://example.com").authority
      "example.com"

      iex> request(:GET, "/").query
      nil

      iex> request(:GET, "/?").query
      ""

      iex> request(:GET, "/?foo=bar").query
      "foo=bar"

      iex> request(:GET, "/").headers
      []

      iex> request(:GET, "/").body
      false

  The path component of a request must contain at least `/`

  ### *https://tools.ietf.org/html/rfc7230#section-5.3.1*

  > If the target URI's path component is
  > empty, the client MUST send "/" as the path within the origin-form of
  > request-target.

  ### *https://tools.ietf.org/html/rfc7540#section-8.1.2.3*

  > "http" or "https" URIs that do not contain a path component
  > MUST include a value of '/'

      iex> request(:GET, "").raw_path
      "/"

      iex> request(:GET, "http://example.com").raw_path
      "/"
  """
  @spec request(Raxx.Request.method(), String.t() | URI.t()) :: Raxx.Request.t()
  def request(method, raw_url) when is_binary(raw_url) do
    url = URI.parse(raw_url)

    # DEBT: remove this query fix in 1.7 https://github.com/elixir-lang/elixir/pull/7565
    url =
      if is_nil(url.query) && String.contains?(raw_url, "?") do
        %{url | query: ""}
      else
        url
      end

    request(method, url)
  end

  def request(method, url) when method in @http_methods do
    scheme =
      if url.scheme do
        url.scheme |> String.to_existing_atom()
      end

    # DEBT in case of path '//' then parsing returns path of nil.
    # e.g. localhost:8080//
    raw_path = url.path || "/"
    segments = split_path(raw_path)

    struct(
      Raxx.Request,
      scheme: scheme,
      authority: url.authority,
      method: method,
      path: segments,
      raw_path: raw_path,
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

  def response(status) when is_atom(status) do
    response(status_code(status))
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

  statuses = statuses ++ Application.get_env(:raxx, :extra_statuses, [])

  for {status_code, reason_phrase} <- statuses do
    reason =
      reason_phrase
      |> String.downcase()
      |> String.replace(" ", "_")
      |> String.to_atom()

    defp status_code(unquote(reason)) do
      unquote(status_code)
    end
  end

  @doc """
  The RFC7231 specified reason phrase for each known HTTP status code.
  Extra reason phrases can be defined in raxx config under extra_status.

  For example.

      config :raxx,
        :extra_statuses, ["422", "Unprocessable Entity"]

  ## Examples

      iex> reason_phrase(200)
      "OK"

      iex> reason_phrase(500)
      "Internal Server Error"

      iex> reason_phrase(422)
      "Unprocessable Entity"
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
  @spec data(binary) :: Raxx.Data.t()
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
  Return the host, without port, for a request.

  ## Examples

      iex> request(:GET, "http://www.example.com/hello")
      ...> |> request_host()
      "www.example.com"

      iex> request(:GET, "http://www.example.com:1234/hello")
      ...> |> request_host()
      "www.example.com"
  """
  defdelegate request_host(request), to: Raxx.Request, as: :host

  @doc """
  Return the host, without port, for a request.

  ## Examples

      iex> request(:GET, "http://www.example.com:1234/hello")
      ...> |> request_port()
      1234

      iex> request(:GET, "http://www.example.com/hello")
      ...> |> request_port()
      80

      iex> request(:GET, "https://www.example.com/hello")
      ...> |> request_port()
      443
  """
  defdelegate request_port(request), to: Raxx.Request, as: :port

  @doc """
  Add a query value to a request

  ## Examples

      iex> request(:GET, "/")
      ...> |> set_query(%{"foo" => "bar"})
      ...> |> Map.get(:query)
      "foo=bar"
  """
  @spec set_query(Raxx.Request.t(), %{binary => binary}) :: Raxx.Request.t()
  def set_query(request = %Raxx.Request{query: nil}, query) do
    %{request | query: URI.encode_query(query)}
  end

  @doc """
  Fetch the decoded query from a request

  A map is always returned, even in the case of a request without a query string.

  ## Examples

      iex> request(:GET, "/")
      ...> |> fetch_query()
      {:ok, %{}}

      iex> request(:GET, "/?")
      ...> |> fetch_query()
      {:ok, %{}}

      iex> request(:GET, "/?foo=bar")
      ...> |> fetch_query()
      {:ok, %{"foo" => "bar"}}
  """
  @spec fetch_query(Raxx.Request.t()) :: {:ok, %{binary => binary}}
  def fetch_query(%Raxx.Request{query: nil}) do
    {:ok, %{}}
  end

  def fetch_query(%Raxx.Request{query: query_string}) do
    {:ok, URI.decode_query(query_string)}
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

    case :binary.match(value, ["\n", "\r"]) do
      {_, _} ->
        raise "Header values must not contain control feed (\\r) or newline (\\n)"

      :nomatch ->
        value
    end

    %{message | headers: headers ++ [{name, value}]}
  end

  @doc """
  Get the value of a header field.

  ## Examples

      iex> response(:ok)
      ...> |> set_header("content-type", "text/html")
      ...> |> get_header("content-type")
      "text/html"

      iex> response(:ok)
      ...> |> set_header("content-type", "text/html")
      ...> |> get_header("location")
      nil

      iex> response(:ok)
      ...> |> set_header("content-type", "text/html")
      ...> |> get_header("content-type", "text/plain")
      "text/html"

      iex> response(:ok)
      ...> |> set_header("content-type", "text/html")
      ...> |> get_header("location", "/")
      "/"
  """
  @spec get_header(Raxx.Request.t(), String.t(), String.t() | nil) :: String.t() | nil
  @spec get_header(Raxx.Response.t(), String.t(), String.t() | nil) :: String.t() | nil
  def get_header(%{headers: headers}, name, fallback \\ nil) do
    if String.downcase(name) != name do
      raise "Header keys must be lowercase"
    end

    case :proplists.get_all_values(name, headers) do
      [] ->
        fallback

      [value] ->
        value

      _ ->
        raise "More than one header found for `#{name}`"
    end
  end

  @doc """
  Delete a header, if present from a request or response.
  """
  @spec delete_header(Raxx.Request.t(), String.t()) :: Raxx.Request.t()
  @spec delete_header(Raxx.Response.t(), String.t()) :: Raxx.Response.t()
  def delete_header(message = %{headers: headers}, header) do
    headers = :proplists.delete(header, headers)
    %{message | headers: headers}
  end

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
  Create a response to redirect client to the given url.

  Response status can be set using the `:status` option.

  ## Examples
    iex> redirect("/foo")
    ...> |> get_header("location")
    "/foo"

    iex> redirect("/foo")
    ...> |> get_header("content-type")
    "text/html"

    iex> redirect("/foo")
    ...> |> Map.get(:body)
    ~s(<html><body>This resource has moved <a href="/foo">here</a>.</body></html>)

    iex> redirect("/foo")
    ...> |> Map.get(:status)
    303

    iex> redirect("/foo", status: 301)
    ...> |> Map.get(:status)
    301

    iex> redirect("/foo", status: :moved_permanently)
    ...> |> Map.get(:status)
    301

  ## Notes

  This implementation was lifted from the [sugar framework](https://github.com/sugar-framework/sugar/blob/405256747ce8c446c504e4dc533b24c76d864a5a/lib/sugar/controller/helpers.ex#L253-L259) and is sufficient for many usecases.

  I would like to implement a `back` function.
  Complication with such functionality are discussed here - https://github.com/phoenixframework/phoenix/pull/1402
  Sinatra has a very complete test suite including a back implementation - https://github.com/sinatra/sinatra/blob/9bd0d40229f76ff60d81c01ad2f4b1a8e6f31e05/test/helpers_test.rb#L183
  """
  def redirect(url, opts \\ []) do
    status = Keyword.get(opts, :status, :see_other)

    response(status)
    |> set_header("location", url)
    |> set_header("content-type", "text/html")
    |> set_body(redirect_page(url))
  end

  @doc """
  Put headers that improve browser security.

  The following headers are set:

  - x-frame-options - set to SAMEORIGIN to avoid clickjacking
    through iframes unless in the same origin
  - x-content-type-options - set to nosniff. This requires
    script and style tags to be sent with proper content type
  - x-xss-protection - set to "1; mode=block" to improve XSS
    protection on both Chrome and IE
  - x-download-options - set to noopen to instruct the browser
    not to open a download directly in the browser, to avoid
    HTML files rendering inline and accessing the security
    context of the application (like critical domain cookies)
  - x-permitted-cross-domain-policies - set to none to restrict
    Adobe Flash Player’s access to data

  ## Examples

      iex> response(:ok)
      ...> |> set_secure_browser_headers()
      ...> |> get_header("x-frame-options")
      "SAMEORIGIN"

      iex> response(:ok)
      ...> |> set_secure_browser_headers()
      ...> |> get_header("x-xss-protection")
      "1; mode=block"

      iex> response(:ok)
      ...> |> set_secure_browser_headers()
      ...> |> get_header("x-content-type-options")
      "nosniff"

      iex> response(:ok)
      ...> |> set_secure_browser_headers()
      ...> |> get_header("x-download-options")
      "noopen"

      iex> response(:ok)
      ...> |> set_secure_browser_headers()
      ...> |> get_header("x-permitted-cross-domain-policies")
      "none"
  """
  def set_secure_browser_headers(response = %Raxx.Response{}) do
    response
    |> set_header("x-frame-options", "SAMEORIGIN")
    |> set_header("x-xss-protection", "1; mode=block")
    |> set_header("x-content-type-options", "nosniff")
    |> set_header("x-download-options", "noopen")
    |> set_header("x-permitted-cross-domain-policies", "none")
  end

  defp redirect_page(url) do
    html = html_escape(url)
    "<html><body>This resource has moved <a href=\"#{html}\">here</a>.</body></html>"
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

  def normalized_path(request) do
    query_string =
      case request.query do
        nil ->
          ""

        query ->
          "?" <> query
      end

    "/" <> Enum.join(request.path, "/") <> query_string
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

defmodule :raxx do
  @moduledoc false
  # A module that is clean to call in erlang code with the same functionality as `Raxx`.

  for {name, arity} <- Raxx.__info__(:functions) do
    args = for i <- 0..arity, i > 0, do: Macro.var(:"#{i}", nil)
    defdelegate unquote(name)(unquote_splicing(args)), to: Raxx
  end
end
