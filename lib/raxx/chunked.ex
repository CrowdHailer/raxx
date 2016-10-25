defmodule Raxx.Chunked do
  @moduledoc """
  Module for handling a response served in chunks.

  A chunked response needs to upgrade the Raxx handler.
  This handler needs to implement the additional `handle_info/2` callback.

  The chunked handler may be the same module as the request handler.

  The contents are itemised below:

  | **handler** | The module that implements the required callbacks to send a response in 1 or more chunks |
  | **state** | Any state that the handle_info callback might need. |
  | **initial** | TODO The first chunk to be streamed to the client, by default an empty string. |
  | **headers** | TODO Any additional headers to add to the response that is sent to the client. |

  """
  # For SSE
  # Headers to initial HTTP streaming are automatically set `%{"cache-control" => "no-cache", "connection" => "keep-alive"}`
  defstruct [app: nil, headers: []]

  def upgrade(app, opts) do
    struct(%__MODULE__{app: app}, opts)
  end

  def to_packet(data) do
    size = :erlang.iolist_size(data)
    packet = [:erlang.integer_to_list(size, 16), "\r\n", data, "\r\n"]
  end

  def end_chunk do
    "0\r\n\r\n"
  end
end
