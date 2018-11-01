defmodule Raxx.BenchmarksTest do
  use ExUnit.Case

  @moduledoc """
  To run the benchmarks do

      mix test --only benchmark --include skip
  """
  @moduletag :skip
  @moduletag :benchmark

  # some benchmarks take more than the default timeout of minute
  @moduletag timeout: 10 * 60 * 1_000

  test "calling modules via functions" do
    list = Enum.to_list(1..10)

    enum = Enum
    lambda = fn l -> Enum.reverse(l) end

    Benchee.run(%{
      "directly" => fn -> Enum.reverse(list) end,
      "module in a variable" => fn -> enum.reverse(list) end,
      "apply on a variable" => fn -> apply(enum, :reverse, [list]) end,
      "apply on a Module" => fn -> apply(Enum, :reverse, [list]) end,
      "lambda" => fn -> lambda.(list) end
    })
  end

  test "passing state around" do
    big_data = %{
      foo: [:bar, :baz, 1.5, "this is a medium size string"],
      bar: Enum.to_list(1..100)
    }

    inputs = %{
      "1 item" => 1,
      "10 items" => 10,
      "100 items" => 100,
      "1000 items" => 1000
    }

    # updating state is here to make sure no smart optimisation kicks in
    update_state = fn state, value -> Map.put(state, :ban, value) end

    Benchee.run(
      %{
        "directly" => fn count ->
          1..count
          |> Enum.map(&update_state.(big_data, &1))
          |> Enum.map(& &1)
        end,
        "sending messages to self" => fn count ->
          1..count
          |> Enum.each(fn number ->
            send(self(), {:whoa, update_state.(big_data, number)})
          end)

          1..count
          |> Enum.map(fn _ ->
            receive do
              {:whoa, a} -> a
            after
              0 -> raise "this shouldn't happen"
            end
          end)
        end,
        "passing through the process dictionary" => fn count ->
          1..count
          |> Enum.each(fn number ->
            Process.put({:whoa, number}, update_state.(big_data, number))
          end)

          1..count
          |> Enum.map(fn number ->
            Process.get({:whoa, number})
          end)
        end
      },
      inputs: inputs
    )
  end
end
