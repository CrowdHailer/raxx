defmodule Ace.HTTP do
  @moduledoc """
  Running a HTTP server on [Ace](https://hex.pm/packages/ace)

  Ace is a generic TCP server.
  This module provides helpers for Raxx applications on Ace.
  """

  @doc """
  Start a HTTP server.
  """
  def start_link(raxx_app, options \\ []) do
    Ace.TCP.start_link({Ace.HTTP.Handler, raxx_app}, options)
  end

  @doc """
  Fetch the server port number.
  """
  def port(endpoint) do
    Ace.TCP.Endpoint.port(endpoint)
  end
end
