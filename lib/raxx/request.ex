defmodule Raxx.Request do
  @moduledoc """
  HTTP requests to a Raxx application are encapsulated in a `Raxx.Request` struct.

  A request has all the properties of the url it was sent to.
  In addition it has optional content, in the body.
  As well as a variable number of headers that contain meta data.

  Where appropriate URI properties are named from this definition.

  > scheme:[//[user:password@]host[:port]][/]path[?query][#fragment]

  from [wikipedia](https://en.wikipedia.org/wiki/Uniform_Resource_Identifier#Syntax)

  The contents are itemised below:

  | **scheme** | `http` or `https`, depending on the transport used. |
  | **authority** | The location of the hosting server, as a binary. e.g. `www.example.com`. Plus an optional port number, separated from the hostname by a colon |
  | **method** | The HTTP request method, such as “GET” or “POST”, as a binary. This cannot ever be an empty string, and is always uppercase. |
  | **mount** | The segments of the request URL's “path”, that have already been matched. Same as rack path_info. This may be an empty array, if the requested URL targets the application root. |
  | **path** | The remainder of the request URL's “path”, split into segments. It designates the virtual “location” of the request's target within the application. This may be an empty array, if the requested URL targets the application root. |
  | **query** | the URL query string. |
  | **headers** | The headers from the HTTP request as a map of strings. Note all headers will be downcased, e.g. `%{"content-type" => "text/plain"}` |
  | **body** | The body content sent with the request |

  """

  @typedoc """
  Method to indicate the desired action to be performed on the identified resource.
  """
  @type method :: atom

  @typedoc """
  Scheme describing protocol used.
  """
  @type scheme :: :http | :https

  @typedoc """
  Elixir representation for an HTTP request.
  """
  @type t :: %__MODULE__{
          scheme: scheme,
          authority: binary,
          method: method,
          mount: [binary],
          path: [binary],
          query: binary | nil,
          headers: Raxx.headers(),
          body: Raxx.body()
        }

  defstruct scheme: nil,
            authority: nil,
            method: nil,
            mount: [],
            path: [],
            query: nil,
            headers: [],
            body: nil
end
