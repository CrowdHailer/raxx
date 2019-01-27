defmodule Raxx.Context.ServerContext do
  @typedoc """
  `"http1.1" | "http2"`
  """
  @type http_version :: String.t()
  @type transport :: :tls | :tcp
  @type ip_address :: :inet.ip4_address() | :inet.ip6_address()
  @type port_number :: :inet.port_number()

  @moduledoc """
  The server context is a place where the HTTP Server implementing the
  Raxx interface can put arbitrary information that doesn't fit elsewhere.
  That could be anything from low-level network information to
  server-specific debug information.

  ## Standard fields

  There's a number of standard properties that are common between HTTP servers.
  If a server is to put any of them in the server context, it should follow
  the standard format:

  | *map key* | *type* | *description* |
  | `:remote_ip_address` | `t:ip_address/0` | the ip address of the remote machine |
  | `:local_port_number` | `t:port_number/0` | the local port number where the request was sent |
  | `:transport` | `t:transport/0` | indicates whether tls/ssl was used |
  | `:http_version` | `t:http_version/0` | indicates if the request was sent using HTTP/1.1 or HTTP/2 |


  To see what values will be set in your case, consult the documentation
  of the HTTP server you're using.
  """

  @doc """
  Retrieves the server context.

  If no server context was set before, will return an empty map.
  """
  @spec retrieve() :: map()
  def retrieve() do
    Raxx.Context.retrieve(__MODULE__, %{})
  end

  @doc """
  Sets the value of the server context.

  Returns the previous value of the server context or an empty map
  if one was not set.
  """
  @spec set(map()) :: map()
  def set(%{} = server_context) do
    Raxx.Context.set(__MODULE__, server_context)
  end
end
