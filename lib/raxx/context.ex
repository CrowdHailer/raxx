defmodule Raxx.Context do
  @type section_name :: term()

  @typedoc """
  An opaque type for the context snapshot data.
  """
  @opaque snapshot :: map()

  @moduledoc """
  `Raxx.Context` is a mechanism for simple sharing of state/information between
  `Raxx.Middleware`s and `Raxx.Server`s.

  It is designed to be flexible and to enable different middlewares to operate
  on it without conflicts. Each separate functionality using the context
  can be in a different "section", containing arbitrary data.

  Context is implicitly shared using the process dictionary and persists for the
  duration of a single request/response cycle. If you want to pass the context
  to a different process, you need to take its snapshot, pass it explicitly and
  "restore" it in the other process. See `Raxx.Context.get_snapshot/0` and 
  `Raxx.Context.restore_snapshot/1` for details.
  """

  @doc """
  Sets the value of a context section.

  Returns the previous value of the section or `nil` if one was
  not set.
  """
  @spec set(section_name, term) :: term | nil
  def set(section_name, value) do
    Process.put(tag(section_name), value)
  end

  @doc """
  Deletes the section from the context.

  Returns the previous value of the section or `nil` if one was
  not set.
  """
  @spec delete(section_name) :: term | nil
  def delete(section_name) do
    Process.delete(tag(section_name))
  end

  @doc """
  Retrieves the value of the context section.

  If the section wasn't set yet, it will return `nil`.
  """
  @spec retrieve(section_name, default :: term) :: term
  def retrieve(section_name, default \\ nil) do
    Process.get(tag(section_name), default)
  end

  @doc """
  Restores a previously created context snapshot.

  It will restore the implicit state of the context for the current
  process to what it was when the snapshot was created using
  `Raxx.Context.get_snapshot/0`. The current context values won't
  be persisted in any way.
  """
  @spec restore_snapshot(snapshot()) :: :ok
  def restore_snapshot(context) when is_map(context) do
    new_context_tuples =
      context
      |> Enum.map(fn {k, v} -> {tag(k), v} end)

    current_context_keys =
      Process.get_keys()
      |> Enum.filter(&tagged_key?/1)

    new_keys = Enum.map(new_context_tuples, fn {k, _v} -> k end)
    keys_to_remove = current_context_keys -- new_keys

    Enum.each(keys_to_remove, &Process.delete/1)
    Enum.each(new_context_tuples, fn {k, v} -> Process.put(k, v) end)
  end

  @doc """
  Creates a snapshot of the current process' context.

  The returned context data can be passed between processes and restored
  using `Raxx.Context.restore_snapshot/1`
  """
  @spec get_snapshot() :: snapshot()
  def get_snapshot() do
    Process.get()
    |> Enum.filter(fn {k, _v} -> tagged_key?(k) end)
    |> Enum.map(fn {k, v} -> {strip_tag(k), v} end)
    |> Map.new()
  end

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
