defmodule Raxx.Cowboy.ChunkedTest do
  use Raxx.Verify.ChunkedCase

  setup %{case: case, test: test} do
    name = {case, test}
    raxx_app = {__MODULE__, %{chunks: ["Hello,", " ", "World", "!"]}}

    Raxx.Cowboy.start_link(raxx_app, port: 0, name: name, acceptors: 2)
    {:ok, %{port: :ranch.get_port(name)}}
  end

end
