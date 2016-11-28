defmodule Raxx.Request do
  @moduledoc """
  HTTP requests to a Raxx application are encapsulated in a `Raxx.Request` struct.

  The contents are itemised below:

  | **host** | The location of the hosting server, as a binary. e.g. `www.example.com`. |
  | **port** | The connection port on the server, as an integer. |
  | **method** | The HTTP request method, such as “GET” or “POST”, as a binary. This cannot ever be an empty string, and is always uppercase. |
  | **mount** | The segments of the request URL's “path”, that have already been matched. Same as rack path_info. This may be an empty array, if the requested URL targets the application root. |
  | **path** | The remainder of the request URL's “path”, split into segments. It designates the virtual “location” of the request's target within the application. This may be an empty array, if the requested URL targets the application root. |
  | **query** | The query parameters from the URL search string, formatted as a map of strings. |
  | **headers** | The headers from the HTTP request as a map of strings. Note all headers will be downcased, e.g. `%{"content-type" => "text/plain"}` |
  | **body** | The body content sent with the request |
  """

  @type request :: %__MODULE__{
    host: binary,
    port: :inet.port_number,
    method: binary,
    mount: [binary],
    path: [binary],
    query: %{binary => binary},
    headers: [{binary, binary}],
    body: binary
  }

  @type cookies :: %{binary => binary}

  defstruct [
    host: "www.example.com",
    port: 80,
    method: :GET, # In ring/rack this is request_method
    mount: [],
    path: [], # This is path_info but is often used so be good to shorten
    query: %{}, # comes from the search string
    headers: [],
    body: ""
  ]

  @doc """
  Fetches and parse cookies from the request.
  """
  @spec parse_cookies(request) :: cookies
  def parse_cookies(%{headers: headers}) do
    case Map.get(headers, "cookie") do
      nil -> Raxx.Cookie.parse([])
      cookie_string -> Raxx.Cookie.parse(cookie_string)
    end
  end

  @doc """
  get content, having parsed content type

  could alternativly have Request.form
  this should be extensible, have multipart form as a separate project
  # type spec, this should return an error for un parsable content
  """
  def content(request) do
    case content_type(request) do
      {"multipart/form-data", "boundary=" <> boundary} ->
        {:ok, parse_multipart_form_data(request.body, boundary)}
      {"application/x-www-form-urlencoded", _} ->
        {:ok, URI.decode_query(request.body)}
    end
  end

  @doc """
  content type is a field of type media type (same as Accept)
  https://tools.ietf.org/html/rfc7231#section-3.1.1.5

  Content type should be send with any content.
  If not can assume "application/octet-stream" or try content sniffing.
  because of security risks it is recommended to be able to disable sniffing
  """
  def content_type(%{headers: headers}) do
    case :proplists.get_value("content-type", headers) do
      :undefined ->
        :undefined
      media_type ->
        parse_media_type(media_type)
    end
  end

  @doc """
  https://tools.ietf.org/html/rfc7231#section-3.1.1.1
  """
  def parse_media_type(media_type) do
    case String.split(media_type, ";") do
      [type, modifier] ->
        {type, String.strip(modifier)}
      [type] ->
        {type, ""}
    end
  end

  defmodule Upload do
    # just need three parameters for upload
    # http://www.wooptoot.com/file-upload-with-sinatra
    # %Raxx.Upload{
    #   filename: "cat.png",
    #   type: "image/png",
    #   contents: "some text"
    # }
    # https://tools.ietf.org/html/rfc7578#section-4.1
    defstruct [:filename, :type, :content]
  end

  def parse_multipart_form_data(data, boundary) do
    ["" | parts] = String.split(data, "--" <> boundary)
    Enum.reduce(parts, [], fn
      ("--\r\n", data) ->
        data
      ("\r\n" <> part, data) ->
        {:ok, headers, body} = read_multipart_headers(part)
        "form-data;" <> params = :proplists.get_value("content-disposition", headers)
        [body, ""] = String.split(body, ~r"\r\n$")
        params = String.strip(params)
        params = Raxx.Cookie.parse([params])
        name = String.slice(Map.get(params, "name"), 1..-2)
        case Map.get(params, "filename") do
          nil ->
            data ++ [{name, body}]
          filename ->
            filename = String.slice(filename, 1..-2)
            data ++ [{name, %Upload{
              filename: filename,
              type: :proplists.get_value("content-type", headers),
              content: body
              }}]

        end
    end)
    |> Enum.into(%{})
  end

  def read_multipart_headers(part, headers \\ []) do
    case :erlang.decode_packet(:httph_bin, part, []) do
      {:ok, {:http_header, _, key, _, value}, rest} ->
        headers = [{String.downcase("#{key}"), value} | headers]
        {:ok, headers, body} = read_multipart_headers(rest, headers)
      {:ok, :http_eoh, rest} ->
        {:ok, Enum.reverse(headers), rest}
    end
  end

  @doc false
  # TODO test
  def parse_path(path_string) do
    case String.split(path_string, "?") do
      [path_string, query_string] ->
        {split_path(path_string), URI.decode_query(query_string)}
      [path_string] ->
        {split_path(path_string), %{}}
    end
  end

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
