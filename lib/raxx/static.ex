defmodule Raxx.Static do
  # other things this should do are
  # - send a response for a HEAD request
  # - return a method not allowed for other HTTP methods
  # - return content error from accept headers
  # - gzip encoding
  #   plug doesnt actually gzip it just assumes a file named path <>.gz
  #   gzip is assumed false by default, say true to generate gz from contents or path modification if zipped exists.
  #   https://groups.google.com/forum/#!topic/elixir-lang-talk/RL-qWWx9ILE
  # - have an overwritable not_found function
  # - cache control time
  # - Etags
  # - filtered reading of a file
  # - set a maximum size of file to bundle into the code.
  # - static_content(content, mime)
  # - check trying to serve root file
  # - use plug semantics of {:app, path/in/priv} or "/binary/absoulte" or "./binary/from/file"
  defmacro serve_file(filename, path) do
    quote do
      ast = unquote(__MODULE__).serve_file_ast(unquote(filename), unquote(path))
      Module.eval_quoted(__MODULE__, ast)
    end
  end

  def serve_file_ast(filename, path) do
    request_match = quote do: %{path: unquote(path)}
    mime = MIME.from_path(filename)
    # Should make use of Response.ok({file: filename})
    case File.read(filename) do
      {:ok, content} ->
        response = Raxx.Response.ok(content, [
          {"content-length", "#{:erlang.iolist_size(content)}"},
          {"content-type", mime}
        ])
        quote do
          def handle_request(request = unquote(request_match), _) do
            case request.method do
              :GET ->
                unquote(Macro.escape(response))
              _ ->
                Raxx.Response.method_not_allowed
            end
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
      # Make use of File.stat instead of just reading.
      for filename <- filenames do
        relative = Path.relative_to(filename, dir)
        path = Path.split(relative)
        Raxx.Static.serve_file(filename, path)
      end

      def handle_request(_,_) do
        Raxx.Response.not_found
      end
      # use a not found function if need be.
      # add option `Raxx.Static.serve_dir(dir, not_found: :not_found_cb)`
      # Or just don't include this at all and let people write the last handle_request callback
    end
  end
end
