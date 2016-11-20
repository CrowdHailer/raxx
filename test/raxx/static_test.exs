defmodule Raxx.StaticTest do
  defmodule Assets do
    use Raxx.Static
  end

  use ExUnit.Case

  test "Correct file contents is served" do
    request = %Raxx.Request{path: ["hello.txt"]}
    response = Assets.handle_request(request, [])
    assert "Hello, World!\n" == response.body
  end

  test "A file is served with a 200 response" do
    request = %Raxx.Request{path: ["hello.txt"]}
    response = Assets.handle_request(request, [])
    assert 200 == response.status
  end

  test "A text file is served with the correct content type" do
    request = %Raxx.Request{path: ["hello.txt"]}
    response = Assets.handle_request(request, [])
    assert {"content-type", "text/plain"} == List.keyfind(response.headers, "content-type", 0)
  end

  test "A css file is served with the correct content type" do
    request = %Raxx.Request{path: ["site.css"]}
    response = Assets.handle_request(request, [])
    IO.inspect(response)
    assert {"content-type", "text/plain"} == List.keyfind(response.headers, "content-type", 0)
  end

  test "No file results in 404 response" do
    request = %Raxx.Request{path: ["nope.txt"]}
    response = Assets.handle_request(request, [])
    assert 404 == response.status
  end
end
