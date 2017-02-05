defmodule Raxx.StaticTest do
  defmodule SingleFile do
    require Raxx.Static

    dir = "./static"
    Raxx.Static.serve_dir(dir)
  end

  use ExUnit.Case

  test "Correct file contents is served" do
    request = %Raxx.Request{method: :GET, path: ["hello.txt"]}
    response = SingleFile.handle_request(request, [])
    assert "Hello, World!\n" == response.body
  end

  test "A file is served with a 200 response" do
    request = %Raxx.Request{method: :GET, path: ["hello.txt"]}
    response = SingleFile.handle_request(request, [])
    assert 200 == response.status
  end

  test "A file is served with the correct content length" do
    request = %Raxx.Request{method: :GET, path: ["hello.txt"]}
    response = SingleFile.handle_request(request, [])
    assert {"content-length", "14"} == List.keyfind(response.headers, "content-length", 0)
  end

  test "A text file is served with the correct content type" do
    request = %Raxx.Request{method: :GET, path: ["hello.txt"]}
    response = SingleFile.handle_request(request, [])
    assert {"content-type", "text/plain"} == List.keyfind(response.headers, "content-type", 0)
  end

  test "A css file is served with the correct content type" do
    request = %Raxx.Request{method: :GET, path: ["site.css"]}
    response = SingleFile.handle_request(request, [])
    assert {"content-type", "text/css"} == List.keyfind(response.headers, "content-type", 0)
  end

  test "files in subdirectories are  found" do
    request = %Raxx.Request{method: :GET, path: ["sub", "file.txt"]}
    response = SingleFile.handle_request(request, [])
    assert 200 == response.status
  end

  test "invalid method returns a 405 Not Allowed" do
    request = %Raxx.Request{path: ["hello.txt"], method: :POST}
    response = SingleFile.handle_request(request, [])
    assert 405 == response.status
  end

end
