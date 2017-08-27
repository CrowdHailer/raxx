defmodule Raxx.Connection do
  @moduledoc """
  Manipulate connection header on raxx messages

  TODO do not show deprecated headers at raxx level
  """

  @field_name "connection"

  @doc """
  Read connection of the HTTP message.

  ## Examples

      iex> %Raxx.Request{headers: [{"connection", "close"}]} |> Raxx.Connection.fetch
      {:ok, "close"}

      iex> %Raxx.Request{headers: []} |> Raxx.Connection.fetch
      {:error, :field_value_not_specified}
  """
  def fetch(%{headers: headers}) do
    case :proplists.lookup_all(@field_name,headers) do
      [{@field_name, field_binary}] ->
        {:ok, field_binary}
      [] ->
        {:error, :field_value_not_specified}
      _ ->
        {:error, :duplicated_field}
    end
  end

  @doc """
  Test if a Connection is marked as reuseable

  This behaviour depends if the HTTP version is 1.0 or 1.1.
  # TODO add a version field to the request/response types.
  # Assumes 1.1

  ## Examples

      iex> %Raxx.Request{headers: [{"connection", "close"}]} |> Raxx.Connection.is_persistant?
      false

      iex> %Raxx.Request{headers: []} |> Raxx.Connection.is_persistant?
      true
  """
  def is_persistant?(request) do
    case fetch(request) do
      {:ok, "close"} ->
        false
      _ ->
        true
    end
  end


  @doc """
  Keep alive the connection for more messages.

  ## Examples

      iex> %Raxx.Response{} |> Raxx.Connection.mark_persistant() |> Raxx.Connection.fetch()
      {:ok, "keep-alive"}
  """
  def mark_persistant(request) do
    set(request, "keep-alive")
  end

  @doc """
  Set the connection of a HTTP message.
  """
  def set(message = %{headers: headers}, value) do
    headers = :proplists.delete(@field_name, headers)
    headers = [{@field_name, value} | headers]
    %{message | headers: headers}
  end

end
