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

  # TODO docs
  def host(%__MODULE__{authority: authority}) do
    hd(String.split(authority, ":"))
  end

  # TODO docs
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

  # TODO docs
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
      # pulling it out of Authorization headers would go agains the
      # main use-case for this function
      userinfo: nil
    }
  end
end
