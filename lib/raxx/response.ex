defmodule Raxx.Response do
  @moduledoc """
  HTTP responses from a Raxx application are encapsulated in a `Raxx.Response` struct.

  The contents are itemised below:

  | **status** | The HTTP status code for the response: `1xx, 2xx, 3xx, 4xx, 5xx` |
  | **headers** | The response headers as a map: `%{"content-type" => ["text/plain"]}` |
  | **body** | The response body, by default an empty string. |

  ## Examples

      iex> Response.ok().status
      200

      iex> Response.ok("Hello, World!").body
      "Hello, World!"

      iex> Response.ok([{"content-language", "en"}]).headers
      [{"content-language", "en"}]

      iex> Response.ok("Hello, World!", [{"content-type", "text/plain"}]).headers
      [{"content-type", "text/plain"}]
  """

  defstruct [
    status: 0,
    headers: [],
    body: []
    # Return page object so you can test on the contents
  ]

  for {status_code, reason_phrase} <- HTTP.StatusLine.statuses do
    function_name = reason_phrase |> String.downcase |> String.replace(" ", "_") |> String.to_atom
    @doc """
    Create a "#{status_code} #{reason_phrase}" response.

    See module documentation for adding response content
    """
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

  @doc """
  The response is marked as an interim response.

  https://tools.ietf.org/html/rfc7231#section-6.2
  """
  def informational?(%{status: code}), do: 100 <= code and code < 200

  @doc """
  The response indicates that client request was received, understood, and accepted.

  https://tools.ietf.org/html/rfc7231#section-6.3
  """
  def success?(%{status: code}), do: 200 <= code and code < 300

  @doc """
  The response indicates that further action needs to be taken by the client.

  https://tools.ietf.org/html/rfc7231#section-6.4
  """
  def redirect?(%{status: code}), do: 300 <= code and code < 400

  @doc """
  The response indicates that the client sent an incorrect request.

  https://tools.ietf.org/html/rfc7231#section-6.5
  """
  def client_error?(%{status: code}), do: 400 <= code and code < 500

  @doc """
  The response indicates that the server is incapable of acting upon the request.

  https://tools.ietf.org/html/rfc7231#section-6.6
  """
  def server_error?(%{status: code}), do: 500 <= code and code < 600
end
