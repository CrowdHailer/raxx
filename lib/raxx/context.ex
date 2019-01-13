defmodule Raxx.Context do
  @type section_name :: term()

  @opaque t :: map()

  @spec set(section_name, term) :: term | nil
  def set(section_name, value) do
    Process.put(tag(section_name), value)
  end

  @spec delete(section_name) :: term | nil
  def delete(section_name) do
    Process.delete(tag(section_name))
  end

  @spec retrieve(section_name, default :: term) :: term
  def retrieve(section_name, default \\ nil) do
    Process.get(tag(section_name), default)
  end

  @spec restore_snapshot(t()) :: :ok
  def restore_snapshot(context) when is_map(context) do
    # TODO remove the keys that shouldn't be in the process dictionary anymore
    context
    |> Enum.each(fn {k, v} -> Process.put(tag(k), v) end)

    :ok
  end

  @spec get_snapshot() :: t()
  def get_snapshot() do
    Process.get()
    |> Enum.filter(fn {k, _v} -> tagged_key?(k) end)
    |> Enum.map(fn {k, v} -> {strip_tag(k), v} end)
    |> Map.new()
  end

  # ## section manipulation zone
  # @spec initialise(section_name, term) :: term
  # def initialise(section_name, value) do
  # end

  # @spec get(section_name, term, term) :: term
  # def get(section_name, key, default \\ nil) do
  # end

  # @spec put(section_name, term, term) :: map | struct
  # def put(section_name, key, value) do
  # end

  # @spec replace!(section_name, term, term) :: map | struct
  # def replace!(section_name, key, value) do
  # end

  # @spec update(section_name, term, (term -> term)) :: map | struct
  # def update(_section_name, _initial, _fun) do
  # end

  defp tagged_key?({__MODULE__, _}) do
    true
  end

  defp tagged_key?(_) do
    false
  end

  defp strip_tag({__MODULE__, key}) do
    key
  end

  defp tag(key) do
    {__MODULE__, key}
  end
end
