defmodule Raxx do
  @moduledoc """
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
    url = %{url | query: Plug.Conn.Query.decode(url.query || "")}
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
  Does the message struct contain all the data to be sent.
  """
  def complete?(%{body: body}) when is_binary(body) do
    true
  end
  def complete?(%{body: body}) do
    !body
  end

  @doc """
  Add a query value to a request

  Examples
      # TODO
      # iex> get({"/", %{foo: "bar"}}).query
      # %{"foo" => "bar"}
  """
  def set_query(request = %Raxx.Request{}, query) do
    %{request | query: query}
  end

  # get_header

  @doc """
      # iex> get("/", [{"referer", "/home"}]).headers
      # [{"referer", "/home"}]
  """
  def set_header(request = %{headers: headers}, name, value) do
    # TODO check lowercase
    # TODO fail if already set to different value
    %{request | headers: headers ++ [{name, value}]}
  end

  def set_body(request, body) do
    # TODO raise if body already set
    %{request | body: body}
  end

  # def set_header(r, name, value) do
  #   if has_header?(r, name) do
  #     raise "set only once"
  #   end
  # end


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
