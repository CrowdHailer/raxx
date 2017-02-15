defmodule HTTPStatus do
  @moduledoc """
  Every HTTP response status for Elixir applications.

  All HTTP response codes are defined in [RFC7231](https://tools.ietf.org/html/rfc7231#section-6.1)
  """
  @external_resource "./rfc7231.status_codes"
  @default_http_version "1.1"

  path = Path.expand(@external_resource, Path.dirname(__ENV__.file))
  {:ok, file} = File.read(path)
  file = String.strip(file)
  [_header | lines] = String.split(file, "\n")
  statuses = Enum.map(lines, fn
    (status_string) ->
      {code, " " <> reason_phrase} = Integer.parse(status_string)
      {code, reason_phrase}
  end)

  @doc """
  Expand a status code into the full response status line.

  Variable naming from https://www.w3.org/Protocols/rfc2616/rfc2616-sec6.html

  ## Examples

      iex> HTTPStatus.status_line(200)
      "HTTP/1.1 200 OK\\r\\n"

      iex> HTTPStatus.status_line(200, "1.0")
      "HTTP/1.0 200 OK\\r\\n"
  """
  def status_line(code, version \\ unquote(@default_http_version))
  for status_string <- lines do
    {code, " " <> _reason_phrase} = Integer.parse(status_string)
    def status_line(unquote(code), version) do
      "HTTP/" <> version <> " " <> unquote(status_string) <> "\r\n"
    end
  end

  @doc """
  Code and Reason-Phrase for all statuses

  Returned as a list of `{code, reason_phrase}` pairs. 
  ## Examples

      iex> HTTPStatus.every_status |> List.first
      {100, "Continue"}
  """
  def every_status do
    unquote(statuses)
  end

end
