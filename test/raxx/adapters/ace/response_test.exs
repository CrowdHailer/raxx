defmodule Raxx.Adapters.Ace.ResponseTest do
  use Raxx.Adapters.ResponseCase

  setup do
    raxx_app = {__MODULE__, %{target: self()}}
    {:ok, endpoint} = Ace.HTTP.start_link(raxx_app, port: 0)
    {:ok, port} = Ace.HTTP.port(endpoint)
    {:ok, %{port: port}}
  end

end
