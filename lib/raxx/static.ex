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
  defmacro serve_file(filename, path) do
    quote do
      ast = unquote(__MODULE__).serve_file_ast(unquote(filename), unquote(path))
      Module.eval_quoted(__MODULE__, ast)
    end
  end

  def serve_file_ast(filename, path) do
    request = quote do: request = %{path: unquote(path), method: method}
    {:ok, content} = File.read(filename)
    mime = MIME.from_path(filename)
    response = Raxx.Response.ok(content, [
      {"content-length", "#{:erlang.iolist_size(content)}"},
      {"content-type", mime}
    ])
    quote do
      def handle_request(unquote(request), _) do
        unquote(Macro.escape(response))
      end
    end
  end
end
