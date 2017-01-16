defmodule Raxx.Adapters.Ace.ChunkedTest do
  use Raxx.Adapters.ChunkedCase

  setup do
    raxx_app = {__MODULE__, %{chunks: ["Hello,", " ", "World", "!"]}}
    {:ok, endpoint} = Ace.HTTP.start_link(raxx_app, port: 0)
    {:ok, port} = Ace.HTTP.port(endpoint)
    {:ok, %{port: port}}
  end

end
