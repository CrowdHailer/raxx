defmodule Raxx.Test do
  def get(path) do
    path = split_path(path)
    %Raxx.Request{path: path}
  end

  def post(path, params) do
    # TODO ensure param keys are strings
    path = split_path(path)
    %Raxx.Request{
      method: "POST",
      path: path,
      body: params
    }
  end

  def patch(path, body) do
    # TODO ensure param keys are strings
    path = split_path(path)
    %Raxx.Request{
      method: "PATCH",
      path: path,
      body: body
    }
  end

  def split_path(str) do
    str
    |> String.split("/")
    |> Enum.reject(&empty_string?/1)

  end

  defp empty_string?("") do
    true
  end
  defp empty_string?(str) when is_binary(str) do
    false
  end
end
