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
  def response(status_code) when is_integer(status_code) do
    struct(Raxx.Response, status: status_code, headers: [], body: false)
  end

  filepath = Path.join(__DIR__, "status.rfc7231")
  @external_resource filepath
  {:ok, file} = File.read(filepath)
  status_lines = String.split(String.trim(file), ~r/\R/)
  statuses = status_lines |> Enum.map(fn(status_line) ->
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
  def set_query(request = %Raxx.Request{query: nil}, query) do
    %{request | query: query}
  end

  # get_header
  # def set_header(r, name, value) do
  #   if has_header?(r, name) do
  #     raise "set only once"
  #   end
  # end

  @doc """
  Set the value of a header field.

  ## Examples

      iex> request(:GET, "/")
      ...> |> set_header("referer", "example.com")
      ...> |> set_header("accept", "text/html")
      ...> |> Map.get(:headers)
      [{"referer", "example.com"}, {"accept", "text/html"}]
  """
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
  Add a complete body to a message.

  ## Examples

      iex> request(:GET, "/")
      ...> |> set_body("Hello")
      ...> |> Map.get(:body)
      "Hello"
  """
  def set_body(message = %{body: false}, body) do
    %{message | body: body}
  end

  @doc """
  Split a path on forward slashes.

  ## Examples

      iex> split_path("/foo/bar")
      ["foo", "bar"]

  """
  def split_path(path_string) do
    path_string
    |> String.split("/", [trim: true])
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
