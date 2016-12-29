defmodule Raxx.Response do
  @moduledoc """
  HTTP responses from a Raxx application are encapsulated in a `Raxx.Response` struct.

  The contents are itemised below:

  | **status** | The HTTP status code for the response: `1xx, 2xx, 3xx, 4xx, 5xx` |
  | **headers** | The response headers as a map: `%{"content-type" => ["text/plain"]}` |
  | **body** | The response body, by default an empty string. |
  """

  defstruct [
    status: 0,
    headers: [],
    body: []
    # Return page object so you can test on the contents
  ]

  for {status_code, reason_phrase} <- HTTP.StatusLine.statuses do
    function_name = reason_phrase |> String.downcase |> String.replace(" ", "_") |> String.to_atom
    if status_code != 200 do
      @doc false
    end
    def unquote(function_name)(body \\ "", headers \\ []) do
      build(unquote(status_code), body, headers)
    end
  end

  # This pattern match cannot be an iolist, it contains a tuple.
  # It is therefore assumed to be body content
  defp build(code, body = [{_, _} | _], headers) do
    build(code, "", body ++ headers)
  end
  defp build(code, %{headers: headers, body: body}, extra_headers) do
    build(code, body, headers ++ extra_headers)
  end
  defp build(code, body, headers) do
    struct(Raxx.Response, status: code, body: body, headers: headers)
  end

  def informational?(%{status: code}), do: 100 <= code and code < 200
  def success?(%{status: code}), do: 200 <= code and code < 300
  def redirect?(%{status: code}), do: 300 <= code and code < 400
  def client_error?(%{status: code}), do: 400 <= code and code < 500
  def server_error?(%{status: code}), do: 500 <= code and code < 600

  # needed for redirect
  @escapes [
    {?<, "&lt;"},
    {?>, "&gt;"},
    {?&, "&amp;"},
    {?", "&quot;"},
    {?', "&#39;"}
  ]

  Enum.each @escapes, fn { match, insert } ->
    defp escape_char(unquote(match)), do: unquote(insert)
  end

  defp escape_char(char), do: << char >>

  @doc false
  defp escape(buffer) do
    IO.iodata_to_binary(for <<char <- buffer>>, do: escape_char(char))
  end
end
