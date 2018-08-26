defmodule Raxx.NaiveClient.Exchange do
  @enforce_keys [
    :caller,
    :reference,
    # NOTE sure request is needed in exchange struct
    :request,
    :client
  ]
  defstruct @enforce_keys
end
