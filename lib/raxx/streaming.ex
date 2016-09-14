defmodule Raxx.Streaming do
  defstruct [handler: nil, environment: nil, initial: "", headers: %{}]
  
  def upgrade(mod, env, opts) do
    struct(%__MODULE__{handler: mod, environment: env}, opts)
  end
end
