defmodule Raxx.Chunked do
  defstruct [app: nil]

  def upgrade(app) do
    struct(__MODULE__, app: app)
  end

  def to_packet(data) do
    size = :erlang.iolist_size(data)
    packet = [:erlang.integer_to_list(size), "\r\n", data, "\r\n"]
  end

  def end_chunk do
    "0\r\n\r\n"
  end
end
