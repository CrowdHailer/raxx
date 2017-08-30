defmodule Raxx.UserAgent do
  @moduledoc """
  Manipulate user-agent header on raxx messages

  """
  @moduledoc false

  @field_name "user-agent"

  @doc """
  Read user-agent of the HTTP message.

  ## Examples

      iex> %Raxx.Request{headers: [{"user-agent", "firefox"}]} |> Raxx.UserAgent.fetch
      {:ok, "firefox"}

      iex> %Raxx.Request{headers: []} |> Raxx.UserAgent.fetch
      {:error, :field_value_not_specified}

      iex> %Raxx.Request{headers: [{"user-agent", "firefox"}, {"user-agent", "chrome"}]} |> Raxx.UserAgent.fetch
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
  Set the user-agent of a HTTP message.

  ## Examples

      iex> %Raxx.Request{} |> Raxx.UserAgent.set("firefox") |> Map.get(:headers)
      [{"user-agent", "firefox"}]

      iex> %Raxx.Request{headers: [{"user-agent", "chrome"}]} |> Raxx.UserAgent.set("firefox") |> Map.get(:headers)
      [{"user-agent", "firefox"}]
  """
  def set(message = %{headers: headers}, user_agent) do
    headers = :proplists.delete(@field_name, headers)
    headers = [{@field_name, user_agent} | headers]
    %{message | headers: headers}
  end

  defp parse_field_value(user_agent) do
    {:ok, user_agent}
  end
end
