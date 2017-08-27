defmodule Raxx.TransferEncoding do
  @moduledoc """
  Manipulate transfer-encoding header on raxx messages


  TODO do not show deprecated headers at raxx level
  """

  @field_name "transfer-encoding"

  @doc """
  Read transfer-encoding of the HTTP message.

  ## Examples

      iex> %Raxx.Request{headers: [{"transfer-encoding", "chunked"}]} |> Raxx.TransferEncoding.fetch
      {:ok, "chunked"}

      iex> %Raxx.Request{headers: []} |> Raxx.TransferEncoding.fetch
      {:error, :field_value_not_specified}

      iex> %Raxx.Request{headers: [{"transfer-encoding", "chunked"}, {"transfer-encoding", "gzip"}]} |> Raxx.TransferEncoding.fetch
      {:error, :duplicated_field}
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
  Is a transfer-encoding value specified for this HTTP message

  ## Examples

      iex> %Raxx.Request{headers: [{"transfer-encoding", "chunked"}]} |> Raxx.TransferEncoding.set?
      true

      iex> %Raxx.Request{headers: []} |> Raxx.TransferEncoding.set?
      false
  """
  def set?(request) do
    !({:error, :field_value_not_specified} == fetch(request))
  end

  @doc """
  Set the transfer-encoding of a HTTP message.

  ## Examples

      iex> %Raxx.Request{} |> Raxx.TransferEncoding.set("chunked") |> Map.get(:headers)
      [{"transfer-encoding", "chunked"}]

      iex> %Raxx.Request{headers: [{"transfer-encoding", "unknown"}]} |> Raxx.TransferEncoding.set("chunked") |> Map.get(:headers)
      [{"transfer-encoding", "chunked"}]
  """
  def set(message = %{headers: headers}, value) when value >= 0 do
    headers = :proplists.delete(@field_name, headers)
    headers = [{@field_name, value} | headers]
    %{message | headers: headers}
  end
end
