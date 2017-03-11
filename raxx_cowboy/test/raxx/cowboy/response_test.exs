defmodule Raxx.Cowboy.ResponseTest do
  use Raxx.Verify.ResponseCase

  setup %{case: case, test: test} do
    name = {case, test}
    raxx_app = {__MODULE__, %{target: self()}}

    Raxx.Cowboy.start_link(raxx_app, port: 0, name: name, acceptors: 2)
    {:ok, %{port: :ranch.get_port(name)}}
  end

end
