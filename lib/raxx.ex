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
  - included in the message (as `iodata`).
  - empty (`false`).
  - present but unknown (`true`).
  """
  @type body :: boolean | iodata

  @typedoc """
  Either a `Raxx.Request.t` or a `Raxx.Response.t`
  """
  @type message :: Raxx.Request.t() | Raxx.Response.t()

  @typedoc """
  Set of all components that make up a message to or from server.
  """
  @type part :: Raxx.Request.t() | Raxx.Response.t() | Raxx.Data.t() | Raxx.Tail.t()

  @typedoc """
  The response status that can be parsed to e.g. response/1.
  This is either an integer status code like 404 or an atom that refers to a reason phrase in RFC7231 like :not_found
  """
  @type status :: Raxx.Response.status_code() | atom

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

      # works for custom status codes
      iex> response(299).status
      299
  """
  @spec response(status) :: Raxx.Response.t()
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

  ## Examples

      iex> reason_phrase(200)
      "OK"

      iex> reason_phrase(500)
      "Internal Server Error"

      iex> reason_phrase(999)
      nil
  """
  @spec reason_phrase(integer) :: String.t() | nil
  for {status_code, reason_phrase} <- statuses do
    def reason_phrase(unquote(status_code)) do
      unquote(reason_phrase)
    end
  end

  def reason_phrase(_) do
    nil
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
  Request does not expect any state change on the server.

  For full definition of safe methods see [RFC7231](https://tools.ietf.org/html/rfc7231#section-4.2.1)

  ## Examples

      iex> request(:GET, "/")
      ...> |> safe?()
      true

      iex> request(:POST, "/")
      ...> |> safe?()
      false

      iex> request(:PUT, "/")
      ...> |> safe?()
      false
  """
  @spec safe?(Raxx.Request.t()) :: boolean
  def safe?(%{method: method}) do
    Enum.member?([:GET, :HEAD, :OPTIONS, :TRACE], method)
  end

  @doc """
  Effect of handling this request more than once should be identical to handling it once.

  For full definition of idempotent methods see [RFC7231](https://tools.ietf.org/html/rfc7231#section-4.2.2)

  ## Examples

      iex> request(:GET, "/")
      ...> |> idempotent?()
      true

      iex> request(:POST, "/")
      ...> |> idempotent?()
      false

      iex> request(:PUT, "/")
      ...> |> idempotent?()
      true
  """
  @spec idempotent?(Raxx.Request.t()) :: boolean
  def idempotent?(%{method: method}) do
    Enum.member?([:GET, :HEAD, :OPTIONS, :TRACE, :PUT, :DELETE, :LINK, :UNLINK], method)
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

      iex> request(:GET, "http://www.example.com/hello")
      ...> |> request_port(%{http: 8080})
      8080
  """
  @spec request_port(Raxx.Request.t(), %{optional(atom) => :inet.port_number()}) ::
          :inet.port_number()
  defdelegate request_port(request), to: Raxx.Request, as: :port
  defdelegate request_port(request, default_ports), to: Raxx.Request, as: :port

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
  Return the decoded query from a request

  A map is always returned, even in the case of a request without a query string.

  ## Examples

      iex> request(:GET, "/")
      ...> |> get_query()
      %{}

      iex> request(:GET, "/?")
      ...> |> get_query()
      %{}

      iex> request(:GET, "/?foo=bar")
      ...> |> get_query()
      %{"foo" => "bar"}
  """
  def get_query(%Raxx.Request{query: nil}) do
    %{}
  end

  def get_query(%Raxx.Request{query: query_string}) do
    URI.decode_query(query_string)
  end

  @doc """
  This function never returns an error use, `get_query/1` instead.
  """
  @spec fetch_query(Raxx.Request.t()) :: {:ok, %{binary => binary}}
  def fetch_query(request) do
    {:ok, get_query(request)}
  end

  @doc """
  Set the value of a header field.

  ## Examples

      iex> request(:GET, "/")
      ...> |> set_header("referer", "example.com")
      ...> |> set_header("accept", "text/html")
      ...> |> Map.get(:headers)
      [{"referer", "example.com"}, {"accept", "text/html"}]

  ## Limitations

  Raxx is protocol agnostic, i.e. it can be used to construct HTTP/1.1 or HTTP/2 messages.
  This limits the heads that can (or should) be set on a message

  The host header should not be set, this information is encoded in the authority key of a request struct.
  This header is forbidden on a response.

  > A server MUST respond with a 400 (Bad Request) status code to any
    HTTP/1.1 request message that lacks a Host header field and to any
    request message that contains more than one Host header field or a
    Host header field with an invalid field-value.

  *https://tools.ietf.org/html/rfc7230#section-5.4*

  > Pseudo-header fields are only valid in the context in which they are
    defined.  Pseudo-header fields defined for requests MUST NOT appear
    in responses; pseudo-header fields defined for responses MUST NOT
    appear in requests.

  *https://tools.ietf.org/html/rfc7540#section-8.1.2.1*

  It is invalid to set a connection specific header on either a `Raxx.Request` or `Raxx.Response`.
  The connection specific headers are:

  - `connection`
  - `keep-alive`
  - `proxy-connection,`
  - `transfer-encoding,`
  - `upgrade`

  Connection specific headers are not part of the end to end message,
  even if in HTTP/1.1 they are encoded as just another header.

  > The "Connection" header field allows the sender to indicate desired
    control options for the current connection.  In order to avoid
    confusing downstream recipients, a proxy or gateway MUST remove or
    replace any received connection options before forwarding the
    message.

  *https://tools.ietf.org/html/rfc7230#section-6.1*

  > HTTP/2 does not use the Connection header field to indicate
    connection-specific header fields; in this protocol, connection-
    specific metadata is conveyed by other means.  An endpoint MUST NOT
    generate an HTTP/2 message containing connection-specific header
    fields; any message containing connection-specific header fields MUST
    be treated as malformed (Section 8.1.2.6)

  *https://tools.ietf.org/html/rfc7540#section-8.1.2.2*
  """
  @spec set_header(Raxx.Request.t(), String.t(), String.t()) :: Raxx.Request.t()
  @spec set_header(Raxx.Response.t(), String.t(), String.t()) :: Raxx.Response.t()
  def set_header(message = %{headers: headers}, name, value) do
    if String.downcase(name) != name do
      raise ArgumentError, "Header keys must be lowercase"
    end

    if :proplists.is_defined(name, headers) do
      raise ArgumentError, "Headers should not be duplicated"
    end

    case :binary.match(value, ["\n", "\r"]) do
      {_, _} ->
        raise ArgumentError, "Header values must not contain control feed (\\r) or newline (\\n)"

      :nomatch ->
        value
    end

    if name in ["connection", "keep-alive", "proxy-connection,", "transfer-encoding,", "upgrade"] do
      raise ArgumentError,
            "Cannot set a connection specific header, see documentation for details"
    end

    if name in ["host"] do
      raise ArgumentError, "Cannot set host header, see documentation for details"
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
      raise ArgumentError, "Header keys must be lowercase"
    end

    case :proplists.get_all_values(name, headers) do
      [] ->
        fallback

      [value] ->
        value

      _ ->
        raise ArgumentError, "More than one header found for `#{name}`"
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
  Set the content length of a request or response.

  The content length must be a non negative integer.

  ## Examples

      iex> response(:ok)
      ...> |> set_content_length(13)
      ...> |> get_header("content-length")
      "13"
  """
  @spec set_content_length(Raxx.Request.t(), non_neg_integer()) :: Raxx.Request.t()
  @spec set_content_length(Raxx.Response.t(), non_neg_integer()) :: Raxx.Response.t()
  def set_content_length(message, content_length) when content_length >= 0 do
    set_header(message, "content-length", Integer.to_string(content_length))
  end

  @doc """
  Get the integer value for the content length of a message.

  A well formed struct will always have a non negative content length, or none.

  ## Examples

      iex> response(:ok)
      ...> |> set_content_length(0)
      ...> |> get_content_length()
      0

      iex> response(:ok)
      ...> |> get_content_length()
      nil
  """
  @spec get_content_length(Raxx.Request.t()) :: nil | non_neg_integer()
  @spec get_content_length(Raxx.Response.t()) :: nil | non_neg_integer()
  def get_content_length(message) do
    case get_header(message, "content-length") do
      nil ->
        nil

      binary ->
        case Integer.parse(binary) do
          {content_length, ""} when content_length >= 0 ->
            content_length
        end
    end
  end

  @doc """
  Set the "content-disposition" header on a response indicating the file should be downloaded.

  Set's the disposition to `attachment` the only other value of `inline` is assumed when no `content-disposition` header.

  **NOTE:** no integration with multipart downloads,
  see https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Disposition#As_a_response_header_for_the_main_body for full details.

  **NOTE:** Sinatra sets `content-type` from filename extension,
  This is not done here in preference of being more explicit.
  https://github.com/sinatra/sinatra/blob/9590706ec6691520970c67b929776fd97d3c9ddd/lib/sinatra/base.rb#L362-L370


  ## Examples

      iex> response(:ok)
      ...> |> set_body("Hello, World!")
      ...> |> set_attachment("hello.txt")
      ...> |> get_header("content-disposition")
      "attachment; filename=hello.txt"

      iex> response(:ok)
      ...> |> set_body("Hello, World!")
      ...> |> set_attachment("hello world.txt")
      ...> |> get_header("content-disposition")
      "attachment; filename=hello+world.txt"
  """
  @spec set_attachment(Raxx.Request.t(), String.t()) :: Raxx.Request.t()
  @spec set_attachment(Raxx.Response.t(), String.t()) :: Raxx.Response.t()
  def set_attachment(message, filename) do
    set_header(
      message,
      "content-disposition",
      "attachment; filename=#{URI.encode_www_form(filename)}"
    )
  end

  @doc """
  Add a complete body to a message.

  All 1xx (Informational), 204 (No Content), and 304 (Not Modified) responses do not include a message body.
  This functional will raise an `ArgumentError` if a body is set on one of these reponses.

  https://tools.ietf.org/html/rfc7230#section-3.1.2

  ### Content Length

  When setting the body of a message to some iodata value,
  then the content length is also set.

  ## Examples

      iex> request = response(:ok)
      ...> |> set_body("Hello, World!")
      iex> request.body
      "Hello, World!"
      iex> Raxx.get_content_length(request)
      13

      iex> request = response(:ok)
      ...> |> set_body(true)
      iex> request.body
      true
      iex> Raxx.get_content_length(request)
      nil

  ## Limitations

  Requests using method `GET` or `HEAD` should not have a body.

  > An HTTP GET request includes request header fields and no payload
    body and is therefore transmitted as a single HEADERS frame, followed
    by zero or more CONTINUATION frames containing the serialized block
    of request header fields.

  *https://tools.ietf.org/html/rfc7540#section-8.1.3*

  Certain unusual usecases require a GET request with a body.
  For example [elastic search](https://www.elastic.co/guide/en/elasticsearch/guide/current/_empty_search.html#get_vs_post)

  Detailed discussion [here](https://stackoverflow.com/questions/978061/http-get-with-request-body).

  In such cases it is always possible to directly add the body to a request struct.
  Server implemenations should respect the provided body in such cases.

  Response with certain status codes never have a body.

  > All 1xx (Informational), 204 (No Content), and 304 (Not Modified)
    responses do not include a message body.  All other responses do
    include a message body, although the body might be of zero length.

  *https://tools.ietf.org/html/rfc7230#section-3.3*
  """
  @spec set_body(Raxx.Request.t(), body) :: Raxx.Request.t()
  @spec set_body(Raxx.Response.t(), body) :: Raxx.Response.t()
  def set_body(%Raxx.Response{status: status}, _body)
      when status in 100..199 or status == 204 or status == 304 do
    raise ArgumentError, "Response with status `#{status}` cannot have a body, see documentation."
  end

  def set_body(%Raxx.Request{method: method}, _body) when method in [:GET, :HEAD] do
    raise ArgumentError,
          "Request with method `#{method}` should not have a body, see documentation."
  end

  def set_body(message = %{body: false}, true) do
    %{message | body: true}
  end

  def set_body(message = %{body: false}, body) do
    content_length = :erlang.iolist_size(body)

    message
    |> set_content_length(content_length)
    |> Map.put(:body, body)
  end

  @doc """
  Create a response to redirect client to the given url.

  Response status can be set using the `:status` option.
  The body can be set with the `:body` option.
  Content-type header can be set with the `:content_type` option.

  ## Examples
    iex> redirect("/foo")
    ...> |> get_header("location")
    "/foo"

    iex> redirect("/foo")
    ...> |> Map.get(:body)
    false

    iex> redirect("/foo")
    ...> |> Map.get(:status)
    303

    iex> redirect("/foo", body: "Redirecting...")
    ...> |> Map.get(:body)
    "Redirecting..."

    iex> redirect("/foo", body: "Redirecting...")
    ...> |> get_header("content-type")
    nil

    iex> redirect("/foo", body: "Redirecting...", content_type: "text/html")
    ...> |> get_header("content-type")
    "text/html"

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
  @spec redirect(String.t(), status: status, body: body, content_type: String.t()) ::
          Raxx.Response.t()
  def redirect(url, opts \\ []) do
    status = Keyword.get(opts, :status, :see_other)
    body = Keyword.get(opts, :body, nil)
    content_type = Keyword.get(opts, :content_type, nil)

    response(status)
    |> set_header("location", url)
    |> set_redirect_body(body)
    |> set_redirect_content_type(content_type)
  end

  defp set_redirect_body(response, nil), do: response
  defp set_redirect_body(response, val), do: set_body(response, val)
  defp set_redirect_content_type(response, nil), do: response
  defp set_redirect_content_type(response, val), do: set_header(response, "content-type", val)

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

  @doc false
  # Use to turn errors into a standard reponse format.
  # In the future could be replaced with a protocol,
  # would require redefining errors as structs.
  def error_response(reason)

  # Extend error to include what kind or line, request/header
  def error_response({:invalid_line, line}) do
    response(:bad_request)
    |> set_header("content-type", "text/plain")
    |> set_body(["Invalid line:\r\n\r\n", line])
  end

  def error_response({:line_length_limit_exceeded, :request_line}) do
    response(:uri_too_long)
    |> set_header("content-type", "text/plain")
    |> set_body("Request line too long")
  end

  def error_response({:line_length_limit_exceeded, :header_line}) do
    response(:bad_request)
    |> set_header("content-type", "text/plain")
    |> set_body("Header line too long")
  end

  def error_response({:header_count_exceeded, maximum_headers_count}) do
    response(:bad_request)
    |> set_header("content-type", "text/plain")
    |> set_body("Maximum number of headers (#{maximum_headers_count}) exceeded")
  end

  def error_response(:multiple_connection_headers) do
    response(:bad_request)
    |> set_header("content-type", "text/plain")
    |> set_body("Singular header 'connection' was submitted multiple times")
  end

  def error_response(:invalid_connection_header) do
    response(:bad_request)
    |> set_header("content-type", "text/plain")
    |> set_body("Required header 'connection' was invalid")
  end

  def error_response(:no_host_header) do
    response(:bad_request)
    |> set_header("content-type", "text/plain")
    |> set_body("Required header 'host' was missing")
  end

  def error_response(:multiple_host_headers) do
    response(:bad_request)
    |> set_header("content-type", "text/plain")
    |> set_body("Singular header 'host' was submitted multiple times")
  end

  def error_response(:multiple_content_length_headers) do
    response(:bad_request)
    |> set_header("content-type", "text/plain")
    |> set_body("Singular header 'content-length' was submitted multiple times")
  end

  def error_response(:invalid_content_length_header) do
    response(:bad_request)
    |> set_header("content-type", "text/plain")
    |> set_body("Required header 'content-length' was invalid")
  end

  def error_response(status) do
    response = response(status)
    reason_phrase = reason_phrase(response.status)

    response
    |> set_header("content-type", "text/plain")
    |> set_body(reason_phrase)
  end

  @doc """
  Helper function that takes a list of `t:Raxx.part/0` parts and breaks
  down Request/Response objects containing binary `body` values
  into their head, data and tail parts.

  All other parts get left untouched.

  ## Examples
      iex> response = response(:ok)
      iex> response.body
      false
      iex> [response] == separate_parts([response])
      true

      iex> response_with_body = response(:ok) |> set_body("some body")
      iex> [head, data, tail] = separate_parts([response_with_body])
      iex> head
      %Raxx.Response{status: 200, body: true, headers: [{"content-length", "9"}]}
      iex> data
      %Raxx.Data{data: "some body"}
      iex> tail
      %Raxx.Tail{headers: []}
  """
  @spec separate_parts([Raxx.part()]) :: [Raxx.part()]
  def separate_parts(parts) when is_list(parts) do
    Enum.flat_map(parts, &separate_part/1)
  end

  defp separate_part(part = %Raxx.Data{}) do
    [part]
  end

  defp separate_part(part = %Raxx.Tail{}) do
    [part]
  end

  defp separate_part(response_headers = %Raxx.Response{body: true}) do
    [response_headers]
  end

  defp separate_part(response = %Raxx.Response{body: false}) do
    [response]
  end

  defp separate_part(response = %Raxx.Response{body: body}) when is_binary(body) do
    headers = %Raxx.Response{response | body: true}

    [
      headers,
      Raxx.data(body),
      Raxx.tail([])
    ]
  end

  defp separate_part(request_headers = %Raxx.Request{body: true}) do
    [request_headers]
  end

  defp separate_part(request = %Raxx.Request{body: false}) do
    [request]
  end

  defp separate_part(response = %Raxx.Request{body: body}) when is_binary(body) do
    headers = %Raxx.Request{response | body: true}

    [
      headers,
      Raxx.data(body),
      Raxx.tail([])
    ]
  end

  defp separate_part(other) do
    # allowing for custom/special meaning parts
    [other]
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
