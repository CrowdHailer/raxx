defmodule Raxx.Adapters.Ace.ResponseTest do
  use Raxx.Adapters.ResponseCase

  setup do
    raxx_app = {__MODULE__, %{target: self()}}
    {:ok, endpoint} = Ace.TCP.start_link({Raxx.Adapters.Ace.Handler, raxx_app}, port: 0)
    {:ok, port} = Ace.TCP.Endpoint.port(endpoint)
    {:ok, %{port: port}}
  end

end
