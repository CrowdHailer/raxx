defmodule Raxx.Elli.ResponseTest do
  use ExUnit.Case

  setup do
    port = 2022
    {:ok, _pid} = :elli.start_link [
      callback: Raxx.Adapters.Elli.Handler,
      callback_args: {Raxx.TestSupport.Responder, %{target: self()}},
      port: port]
    {:ok, %{port: port}}
  end

  test "response uses correct method", %{port: port} do
    task = Task.async(fn () -> HTTPoison.get("localhost:#{port}") end)
    receive do
      {:request, pid} ->
        send(pid, {:response, Raxx.Response.continue})
    end
    assert {:ok, %{status_code: 100, body: ""}} = Task.await(task)
  end

  test "response custom headers are set", %{port: port} do
    task = Task.async(fn () -> HTTPoison.get("localhost:#{port}") end)
    receive do
      {:request, pid} ->
        send(pid, {:response, Raxx.Response.no_content("", %{"custom-header" => ["my-value"]})})
    end
    assert {:ok, %{headers: headers}} = Task.await(task)
    header = Enum.find(headers, fn
      ({"custom-header", _}) -> true
      _ -> false
    end)
    assert {_, "my-value"} = header
  end


end
