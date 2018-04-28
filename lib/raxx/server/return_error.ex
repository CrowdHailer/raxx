defmodule ReturnError do
  @moduledoc """
  Raise when a server module returns an invalid reaction
  """

  # DEBT could be improved by including server module in message and if it implements behaviour.
  defexception [:return]

  def message(%{return: return}) do
    """
    Invalid reaction from server module. Response must be complete or include update server state

        e.g.
          \# Complete
          Raxx.response(:ok)
          |> Raxx.set_body("Hello, World!")

          \# New server state
          response = Raxx.response(:ok)
          |> Raxx.set_body(true)
          {[response], new_state}

        Actual value returned was
          #{inspect(return)}
    """
  end
end
