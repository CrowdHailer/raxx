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
