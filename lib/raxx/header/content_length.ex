defmodule Raxx.ContentLength do
  @moduledoc """
  Manipulate content-length header on raxx messages

  """
  @moduledoc false

  @field_name "content-length"

  @doc """
  Read content-length of the HTTP message.

  ## Examples

      iex> %Raxx.Request{headers: [{"content-length", "100"}]} |> Raxx.ContentLength.fetch
      {:ok, 100}

      iex> %Raxx.Request{headers: []} |> Raxx.ContentLength.fetch
      {:error, :field_value_not_specified}

      iex> %Raxx.Request{headers: [{"content-length", "garbage"}]} |> Raxx.ContentLength.fetch
      {:error, :field_value_parse_failure}

      iex> %Raxx.Request{headers: [{"content-length", "100garbage"}]} |> Raxx.ContentLength.fetch
      {:error, :field_value_parse_failure}

      iex> %Raxx.Request{headers: [{"content-length", "100"}, {"content-length", "200"}]} |> Raxx.ContentLength.fetch
      {:error, :duplicated_field}
  """
  def fetch(%{headers: headers}) do
    case :proplists.lookup_all(@field_name,headers) do
      [{@field_name, field_binary}] ->
        parse_field_value(field_binary)
      [] ->
        {:error, :field_value_not_specified}
      _ ->
        {:error, :duplicated_field}
    end
  end

  @doc """
  Set the content-length of a HTTP message.

  ## Examples

      iex> %Raxx.Request{} |> Raxx.ContentLength.set(100) |> Map.get(:headers)
      [{"content-length", "100"}]

      iex> %Raxx.Request{headers: [{"content-length", "200"}]} |> Raxx.ContentLength.set(100) |> Map.get(:headers)
      [{"content-length", "100"}]
  """
  def set(message = %{headers: headers}, value) when value >= 0 do
    headers = :proplists.delete(@field_name, headers)
    headers = [{@field_name, Integer.to_string(value)} | headers]
    %{message | headers: headers}
  end

  defp parse_field_value(content_length_binary) do
    case Integer.parse(content_length_binary) do
      {content_length, ""} ->
        {:ok, content_length}
      _ ->
        {:error, :field_value_parse_failure}
    end
  end
end
