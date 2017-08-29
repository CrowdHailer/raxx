defmodule Raxx.Cowboy.RequestTest do
  use Raxx.Verify.RequestCase

  setup %{case: case, test: test} do
    name = {case, test}
    raxx_app = {Raxx.Verify.Forwarder, %{target: self()}}

    Raxx.Cowboy.start_link(raxx_app, port: 0, name: name, acceptors: 2)
    {:ok, %{port: :ranch.get_port(name)}}
  end
end
