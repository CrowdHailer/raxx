defmodule CORSTest do
  use ExUnit.Case
  doctest CORS

  def test_config do
    %{
      origins: ["other.example.com"],
      # TODO default PUT PATCH DELETE
      allow_methods: ["PUT"],
      # headers than can be sent by the request
      allow_headers: [],
      # headers that the client can use in a response
      expose_headers: []
    }
  end
end
