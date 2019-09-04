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
  | **method** | The HTTP request method, such as `:GET` or `:POST`, as an atom. This cannot ever be `nil`. It is always uppercase. |
  | **path** | The remainder of the request URL's “path”, split into segments. It designates the virtual “location” of the request's target within the application. This may be an empty array, if the requested URL targets the application root. |
  | **raw_path** | The request URL's "path" |
  | **query** | the URL query string. |
  | **headers** | The headers from the HTTP request as a proplist of strings. Note all headers will be downcased, e.g. `[{"content-type", "text/plain"}]` |
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
          path: [binary],
          raw_path: binary,
          query: binary | nil,
          headers: Raxx.headers(),
          body: Raxx.body()
        }

  defstruct scheme: nil,
            authority: nil,
            method: nil,
            path: [],
            raw_path: "",
            query: nil,
            headers: [],
            body: nil

  @default_ports %{
    http: 80,
    https: 443
  }

  @doc """
  Return the host value for the request.

  The `t:Raxx.Request.t/0` struct contains `authority` field, which
  may contain the port number. This function returns the host value which
  won't include the port number.
  """
  def host(%__MODULE__{authority: authority}) do
    hd(String.split(authority, ":"))
  end

  @doc """
  Return the port number used for the request.

  If no port number is explicitly specified in the request url, the 
  default one for the scheme is used.
  """
  @spec port(t, %{optional(atom) => :inet.port_number()}) :: :inet.port_number()
  def port(%__MODULE__{scheme: scheme, authority: authority}, default_ports \\ @default_ports) do
    case String.split(authority, ":") do
      [_host] ->
        Map.get(default_ports, scheme)

      [_host, port_string] ->
        case Integer.parse(port_string) do
          {port, _} when port in 0..65535 ->
            port
        end
    end
  end

  @doc """
  Returns an `URI` struct corresponding to the url used in the provided request.

  **NOTE**: the `userinfo` field of the `URI` will always be `nil`, even if there
  is `Authorization` header basic auth information contained in the request.

  The `fragment` will also be `nil`, as the servers don't have access to it.
  """
  @spec uri(t) :: URI.t()
  def uri(%__MODULE__{} = request) do
    scheme =
      case request.scheme do
        nil -> nil
        atom when is_atom(atom) -> Atom.to_string(atom)
      end

    %URI{
      authority: request.authority,
      host: Raxx.request_host(request),
      path: request.raw_path,
      port: port(request),
      query: request.query,
      scheme: scheme,
      # you can't provide userinfo in a http request url (anymore)
      # pulling it out of Authorization headers would go against the
      # main use-case for this function
      userinfo: nil
    }
  end
end
