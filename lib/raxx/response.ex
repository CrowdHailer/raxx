defmodule Raxx.Response do
  @moduledoc """
  HTTP responses from a Raxx application are encapsulated in a `Raxx.Response` struct.

  The contents are itemised below:

  | **status** | The HTTP status code for the response: `1xx, 2xx, 3xx, 4xx, 5xx` |
  | **headers** | The response headers as a list: `[{"content-type", "text/plain"}` |
  | **body** | The response body, by default an empty string. |

  """

  @typedoc """
  Integer code for server response type
  """
  @type status :: integer

  @typedoc """
  Elixir representation for an HTTP response.
  """
  @type t :: %__MODULE__{
          status: status,
          headers: [Raxx.header()],
          body: boolean | String.t()
        }

  @enforce_keys [:status, :headers, :body]
  defstruct @enforce_keys

  # DEBT I never used these, will they be missed?
  # @doc """
  # The response is marked as an interim response.
  #
  # https://tools.ietf.org/html/rfc7231#section-6.2
  # """
  # def informational?(%{status: code}), do: 100 <= code and code < 200
  #
  # @doc """
  # The response indicates that client request was received, understood, and accepted.
  #
  # https://tools.ietf.org/html/rfc7231#section-6.3
  # """
  # def success?(%{status: code}), do: 200 <= code and code < 300
  #
  # @doc """
  # The response indicates that further action needs to be taken by the client.
  #
  # https://tools.ietf.org/html/rfc7231#section-6.4
  # """
  # def redirect?(%{status: code}), do: 300 <= code and code < 400
  #
  # @doc """
  # The response indicates that the client sent an incorrect request.
  #
  # https://tools.ietf.org/html/rfc7231#section-6.5
  # """
  # def client_error?(%{status: code}), do: 400 <= code and code < 500
  #
  # @doc """
  # The response indicates that the server is incapable of acting upon the request.
  #
  # https://tools.ietf.org/html/rfc7231#section-6.6
  # """
  # def server_error?(%{status: code}), do: 500 <= code and code < 600
end
