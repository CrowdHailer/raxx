defmodule Raxx.Static do
  defmacro __using__(opts) do
    # No real idea about why `unquote: false` works here.
    # It seams to and I think it is related to the fact that def is a macro
    # A clearer version of this code would be great.

    quote unquote: false do
      dir = Path.expand("./static", Path.dirname(__ENV__.file))
      files = Path.expand("./**/*", dir) |> Path.wildcard

      for file <- files do
        case File.read(file) do
          {:ok, content} ->
            relative = Path.relative_to(file, dir)
            path = Path.split(relative)
            mime = MIME.from_path(file)

            def handle_request(r = %{path: (unquote(path))}, _) do
              Raxx.Response.ok(unquote(content), [
                {"content-length", "#{:erlang.iolist_size(unquote(content))}"},
                {"content-type", unquote(mime)}
              ])
            end
        end
        def handle_request(_, _) do
          Raxx.Response.not_found
        end
      end
    end
  end
end
