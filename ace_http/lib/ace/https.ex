defmodule Ace.HTTPS do
  @moduledoc """
  Running a HTTPS server on [Ace](https://hex.pm/packages/ace)

  Ace provides generic servers.
  This module provides helpers for Raxx applications on Ace.
  """

  @doc """
  Start a HTTPS server.
  """
  def start_link(raxx_app, options \\ []) do
    Ace.TLS.start_link({Ace.HTTP.Handler, raxx_app}, options)
  end

  @doc """
  Fetch the server port number.
  """
  def port(endpoint) do
    Ace.TLS.port(endpoint)
  end
end
