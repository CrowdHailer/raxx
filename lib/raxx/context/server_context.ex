defmodule Raxx.Context.ServerContext do
  defstruct remote_ip_address: nil,
            local_port_number: nil,
            # or protocol?
            schema: nil,
            properties: %{}

  # TODO what are the options? Do we need it at all?
  @type schema :: :TODO

  @type t :: %__MODULE__{
          remote_ip_address: :inet.ip4_address() | :inet.ip6_address() | nil,
          local_port_number: :inet.port_number() | nil,
          schema: schema() | nil,
          properties: map()
        }

  @spec retrieve() :: t()
  def retrieve() do
    Raxx.Context.retrieve(__MODULE__, %__MODULE__{})
  end

  @spec set(t()) :: term | nil
  def set(%__MODULE__{} = server_context) do
    Raxx.Context.set(__MODULE__, server_context)
  end
end
