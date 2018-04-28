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
  @type status_code :: integer

  @typedoc """
  Elixir representation for an HTTP response.
  """
  @type t :: %__MODULE__{
          status: status_code,
          headers: Raxx.headers(),
          body: Raxx.body()
        }

  @enforce_keys [:status, :headers, :body]
  defstruct @enforce_keys
end
