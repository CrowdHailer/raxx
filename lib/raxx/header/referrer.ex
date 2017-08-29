defmodule Raxx.Referrer do
  @moduledoc """
  Manipulate referer header on raxx messages

  *NOTE: The `Referrer` module uses the correct spelling however due to historic reasons the field_name is spelt `referer`
  """

  @field_name "referer"

  @doc """
  Read referer of the HTTP message.

  ## Examples

      iex> %Raxx.Request{headers: [{"referer", "http://www.example.com"}]} |> Raxx.Referrer.fetch
      {:ok, %URI{authority: "www.example.com", fragment: nil,
             host: "www.example.com", path: nil, port: 80, query: nil,
             scheme: "http", userinfo: nil}}

      iex> %Raxx.Request{headers: []} |> Raxx.Referrer.fetch
      {:error, :field_value_not_specified}


      iex> %Raxx.Request{headers: [{"referer", "http://www.example.com"}, {"referer", "http://www.example.org"}]} |> Raxx.Referrer.fetch
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
  Set the referer of a HTTP message.

  ## Examples

      iex> %Raxx.Request{} |> Raxx.Referrer.set("www.example.com") |> Map.get(:headers)
      [{"referer", "www.example.com"}]

      iex> uri = %URI{authority: "www.example.com", fragment: nil,
      iex>            host: "www.example.com", path: nil, port: 80, query: nil,
      iex>            scheme: "http", userinfo: nil}
      iex> %Raxx.Request{} |> Raxx.Referrer.set(uri) |> Map.get(:headers)
      [{"referer", "http://www.example.com"}]

      iex> %Raxx.Request{headers: [{"referer", "www.example.com"}]} |> Raxx.Referrer.set("www.example.org") |> Map.get(:headers)
      [{"referer", "www.example.org"}]
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
