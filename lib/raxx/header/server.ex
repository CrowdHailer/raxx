# TODO namespace under headers or not
# defmodule Raxx.Server do
#   @moduledoc """
#   Manipulate server header on raxx messages
#
#   """
#
#   @field_name "server"
#
#   @doc """
#   Read server of the HTTP message.
#
#   ## Examples
#
#       iex> %Raxx.Request{headers: [{"server", "Apache"}]} |> Raxx.Server.fetch
#       {:ok, "Apache"}
#
#       iex> %Raxx.Request{headers: []} |> Raxx.Server.fetch
#       {:error, :field_value_not_specified}
#
#       iex> %Raxx.Request{headers: [{"server", "Apache"}, {"server", "NginX"}]} |> Raxx.Server.fetch
#       {:error, :duplicated_field}
#   """
#   def fetch(%{headers: headers}) do
#     case :proplists.lookup_all(@field_name,headers) do
#       [{@field_name, field_binary}] ->
#         parse_field_value(field_binary)
#       [] ->
#         {:error, :field_value_not_specified}
#       _ ->
#         {:error, :duplicated_field}
#     end
#   end
#
#   @doc """
#   Set the server of a HTTP message.
#
#   ## Examples
#
#       iex> %Raxx.Request{} |> Raxx.Server.set("Apache") |> Map.get(:headers)
#       [{"server", "Apache"}]
#
#       iex> %Raxx.Request{headers: [{"server", "NginX"}]} |> Raxx.Server.set("Apache") |> Map.get(:headers)
#       [{"server", "Apache"}]
#   """
#   def set(message = %{headers: headers}, user_agent) do
#     headers = :proplists.delete(@field_name, headers)
#     headers = [{@field_name, user_agent} | headers]
#     %{message | headers: headers}
#   end
#
#   defp parse_field_value(user_agent) do
#     {:ok, user_agent}
#   end
# end
