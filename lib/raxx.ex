defmodule Raxx do
  @moduledoc """
  Tooling to work with HTTP.

  Several data structures are defined to model parts of the communication between client and server.

  - `Raxx.Request`: metadata sent by a client before sending content.
  - `Raxx.Response`: metadata sent by a server before sending content.
  - `Raxx.Fragment`: A part of a messages content.
  - `Raxx.Trailer`: metadata set by client or server to conclude communication.

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

      iex> request(:GET, "/").headers
      []

      iex> request(:GET, "/").body
      false
  """
  def request(method, url) when is_binary(url) do
    url = URI.parse(url)
    query = if url.query do
      Plug.Conn.Query.decode(url.query)
    end
    url = %{url | query: query}
    request(method, url)
  end
  def request(method, url) when method in @http_methods do
    scheme = if url.scheme do
      url.scheme |> String.to_existing_atom()
    end
    segments = split_path(url.path || "/")
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
  for {status_code, reason_phrase} <- HTTPStatus.every_status do
    reason = reason_phrase
    |> String.downcase
    |> String.replace(" ", "_")
    |> String.to_atom

    def response(unquote(reason)) do
      response(unquote(status_code))
    end
  end

  @doc """
  Construct a `Raxx.Fragment`

  A fragment encapsulates a section of message content that has been generated.
  If a stream has no trailers then the final fragment should mark the stream as ended.

  ## Examples

      iex> fragment("Hi").data
      "Hi"

      iex> fragment("Hi", true).end_stream
      true

      iex> fragment("Hi").end_stream
      false
  """
  def fragment(data, end_stream \\ false) do
    %Raxx.Fragment{data: data, end_stream: end_stream}
  end

  @doc """
  Construct a `Raxx.Trailer`

  ## Examples

      iex> trailer([{"digest", "opaque-data"}]).headers
      [{"digest", "opaque-data"}]
  """
  def trailer(headers) do
    %Raxx.Trailer{headers: headers}
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
    # TODO check lowercase
    # TODO fail if already set to different value
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
