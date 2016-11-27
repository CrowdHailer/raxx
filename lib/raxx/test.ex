defmodule Raxx.Test do
  alias Raxx.Request
  @moduledoc """
  Help for testing Raxx applications.
  """

  @doc """
  Create a new `GET` request
  """
  @spec get(binary, %{binary => binary}) :: Request.t
  def get(path, headers \\ %{}) do
    path = Raxx.Request.split_path(path)
    %Request{path: path, headers: headers}
  end

  @doc """
  Create a new `POST` request
  """
  @spec post(binary, %{binary => binary}) :: Request.t
  def post(path, params) do
    path = Raxx.Request.split_path(path)
    %Request{
      method: "POST",
      path: path,
      body: params
    }
  end

  @doc """
  Create a new `PATCH` request
  """
  @spec patch(binary, binary) :: Request.t
  def patch(path, body) do
    path = Raxx.Request.split_path(path)
    %Request{
      method: "PATCH",
      path: path,
      body: body
    }
  end
end
