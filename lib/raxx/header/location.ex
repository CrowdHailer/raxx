defmodule Raxx.Location do
  @moduledoc """
  Manipulate location header on raxx messages

  """
  @moduledoc false

  @field_name "location"

  @doc """
  Read location of the HTTP message.

  ## Examples

      iex> %Raxx.Request{headers: [{"location", "http://www.example.com"}]} |> Raxx.Location.fetch
      {:ok, %URI{authority: "www.example.com", fragment: nil,
             host: "www.example.com", path: nil, port: 80, query: nil,
             scheme: "http", userinfo: nil}}

      iex> %Raxx.Request{headers: []} |> Raxx.Location.fetch
      {:error, :field_value_not_specified}


      iex> %Raxx.Request{headers: [{"location", "http://www.example.com"}, {"location", "http://www.example.org"}]} |> Raxx.Location.fetch
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
  Set the location of a HTTP message.

  ## Examples

      iex> %Raxx.Request{} |> Raxx.Location.set("www.example.com") |> Map.get(:headers)
      [{"location", "www.example.com"}]

      iex> uri = %URI{authority: "www.example.com", fragment: nil,
      iex>            host: "www.example.com", path: nil, port: 80, query: nil,
      iex>            scheme: "http", userinfo: nil}
      iex> %Raxx.Request{} |> Raxx.Location.set(uri) |> Map.get(:headers)
      [{"location", "http://www.example.com"}]

      iex> %Raxx.Request{headers: [{"location", "www.example.com"}]} |> Raxx.Location.set("www.example.org") |> Map.get(:headers)
      [{"location", "www.example.org"}]
  """
  def set(message = %{headers: headers}, uri) do
    headers = :proplists.delete(@field_name, headers)
    headers = [{@field_name, serialize_field_value(uri)} | headers]
    %{message | headers: headers}
  end

  def serialize_field_value(uri_binary) when is_binary(uri_binary) do
    uri_binary
  end
  def serialize_field_value(uri = %URI{}) do
    URI.to_string(uri)
  end

  defp parse_field_value(referrer_binary) do
    # NOTE URI.parse always comes up with something
    case URI.parse(referrer_binary) do
      referrer = %URI{} ->
        {:ok, referrer}
    end
  end
end
