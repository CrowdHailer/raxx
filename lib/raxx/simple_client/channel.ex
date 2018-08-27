defmodule Raxx.SimpleClient.Channel do
  @moduledoc false

  @enforce_keys [
    :caller,
    :reference,
    # NOTE not sure request is needed in exchange struct
    :request,
    :client
  ]
  defstruct @enforce_keys
end
