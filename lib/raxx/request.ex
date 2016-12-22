defmodule Raxx.Request do
  @moduledoc """
  HTTP requests to a Raxx application are encapsulated in a `Raxx.Request` struct.

  A request has all the properties of the url it was sent to.
  In addition it has optional content, in the body.
  As well as a variable number of headers that contain meta data.

  where appropriate URI properties are named from this definition.

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

  @type cookies :: %{binary => binary}

  defstruct [
    scheme: nil,
    host: nil,
    port: nil,
    method: nil, # In ring/rack this is request_method
    mount: [],
    path: [], # This is path_info but is often used so be good to shorten
    query: %{}, # comes from the search string
    headers: [],
    body: nil
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
