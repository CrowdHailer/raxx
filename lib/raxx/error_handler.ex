defmodule Raxx.ErrorHandler do
  @moduledoc """
  It might make sense for this to be called something else, i.e. error handler.
  The aim is to ensure a productive 500/404 call is returned to the user.
  The formatting of this information is separate

  Handling the case of a missing route would be nice, in that case return a 404
  This could be done on matching on the stack trace.

  ```elixir
  try do
  next.handle_request(request, %{})
  catch
    kind = :error, reason = :function_clause ->
      stacktrace = System.stacktrace
      [{mod, func, args, location} | rest] = System.stacktrace
  end
  ```

  asserting that func == :handle_request
  asserting that args are length 2.

  Elixir exceptions can be caught with rescue, however throws and exits need a catch block.
  exceptions will also be caught in catch blocks.
  Elixir.Exception.normalize can be used to turn caugth errors to exceptions
  """

  def handle_request(request, %{next: next}) do
    try do
      next.handle_request(request, %{})
    catch
      kind, reason ->
        stacktrace = System.stacktrace
        error_page(request, {kind, reason, stacktrace}, next)
    end
  end

  def error_page(request, error = {kind, reason, stacktrace}, state) do
    reason = Exception.normalize(kind, reason, stacktrace)
    {title, message} = case {kind, reason} do
      {:error, exception} ->
        {inspect(exception.__struct__), Exception.message(exception)}
      {:throw, thrown} ->
        {"unhandled throw", inspect(thrown)}
      {:exit, reason} ->
        {"unhandled exit", Exception.format_exit(reason)}
    end

    method = request.method
    path = "/" <> Enum.join(request.path, "/")

    # IO.inspect(__ENV__)
    frames = stacktrace |> Enum.map(&norm_stack/1)

    Raxx.Response.internal_server_error("""
    <p>title: #{title}</p>
    <p>message: #{message}</p>
    <p>method: #{method}</p>
    <p>path: #{path}</p>
    <p>frames: #{inspect(frames)}</p>
    """)
    |> Map.merge(%{error: error})
  end

  def norm_stack(entry) do
    {module, info, location, app, func, args} = get_entry(entry)
    {file, line} = {to_string(location[:file] || "nofile"), location[:line]}

    root = :todo_myapp
    source  = get_source(module, file)
    context = get_context(root, app)
    snippet = get_snippet(source, line)
    %{
      app: app,
      info: info,
      file: file,
      line: line,
      context: context,
      snippet: snippet,
      # index: index,
      func: func,
      args: args,
    }
  end

  # From :elixir_compiler_*
  defp get_entry({module, :__MODULE__, 0, location}) do
    {module, inspect(module) <> " (module)", location, get_app(module), nil, []}
  end

  # From :elixir_compiler_*
  defp get_entry({_module, :__MODULE__, 1, location}) do
    {nil, "(module)", location, nil, nil, []}
  end

  # From :elixir_compiler_*
  defp get_entry({_module, :__FILE__, 1, location}) do
    {nil, "(file)", location, nil, nil, []}
  end

  defp get_entry({module, fun, args, location}) when is_list(args) do
    {module, Exception.format_mfa(module, fun, length(args)), location, get_app(module), fun, args}
  end

  defp get_entry({module, fun, arity, location}) do
    {module, Exception.format_mfa(module, fun, arity), location, get_app(module), fun, []}
  end

  defp get_entry({fun, arity, location}) do
    {nil, Exception.format_fa(fun, arity), location, nil, fun, []}
  end

  defp get_app(module) do
    case :application.get_application(module) do
      {:ok, app} -> app
      :undefined -> nil
    end
  end

  defp get_context(app, app) when app != nil, do: :app
  defp get_context(_app1, _app2),             do: :all

  defp get_source(module, file) do
    cond do
      File.regular?(file) ->
        file
      source = Code.ensure_loaded?(module) && module.module_info(:compile)[:source] ->
        to_string(source)
      true ->
        file
    end
  end

  @radius 5

  defp get_snippet(file, line) do
    if File.regular?(file) and is_integer(line) do
      to_discard = max(line - @radius - 1, 0)
      lines = File.stream!(file) |> Stream.take(line + 5) |> Stream.drop(to_discard)

      {first_five, lines} = Enum.split(lines, line - to_discard - 1)
      first_five = with_line_number first_five, to_discard + 1, false

      {center, last_five} = Enum.split(lines, 1)
      center = with_line_number center, line, true
      last_five = with_line_number last_five, line + 1, false

      first_five ++ center ++ last_five
    end
  end

  defp with_line_number(lines, initial, highlight) do
    Enum.map_reduce(lines, initial, fn(line, acc) ->
      {{acc, line, highlight}, acc + 1}
    end) |> elem(0)
  end
end
