defmodule Raxx.Context do
  defmodule ServerContext do
    defstruct remote_ip: nil,
              schema: nil,
              properties: %{}
  end

  def get_server_context() do
  end

  def put_server_context() do
  end

  def put_section(section_name, value) do
    previous_value = put_tagged(section_name, value)
    previous_value
  end

  def get_section(section_name, default \\ %{}) do
    get_tagged(section_name, default)
  end

  defp put_tagged(key, value) do
    Process.put({__MODULE__, key}, value)
  end

  defp get_tagged(key, default) do
    Process.get({__MODULE__, key}, default)
  end
end
