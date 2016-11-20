defmodule Raxx.StaticTest do
  defmodule Assets do
    asset_dir = Path.expand("./static", Path.dirname(__ENV__.file))
    assets = Path.expand("./**/*", asset_dir) |> Path.wildcard
    IO.inspect(assets)

    # other things this should do are
    # - send a response for a HEAD request
    # - return a method not allowed for other HTTP methods
    # - return content error from accept headers
    # - gzip encoding
    # - have an overwritable not_found function
    # - cache control time
    # - Etags
    # - filtered reading of a file
    # - set a maximum size of file to bundle into the code.

    for asset <- assets do
      case File.read(asset) do
        {:ok, content} ->
          relative = Path.relative_to(asset, asset_dir)
          path = Path.split(relative)
          mime = MIME.from_path(asset)

          response = Raxx.Response.ok(content, [
            {"content-length", "#{:erlang.iolist_size(content)}"},
            {"content-type", mime}
          ])
          def handle_request(%{path: unquote(path)}, _) do
            unquote(Macro.escape(response))
          end |> IO.inspect

        {:error, reason} ->
          IO.inspect(reason)
      end
    end

    def handle_request(_, _) do
      Raxx.Response.not_found()
    end
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
    assert {"content-type", "text/css"} == List.keyfind(response.headers, "content-type", 0)
  end

  test "No file results in 404 response" do
    request = %Raxx.Request{path: ["nope.txt"]}
    response = Assets.handle_request(request, [])
    assert 404 == response.status
  end

end
