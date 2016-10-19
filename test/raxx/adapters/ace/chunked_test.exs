defmodule Raxx.Ace.ChunkedTest do
  use Raxx.Adapters.ChunkedCase

  setup do
    raxx_app = {__MODULE__, %{chunks: ["Hello,", " ", "World", "!"]}}
    {:ok, endpoint} = Ace.TCP.start_link({Raxx.Adapters.Ace.Handler, raxx_app}, port: 0)
    {:ok, port} = Ace.TCP.Endpoint.port(endpoint)
    {:ok, %{port: port}}
  end

end
