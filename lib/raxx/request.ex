defmodule Raxx.Request do
  @moduledoc """
  HTTP requests to a Raxx application are encapsulated in a `Raxx.Request` struct.

  The contents are itemised below:

  | **host** | The location of the hosting server, as a binary. e.g. `www.example.com`. |
  | **port** | The connection port on the server, as an integer. |
  | **method** | The HTTP request method, such as “GET” or “POST”, as a binary. This cannot ever be an empty string, and is always uppercase. |
  | **path** | The remainder of the request URL's “path”, split into segments. It designates the virtual “location” of the request's target within the application. This may be an empty array, if the requested URL targets the application root. |
  | **query** | The query parameters from the URL search string, formatted as a map of strings. |
  | **headers** | The headers from the HTTP request as a map of strings. Note all headers will be downcased, e.g. `%{"content-type" => "text/plain"}` |
  | **body** | The body content sent with the request |
  """

  @type request :: %__MODULE__{
    host: binary,
    port: :inet.port_number,
    method: binary,
    path: [binary],
    query: %{binary => binary},
    headers: %{binary => binary}, # FIXME %{binary => [binary]},
    body: binary
  }

  @type cookies :: %{binary => binary}

  defstruct [
    host: "www.example.com",
    port: 80,
    method: "GET", # In ring/rack this is request_method
    path: [], # This is path_info but is often used so be good to shorten
    query: %{}, # comes from the search string
    headers: %{},
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
