defmodule Raxx.HTTP1 do
  @moduledoc """
  Toolkit for parsing and serializing requests to HTTP/1.1 format.

  The majority of functions return iolists and not compacted binaries.
  To efficiently turn a list into a binart use `:erlang.iolist_to_binary/1`

  ## Notes

  ### content-length

  The serializer does not add the content-length header for empty bodies.
  The rfc7230 says it SHOULD, but there are may cases where it must not be sent.
  This simplifies the serialization code.

  It is probable that in the future `Raxx.set_content_length/2` will be added.
  And that it will be used by `Raxx.set_body/2`

  This is because when parsing a message the content-length headers is kept.
  Adding it to the `Raxx.Request` struct will increase the cases when serialization and deserialization result in the exact same struct.

  ## Property testing

  Functionality in this module might be a good opportunity for property based testing.
  Elixir Outlaws convinced me to give it a try.

  - Property of serialize then decode the head should end up with the same struct
  - Propery of any number of splits in the binary should not change the output
  """

  @type connection_status :: nil | :close | :keepalive
  @type body_read_state :: {:complete, binary} | {:bytes, non_neg_integer} | :chunked

  @crlf "\r\n"

  @maximum_line_length 1_000
  @maximum_headers_count 100

  @doc ~S"""
  Serialize a request to wire format

  # NOTE set_body should add content-length otherwise we don't know if to delete it to match on other end, when serializing

  ### *https://tools.ietf.org/html/rfc7230#section-5.4*

  > Since the Host field-value is critical information for handling a
  > request, a user agent SHOULD generate Host as the first header field
  > following the request-line.

  ## Examples

      iex> request = Raxx.request(:GET, "http://example.com/path?qs")
      ...> |> Raxx.set_header("accept", "text/plain")
      ...> {head, body} =  Raxx.HTTP1.serialize_request(request)
      ...> :erlang.iolist_to_binary(head)
      "GET /path?qs HTTP/1.1\r\nhost: example.com\r\naccept: text/plain\r\n\r\n"
      iex> body
      {:complete, ""}

      iex> request = Raxx.request(:POST, "https://example.com")
      ...> |> Raxx.set_header("content-type", "text/plain")
      ...> |> Raxx.set_body(true)
      ...> {head, body} =  Raxx.HTTP1.serialize_request(request)
      ...> :erlang.iolist_to_binary(head)
      "POST / HTTP/1.1\r\nhost: example.com\r\ntransfer-encoding: chunked\r\ncontent-type: text/plain\r\n\r\n"
      iex> body
      :chunked

      iex> request = Raxx.request(:POST, "https://example.com")
      ...> |> Raxx.set_header("content-length", "13")
      ...> |> Raxx.set_body(true)
      ...> {head, body} =  Raxx.HTTP1.serialize_request(request)
      ...> :erlang.iolist_to_binary(head)
      "POST / HTTP/1.1\r\nhost: example.com\r\ncontent-length: 13\r\n\r\n"
      iex> body
      {:bytes, 13}

  ### *https://tools.ietf.org/html/rfc7230#section-6.1*

  > A client that does not support persistent connections MUST send the
  > "close" connection option in every request message.

      iex> request = Raxx.request(:GET, "http://example.com/")
      ...> |> Raxx.set_header("accept", "text/plain")
      ...> {head, _body} =  Raxx.HTTP1.serialize_request(request, connection: :close)
      ...> :erlang.iolist_to_binary(head)
      "GET / HTTP/1.1\r\nhost: example.com\r\nconnection: close\r\naccept: text/plain\r\n\r\n"

      iex> request = Raxx.request(:GET, "http://example.com/")
      ...> |> Raxx.set_header("accept", "text/plain")
      ...> {head, _body} =  Raxx.HTTP1.serialize_request(request, connection: :keepalive)
      ...> :erlang.iolist_to_binary(head)
      "GET / HTTP/1.1\r\nhost: example.com\r\nconnection: keep-alive\r\naccept: text/plain\r\n\r\n"
  """
  @spec serialize_request(Raxx.Request.t(), [{:connection, connection_status}]) ::
          {iodata, body_read_state}
  def serialize_request(request = %Raxx.Request{}, options \\ []) do
    {payload_headers, body} = payload(request)
    connection_headers = connection_headers(Keyword.get(options, :connection))

    headers =
      [{"host", request.authority}] ++ connection_headers ++ payload_headers ++ request.headers

    head = [request_line(request), header_lines(headers), @crlf]
    {head, body}
  end

  @doc ~S"""
  Parse the head part of a request from a buffer.

  The scheme is not part of a HTTP/1.1 request, yet it is part of a HTTP/2 request.
  When parsing a request the scheme the buffer was received by has to be given.

  ## Options

  - **scheme** (required)
    Set the scheme of the `Raxx.Request` struct.
    This information is not contained in the data of a HTTP/1 request.

  - **maximum_headers_count**
    Maximum number of headers allowed in the request.

  - **maximum_line_length**
    Maximum length (in bytes) of request line or any header line.

  ## Examples

      iex> "GET /path?qs HTTP/1.1\r\nhost: example.com\r\naccept: text/plain\r\n\r\n"
      ...> |> Raxx.HTTP1.parse_request(scheme: :http)
      {:ok,
       {%Raxx.Request{
         authority: "example.com",
         body: false,
         headers: [{"accept", "text/plain"}],
         method: :GET,
         mount: [],
         path: ["path"],
         query: "qs",
         raw_path: "/path",
         scheme: :http
       }, nil, {:complete, ""}, ""}}

      iex> "GET /path?qs HTTP/1.1\r\nhost: example.com\r\naccept: text/plain\r\n\r\n"
      ...> |> Raxx.HTTP1.parse_request(scheme: :https)
      {:ok,
       {%Raxx.Request{
         authority: "example.com",
         body: false,
         headers: [{"accept", "text/plain"}],
         method: :GET,
         mount: [],
         path: ["path"],
         query: "qs",
         raw_path: "/path",
         scheme: :https
       }, nil, {:complete, ""}, ""}}

      iex> "POST /path HTTP/1.1\r\nhost: example.com\r\ntransfer-encoding: chunked\r\ncontent-type: text/plain\r\n\r\n"
      ...> |> Raxx.HTTP1.parse_request(scheme: :http)
      {:ok,
       {%Raxx.Request{
         authority: "example.com",
         body: true,
         headers: [{"content-type", "text/plain"}],
         method: :POST,
         mount: [],
         path: ["path"],
         query: nil,
         raw_path: "/path",
         scheme: :http
       }, nil, :chunked, ""}}

      iex> "POST /path HTTP/1.1\r\nhost: example.com\r\ncontent-length: 13\r\n\r\n"
      ...> |> Raxx.HTTP1.parse_request(scheme: :http)
      {:ok,
       {%Raxx.Request{
         authority: "example.com",
         body: true,
         headers: [{"content-length", "13"}],
         method: :POST,
         mount: [],
         path: ["path"],
         query: nil,
         raw_path: "/path",
         scheme: :http
       }, nil, {:bytes, 13}, ""}}

      iex> "GET /path?qs HT"
      ...> |> Raxx.HTTP1.parse_request(scheme: :http)
      {:more, "GET /path?qs HT"}

      iex> "GET /path?qs HTTP/1.1\r\nhost: exa"
      ...> |> Raxx.HTTP1.parse_request(scheme: :http)
      {:more, "GET /path?qs HTTP/1.1\r\nhost: exa"}

      # Missing host header
      iex> "GET /path?qs HTTP/1.1\r\naccept: text/plain\r\n\r\n"
      ...> |> Raxx.HTTP1.parse_request(scheme: :http)
      {:error, :no_host_header}

      # Invalid start line
      iex> "!!!BAD_REQUEST_LINE\r\n"
      ...> |> Raxx.HTTP1.parse_request(scheme: :http)
      {:error, {:invalid_line, "!!!BAD_REQUEST_LINE\r\n"}}

      # Invalid header line
      iex> "GET / HTTP/1.1\r\n!!!BAD_HEADER\r\n\r\n"
      ...> |> Raxx.HTTP1.parse_request(scheme: :http)
      {:error, {:invalid_line, "!!!BAD_HEADER\r\n"}}

      # Test connection status is extracted
      iex> "GET /path?qs HTTP/1.1\r\nhost: example.com\r\nconnection: close\r\naccept: text/plain\r\n\r\n"
      ...> |> Raxx.HTTP1.parse_request(scheme: :http)
      {:ok,
       {%Raxx.Request{
         authority: "example.com",
         body: false,
         headers: [{"accept", "text/plain"}],
         method: :GET,
         mount: [],
         path: ["path"],
         query: "qs",
         raw_path: "/path",
         scheme: :http
       }, :close, {:complete, ""}, ""}}

       iex> "GET /path?qs HTTP/1.1\r\nhost: example.com\r\nconnection: keep-alive\r\naccept: text/plain\r\n\r\n"
       ...> |> Raxx.HTTP1.parse_request(scheme: :http)
       {:ok,
        {%Raxx.Request{
          authority: "example.com",
          body: false,
          headers: [{"accept", "text/plain"}],
          method: :GET,
          mount: [],
          path: ["path"],
          query: "qs",
          raw_path: "/path",
          scheme: :http
        }, :keepalive, {:complete, ""}, ""}}

      # Test line_length is limited
      # "GET /" +  "HTTP/1.1\r\n" = 15
      iex> path = "/" <> String.duplicate("a", 985)
      ...> "GET #{path} HTTP/1.1\r\n"
      ...> |> Raxx.HTTP1.parse_request(scheme: :http)
      {:error, {:line_length_limit_exceeded, :request_line}}

      iex> path = "/" <> String.duplicate("a", 984)
      ...> {:more, _} = "GET #{path} HTTP/1.1\r\n"
      ...> |> Raxx.HTTP1.parse_request(scheme: :http)
      ...> :ok
      :ok

      iex> path = "/" <> String.duplicate("a", 1984)
      ...> {:more, _} = "GET #{path} HTTP/1.1\r\n"
      ...> |> Raxx.HTTP1.parse_request(scheme: :http, maximum_line_length: 2000)
      ...> :ok
      :ok

      iex> "GET / HTTP/1.1\r\nhost: #{String.duplicate("a", 993)}\r\n"
      ...> |> Raxx.HTTP1.parse_request(scheme: :http)
      {:error, {:line_length_limit_exceeded, :header_line}}

      iex> {:more, _} = "GET / HTTP/1.1\r\nhost: #{String.duplicate("a", 992)}\r\n"
      ...> |> Raxx.HTTP1.parse_request(scheme: :http)
      ...> :ok
      :ok

      iex> {:more, _} = "GET / HTTP/1.1\r\nhost: #{String.duplicate("a", 1992)}\r\n"
      ...> |> Raxx.HTTP1.parse_request(scheme: :http, maximum_line_length: 2000)
      ...> :ok
      :ok
  """
  @spec parse_request(binary, [option]) ::
          {:ok, {Raxx.Request.t(), connection_status, body_read_state, binary}}
          | {:error, term}
          | {:more, :undefined}
        when option: {:scheme, atom} | {:maximum_line_length, integer}
  def parse_request(buffer, options) do
    scheme = Keyword.get(options, :scheme)
    maximum_line_length = Keyword.get(options, :maximum_line_length, @maximum_line_length)
    maximum_headers_count = Keyword.get(options, :maximum_headers_count, @maximum_headers_count)

    case :erlang.decode_packet(:http_bin, buffer, line_length: maximum_line_length) do
      {:ok, {:http_request, method, {:abs_path, path_and_query}, _version}, rest} ->
        case parse_headers(rest,
               maximum_line_length: maximum_line_length,
               maximum_headers_count: maximum_headers_count
             ) do
          {:ok, headers, rest2} ->
            case Enum.split_with(headers, fn {key, _value} -> key == "host" end) do
              {[{"host", host}], headers} ->
                {headers, body_present, body_read_state} = decode_payload(headers)

                {connection_status, headers} = decode_connection_status(headers)

                request =
                  Raxx.request(method, path_and_query)
                  |> Map.put(:scheme, scheme)
                  |> Map.put(:authority, host)
                  |> Map.put(:headers, headers)
                  |> Map.put(:body, body_present)

                {:ok, {request, connection_status, body_read_state, rest2}}

              {[], _headers} ->
                {:error, :no_host_header}
            end

          {:error, reason} ->
            {:error, reason}

          {:more, :undefined} ->
            {:more, buffer}
        end

      {:ok, {:http_error, invalid_line}, _rest} ->
        {:error, {:invalid_line, invalid_line}}

      {:error, :invalid} ->
        {:error, {:line_length_limit_exceeded, :request_line}}

      {:more, :undefined} ->
        {:more, buffer}
    end
  end

  defp parse_headers(buffer, options, headers \\ []) do
    {:ok, maximum_line_length} = Keyword.fetch(options, :maximum_line_length)
    {:ok, maximum_headers_count} = Keyword.fetch(options, :maximum_headers_count)

    if length(headers) >= maximum_headers_count do
      {:error, :header_count_exceeded}
    else
      case :erlang.decode_packet(:httph_bin, buffer, line_length: maximum_line_length) do
        {:ok, :http_eoh, rest} ->
          {:ok, Enum.reverse(headers), rest}

        {:ok, {:http_header, _, key, _, value}, rest} ->
          parse_headers(rest, options, [
            {String.downcase("#{key}"), value} | headers
          ])

        {:ok, {:http_error, invalid_line}, _rest} ->
          {:error, {:invalid_line, invalid_line}}

        {:error, :invalid} ->
          {:error, {:line_length_limit_exceeded, :header_line}}

        {:more, :undefined} ->
          {:more, :undefined}
      end
    end
  end

  @doc ~S"""
  Serialize a response to an iolist

  Because of HEAD requests we should keep body separate
  ## Examples

      iex> response = Raxx.response(200)
      ...> |> Raxx.set_header("content-type", "text/plain")
      ...> |> Raxx.set_body("Hello, World!")
      ...> {head, body} =  Raxx.HTTP1.serialize_response(response)
      ...> :erlang.iolist_to_binary(head)
      "HTTP/1.1 200 OK\r\ncontent-length: 13\r\ncontent-type: text/plain\r\n\r\n"
      iex> body
      {:complete, "Hello, World!"}

      iex> response = Raxx.response(200)
      ...> |> Raxx.set_header("content-length", "13")
      ...> |> Raxx.set_header("content-type", "text/plain")
      ...> |> Raxx.set_body(true)
      ...> {head, body} =  Raxx.HTTP1.serialize_response(response)
      ...> :erlang.iolist_to_binary(head)
      "HTTP/1.1 200 OK\r\ncontent-length: 13\r\ncontent-type: text/plain\r\n\r\n"
      iex> body
      {:bytes, 13}

      iex> response = Raxx.response(200)
      ...> |> Raxx.set_header("content-type", "text/plain")
      ...> |> Raxx.set_body(true)
      ...> {head, body} =  Raxx.HTTP1.serialize_response(response)
      ...> :erlang.iolist_to_binary(head)
      "HTTP/1.1 200 OK\r\ntransfer-encoding: chunked\r\ncontent-type: text/plain\r\n\r\n"
      iex> body
      :chunked

      > A server MUST NOT send a Content-Length header field in any response
      > with a status code of 1xx (Informational) or 204 (No Content).  A
      > server MUST NOT send a Content-Length header field in any 2xx
      > (Successful) response to a CONNECT request (Section 4.3.6 of
      > [RFC7231]).

      iex> Raxx.response(204)
      ...> |> Raxx.set_header("foo", "bar")
      ...> |> Raxx.HTTP1.serialize_response()
      ...> |> elem(0)
      ...> |> :erlang.iolist_to_binary()
      "HTTP/1.1 204 No Content\r\nfoo: bar\r\n\r\n"

  ### *https://tools.ietf.org/html/rfc7230#section-6.1*

  > A server that does not support persistent connections MUST send the
  > "close" connection option in every response message that does not
  > have a 1xx (Informational) status code.

      iex> Raxx.response(204)
      ...> |> Raxx.set_header("foo", "bar")
      ...> |> Raxx.HTTP1.serialize_response(connection: :close)
      ...> |> elem(0)
      ...> |> :erlang.iolist_to_binary()
      "HTTP/1.1 204 No Content\r\nconnection: close\r\nfoo: bar\r\n\r\n"

      iex> Raxx.response(204)
      ...> |> Raxx.set_header("foo", "bar")
      ...> |> Raxx.HTTP1.serialize_response(connection: :keepalive)
      ...> |> elem(0)
      ...> |> :erlang.iolist_to_binary()
      "HTTP/1.1 204 No Content\r\nconnection: keep-alive\r\nfoo: bar\r\n\r\n"
  """
  @spec serialize_response(Raxx.Response.t(), [{:connection, connection_status}]) ::
          {iolist, body_read_state}
  def serialize_response(response = %Raxx.Response{}, options \\ []) do
    {payload_headers, body} = payload(response)
    connection_headers = connection_headers(Keyword.get(options, :connection))
    headers = connection_headers ++ payload_headers ++ response.headers
    head = [status_line(response), header_lines(headers), @crlf]
    {head, body}
  end

  @doc ~S"""
  Parse the head of a response.

  A scheme option is not given to this parser because the scheme not a requirement in HTTP/1 or HTTP/2

  ## Options

  - **maximum_headers_count**
    Maximum number of headers allowed in the request.

  - **maximum_line_length**
    Maximum length (in bytes) of request line or any header line.

  ## Examples

      iex> "HTTP/1.1 204 No Content\r\nfoo: bar\r\n\r\n"
      ...> |> Raxx.HTTP1.parse_response()
      {:ok, {%Raxx.Response{
        status: 204,
        headers: [{"foo", "bar"}],
        body: false
      }, nil, {:complete, ""}, ""}}

      iex> "HTTP/1.1 200 OK\r\ncontent-length: 13\r\ncontent-type: text/plain\r\n\r\n"
      ...> |> Raxx.HTTP1.parse_response()
      {:ok, {%Raxx.Response{
        status: 200,
        headers: [{"content-length", "13"}, {"content-type", "text/plain"}],
        body: true
      }, nil, {:bytes, 13}, ""}}

      iex> "HTTP/1.1 204 No Con"
      ...> |> Raxx.HTTP1.parse_response()
      {:more, :undefined}

      iex> "HTTP/1.1 204 No Content\r\nfo"
      ...> |> Raxx.HTTP1.parse_response()
      {:more, :undefined}

      iex> "!!!BAD_STATUS_LINE\r\n"
      ...> |> Raxx.HTTP1.parse_response()
      {:error, {:invalid_line, "!!!BAD_STATUS_LINE\r\n"}}

      iex> "HTTP/1.1 204 No Content\r\n!!!BAD_HEADER\r\n\r\n"
      ...> |> Raxx.HTTP1.parse_response()
      {:error, {:invalid_line, "!!!BAD_HEADER\r\n"}}

      iex> "HTTP/1.1 204 No Content\r\nconnection: close\r\nfoo: bar\r\n\r\n"
      ...> |> Raxx.HTTP1.parse_response()
      {:ok, {%Raxx.Response{
        status: 204,
        headers: [{"foo", "bar"}],
        body: false
      }, :close, {:complete, ""}, ""}}

      iex> "HTTP/1.1 204 No Content\r\nconnection: keep-alive\r\nfoo: bar\r\n\r\n"
      ...> |> Raxx.HTTP1.parse_response()
      {:ok, {%Raxx.Response{
        status: 204,
        headers: [{"foo", "bar"}],
        body: false
      }, :keepalive, {:complete, ""}, ""}}

      # Test exceptional case when server returns Title case values
      iex> "HTTP/1.1 204 No Content\r\nconnection: Close\r\nfoo: bar\r\n\r\n"
      ...> |> Raxx.HTTP1.parse_response()
      {:ok, {%Raxx.Response{
        status: 204,
        headers: [{"foo", "bar"}],
        body: false
      }, :close, {:complete, ""}, ""}}

      # Test exceptional case when server uses Title case values
      iex> "HTTP/1.1 204 No Content\r\nconnection: Keep-alive\r\nfoo: bar\r\n\r\n"
      ...> |> Raxx.HTTP1.parse_response()
      {:ok, {%Raxx.Response{
        status: 204,
        headers: [{"foo", "bar"}],
        body: false
      }, :keepalive, {:complete, ""}, ""}}

      # Test line_length is limited
      # "HTTP/1.1 204 " + newlines = 15
      iex> reason_phrase = String.duplicate("A", 986)
      ...> "HTTP/1.1 204 #{reason_phrase}\r\n"
      ...> |> Raxx.HTTP1.parse_response()
      {:error, {:line_length_limit_exceeded, :status_line}}

      iex> reason_phrase = String.duplicate("A", 985)
      ...> {:more, _} = "HTTP/1.1 204 #{reason_phrase}\r\n"
      ...> |> Raxx.HTTP1.parse_response()
      ...> :ok
      :ok

      iex> reason_phrase = String.duplicate("A", 1985)
      ...> {:more, _} = "HTTP/1.1 204 #{reason_phrase}\r\n"
      ...> |> Raxx.HTTP1.parse_response(maximum_line_length: 2000)
      ...> :ok
      :ok

      iex> "HTTP/1.1 204 No Content\r\nfoo: #{String.duplicate("a", 994)}\r\n"
      ...> |> Raxx.HTTP1.parse_response()
      {:error, {:line_length_limit_exceeded, :header_line}}

      iex> {:more, _} = "HTTP/1.1 204 No Content\r\nfoo: #{String.duplicate("a", 993)}\r\n"
      ...> |> Raxx.HTTP1.parse_response()
      ...> :ok
      :ok

      iex> {:more, _} = "HTTP/1.1 204 No Content\r\nfoo: #{String.duplicate("a", 1993)}\r\n"
      ...> |> Raxx.HTTP1.parse_response(maximum_line_length: 2000)
      ...> :ok
      :ok

      # Test maximum number of headers is limited
      iex> "HTTP/1.1 204 No Content\r\n#{String.duplicate("foo: bar\r\n", 101)}"
      ...> |> Raxx.HTTP1.parse_response()
      {:error, :header_count_exceeded}

      # Test maximum number of headers is limited
      iex> "HTTP/1.1 204 No Content\r\n#{String.duplicate("foo: bar\r\n", 2)}"
      ...> |> Raxx.HTTP1.parse_response(maximum_headers_count: 1)
      {:error, :header_count_exceeded}
  """
  @spec parse_response(binary, [option]) ::
          {:ok, {Raxx.Response.t(), connection_status, body_read_state, binary}}
          | {:error, term}
          | {:more, :undefined}
        when option: {:maximum_line_length, integer}
  def parse_response(buffer, options \\ []) do
    maximum_line_length = Keyword.get(options, :maximum_line_length, @maximum_line_length)
    maximum_headers_count = Keyword.get(options, :maximum_headers_count, @maximum_headers_count)

    case :erlang.decode_packet(:http_bin, buffer, line_length: maximum_line_length) do
      {:ok, {:http_response, {1, 1}, status, _reason_phrase}, rest} ->
        case parse_headers(rest,
               maximum_line_length: maximum_line_length,
               maximum_headers_count: maximum_headers_count
             ) do
          {:ok, headers, rest2} ->
            {headers, body_present, body_read_state} = decode_payload(headers)

            {connection_status, headers} = decode_connection_status(headers)

            {:ok,
             {%Raxx.Response{status: status, headers: headers, body: body_present},
              connection_status, body_read_state, rest2}}

          {:error, reason} ->
            {:error, reason}

          {:more, :undefined} ->
            {:more, :undefined}
        end

      {:ok, {:http_error, invalid_line}, _rest} ->
        {:error, {:invalid_line, invalid_line}}

      {:error, :invalid} ->
        {:error, {:line_length_limit_exceeded, :status_line}}

      {:more, :undefined} ->
        {:more, :undefined}
    end
  end

  defp decode_payload(headers) do
    case Enum.split_with(headers, fn {key, _value} -> key == "transfer-encoding" end) do
      {[{"transfer-encoding", "chunked"}], headers} ->
        {headers, true, :chunked}

      {[], headers} ->
        case content_length(headers) do
          nuffink when nuffink in [nil, 0] ->
            {headers, false, {:complete, ""}}

          bytes ->
            {headers, true, {:bytes, bytes}}
        end
    end
  end

  defp decode_connection_status(headers) do
    case Enum.split_with(headers, fn {key, _value} -> key == "connection" end) do
      {[{"connection", value}], headers} ->
        case String.downcase(value) do
          "close" -> {:close, headers}
          "keep-alive" -> {:keepalive, headers}
        end

      {[], headers} ->
        {nil, headers}
    end
  end

  @doc ~S"""
  Serialize io_data as a single chunk to be streamed.

  ## Example

      iex> Raxx.HTTP1.serialize_chunk("hello")
      ...> |> to_string()
      "5\r\nhello\r\n"

      iex> Raxx.HTTP1.serialize_chunk("")
      ...> |> to_string()
      "0\r\n\r\n"
  """
  @spec serialize_chunk(iodata) :: iodata
  def serialize_chunk(data) do
    size = :erlang.iolist_size(data)
    [:erlang.integer_to_list(size, 16), "\r\n", data, "\r\n"]
  end

  @doc """
  Extract the content from a buffer with transfer encoding chunked
  """
  @spec parse_chunk(binary) :: {:ok, {binary | nil, binary}}
  def parse_chunk(buffer) do
    case String.split(buffer, "\r\n", parts: 2) do
      [base_16_size, rest] ->
        size =
          base_16_size
          |> :erlang.binary_to_list()
          |> :erlang.list_to_integer(16)

        case rest do
          <<chunk::binary-size(size), "\r\n", rest::binary>> ->
            {:ok, {chunk, rest}}

          _incomplete_chunk ->
            {:ok, {nil, buffer}}
        end

      [rest] ->
        {:ok, {nil, rest}}
    end
  end

  defp request_line(%Raxx.Request{method: method, raw_path: path, query: query}) do
    query_string = if query, do: ["?", query], else: ""
    [Atom.to_string(method), " ", path, query_string, " HTTP/1.1", @crlf]
  end

  defp status_line(%Raxx.Response{status: status}) do
    [
      "HTTP/1.1 ",
      Integer.to_string(status),
      " ",
      Raxx.reason_phrase(status),
      @crlf
    ]
  end

  defp header_lines(headers) do
    Enum.map(headers, &header_to_iolist/1)
  end

  defp header_to_iolist({key, value}) when is_binary(key) and is_binary(value) do
    [key, ": ", value, @crlf]
  end

  defp connection_headers(nil) do
    []
  end

  defp connection_headers(:close) do
    [{"connection", "close"}]
  end

  defp connection_headers(:keepalive) do
    [{"connection", "keep-alive"}]
  end

  defp payload(%{headers: headers, body: true}) do
    case content_length(headers) do
      nil ->
        {[{"transfer-encoding", "chunked"}], :chunked}

      content_length ->
        {[], {:bytes, content_length}}
    end
  end

  defp payload(message = %{body: false}) do
    payload(%{message | body: ""})
  end

  defp payload(%{headers: headers, body: iodata}) do
    payload_headers =
      case content_length(headers) do
        nil ->
          # NOTE `:erlang.iolist_size/1` accepts binaries, i.e. should be `:erlang.iodata_size/1`
          case :erlang.iolist_size(iodata) do
            0 ->
              []

            content_length ->
              [{"content-length", Integer.to_string(content_length)}]
          end

        _value ->
          # If a content-length is already set it is the callers responsibility to set the correct value
          []
      end

    {payload_headers, {:complete, iodata}}
  end

  defp content_length(headers) do
    case :proplists.get_all_values("content-length", headers) do
      [] ->
        nil

      [binary] ->
        {content_length, ""} = Integer.parse(binary)
        content_length
    end
  end
end
