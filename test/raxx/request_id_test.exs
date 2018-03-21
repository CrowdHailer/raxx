defmodule Raxx.RequestIDTest do
  use ExUnit.Case
  import Raxx
  import Raxx.RequestID

  doctest Raxx.RequestID

  test "uuid is generate for request with no id" do
    request = request(:GET, "/")

    {id, new_request} = ensure_request_id(request)
    assert id == get_header(new_request, "x-request-id")
  end

  test "uuid is generate for request with invalid id" do
    request =
      request(:GET, "/")
      |> set_header("x-request-id", "123")

    {id, new_request} = ensure_request_id(request)
    assert id == get_header(new_request, "x-request-id")
    assert id != "123"
  end
end
