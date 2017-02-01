defmodule Ace.HTTP.ResponseTest do
  use Raxx.Verify.ResponseCase

  setup do
    raxx_app = {__MODULE__, %{target: self()}}
    {:ok, endpoint} = Ace.HTTP.start_link(raxx_app, port: 0)
    {:ok, port} = Ace.HTTP.port(endpoint)
    {:ok, %{port: port}}
  end

end
