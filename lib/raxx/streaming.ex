defmodule Raxx.Streaming do
  @moduledoc """
  The intention to respond to a request with HTTP streaming is encapsulated in a `Raxx.Streaming` struct.

  The contents are itemised below:

  | **handler** | The module that implements the required callbacks to handle a streaming connection |
  | **environment** | Any state that the handle_info callback might need. |
  | **initial** | The first chunk to be streamed to the client, by default an empty string. |
  | **headers** | Any additional headers to add to the response that is sent to the client. |

  Callback names do not clash so the streaming handler can be the same module as the request handler.

  Headers to initial HTTP streaming are automatically set `%{"cache-control" => "no-cache", "connection" => "keep-alive"}`
  """
  defstruct [handler: nil, environment: nil, initial: "", headers: %{}]

  @doc """
  Create an upgrade object for the server.
  Indicates that the response will be sent in chunks.
  """
  def upgrade(mod, env, opts \\ %{}) do
    struct(%__MODULE__{handler: mod, environment: env}, opts)
  end
end
