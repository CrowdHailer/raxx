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

  def handle_request(request, env = %{next: next}) do
    app = Map.get(env, :app)
    try do
      next.handle_request(request, %{})
    catch
      kind, reason ->
        stacktrace = System.stacktrace
        Raxx.DebugPage.html(request, {kind, reason, stacktrace}, app)
        |> Raxx.Response.internal_server_error
    end
  end


end
