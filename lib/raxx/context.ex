defmodule Raxx.Context do
  # defmodule ServerContext do
  #   defstruct remote_ip: nil,
  #             schema: nil,
  #             properties: %{}

  #   @type t :: %__MODULE__{}
  # end

  # ## Server Context zone

  # @spec get_server_context() :: ServerContext.t()
  # def get_server_context() do
  #   get_tagged(ServerContext, %ServerContext{})
  # end

  # @spec put_server_context(ServerContext.t()) :: ServerContext.t()
  # def put_server_context(%ServerContext{} = server_context) do
  #   put_tagged(ServerContext, server_context)
  # end

  @type section_name :: term()

  # section zone

  @spec set(section_name, term) :: term
  def set(section_name, value) do
    previous_value = put_tagged(section_name, value)
    previous_value
  end

  # retrieve?
  @spec retrieve(section_name, default :: term) :: term
  def retrieve(section_name, default \\ nil) do
    get_tagged(section_name, default)
  end

  def update_section() do
  end

  ## section manipulation zone
  @spec initialise(section_name, term) :: term
  def initialise(section_name, value) do
  end

  @spec get(section_name, term, term) :: term
  def get(section_name, key, default \\ nil) do
  end

  @spec put(section_name, term, term) :: map | struct
  def put(section_name, key, value) do
  end

  @spec replace!(section_name, term, term) :: map | struct
  def replace!(section_name, key, value) do
  end

  @spec update(section_name, term, (term -> term)) :: map | struct
  def update(_section_name, _initial, _fun) do
  end

  ## Private functions

  defp put_tagged(key, value) do
    Process.put({__MODULE__, key}, value)
  end

  defp get_tagged(key, default) do
    Process.get({__MODULE__, key}, default)
  end
end
