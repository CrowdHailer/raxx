defmodule TroubleApp do
  def handle_request(%{path: []}, _env) do
    Raxx.Response.ok("Dandy")
  end

  def handle_request(%{path: ["throw"]}, _env) do
    throw :catch_this
  end
end


defmodule Raxx.DebuggerTest do
  alias Raxx.ErrorHandler
  use ExUnit.Case


  test "will return request if no problems" do
    response = ErrorHandler.handle_request(%Raxx.Request{path: []}, %{next: TroubleApp})
    assert 200 = response.status
    assert "Dandy" = response.body
  end

  @tag :skip
  test "handling a throw" do
    response = Raxx.ErrorHandler.handle_request(Raxx.Test.get("/throw"), %{next: TroubleApp})
    assert 500 = response.status
    assert response.body =~ "<p>title: unhandled throw</p>"
    assert response.body =~ "<p>message: :catch_this</p>"
    assert response.body =~ "<p>method: GET</p>"
    assert response.body =~ "<p>path: /throw</p>"
  end

  @tag :skip
  test "handling an unknow path" do
    response = Raxx.ErrorHandler.handle_request(Raxx.Test.get("/unknown"), %{next: TroubleApp})
    assert 500 = response.status
    assert response.body =~ "<p>title: FunctionClauseError</p>"
    assert response.body =~ "<p>message: no function clause matching in TroubleApp.handle_request/2</p>"
    assert response.body =~ "<p>method: GET</p>"
    assert response.body =~ "<p>path: /unknown</p>"
  end

  @tag :skip
  test "errors" do
    try do
      :foo + 1
    rescue
      x in [ArithmeticError] ->
        x
        # IO.inspect(x)
        # System.stacktrace
        # |> IO.inspect
    end
    try do
      :foo + 1
    catch
      kind, reason ->
        Exception.format_banner(kind, reason, System.stacktrace)
        |> IO.puts
    end
    # try do
    #   throw :blah
    # rescue
    #   e ->
    #     IO.inspect(e)
    # catch
    #   kind, reason ->
    #     IO.inspect(kind)
    #     IO.inspect(reason)
    #     System.stacktrace
    #     |> IO.inspect
    # end
    # try do
    #   exit :ooh
    # rescue
    #   e ->
    #     IO.inspect(e)
    # catch
    #   kind, reason ->
    #     IO.inspect(kind)
    #     IO.inspect(reason)
    #     System.stacktrace
    #     |> IO.inspect
    # end
  end
end
