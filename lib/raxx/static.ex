defmodule Raxx.Static do
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
  # - static_content(content, mime)
  defmacro serve_file(filename, path) do
    quote do
      ast = unquote(__MODULE__).serve_file_ast(unquote(filename), unquote(path))
      Module.eval_quoted(__MODULE__, ast)
    end
  end

  def serve_file_ast(filename, path) do
    request_match = quote do: %{path: unquote(path)}
    mime = MIME.from_path(filename)
    case File.read(filename) do
      {:ok, content} ->
        response = Raxx.Response.ok(content, [
          {"content-length", "#{:erlang.iolist_size(content)}"},
          {"content-type", mime}
        ])
        quote do
          def handle_request(unquote(request_match), _) do
            unquote(Macro.escape(response))
          end
        end
      {:error, :eisdir} ->
        nil
    end
  end

  defmacro serve_dir(dir) do
    quote do
      dir = Path.expand(unquote(dir), Path.dirname(__ENV__.file))
      filenames = Path.expand("./**/*", dir) |> Path.wildcard
      for filename <- filenames do
        relative = Path.relative_to(filename, dir)
        path = Path.split(relative)
        Raxx.Static.serve_file(filename, path)
      end

      def handle_request(_,_) do
        Raxx.Response.not_found
      end
    end
  end
end
