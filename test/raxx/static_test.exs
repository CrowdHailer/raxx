defmodule Raxx.StaticTest do
  # defmodule SingleFile do
  #   require Raxx.Static
  #
  #   dir = Path.expand("./static", Path.dirname(__ENV__.file))
  #   filenames = Path.expand("./**/*", dir) |> Path.wildcard
  #
  #   for filename <- filenames do
  #     relative = Path.relative_to(filename, dir)
  #     path = Path.split(relative)
  #     Raxx.Static.serve_file(filename, path)
  #   end
  #
  #   def handle_request(_, _) do
  #     Raxx.Response.not_found()
  #   end
  # end
  defmodule SingleFile do
    require Raxx.Static

    dir = "./static"
    Raxx.Static.serve_dir(dir)
  end

  use ExUnit.Case

  test "Correct file contents is served" do
    request = %Raxx.Request{path: ["hello.txt"]}
    response = SingleFile.handle_request(request, [])
    assert "Hello, World!\n" == response.body
  end

  test "A file is served with a 200 response" do
    request = %Raxx.Request{path: ["hello.txt"]}
    response = SingleFile.handle_request(request, [])
    assert 200 == response.status
  end

  test "A text file is served with the correct content type" do
    request = %Raxx.Request{path: ["hello.txt"]}
    response = SingleFile.handle_request(request, [])
    assert {"content-type", "text/plain"} == List.keyfind(response.headers, "content-type", 0)
  end

  test "A css file is served with the correct content type" do
    request = %Raxx.Request{path: ["site.css"]}
    response = SingleFile.handle_request(request, [])
    assert {"content-type", "text/css"} == List.keyfind(response.headers, "content-type", 0)
  end

  test "No file results in 404 response" do
    request = %Raxx.Request{path: ["nope.txt"]}
    response = SingleFile.handle_request(request, [])
    assert 404 == response.status
  end

  test "directorys are not found" do
    request = %Raxx.Request{path: ["sub"]}
    response = SingleFile.handle_request(request, [])
    assert 404 == response.status
  end

  test "files in subdirectories are  found" do
    request = %Raxx.Request{path: ["sub", "file.txt"]}
    response = SingleFile.handle_request(request, [])
    assert 200 == response.status
  end

end
