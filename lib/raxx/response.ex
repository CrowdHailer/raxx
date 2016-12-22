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

  # Copied from https://tools.ietf.org/html/rfc7231#section-6.1
  statuses = [
    {100, "Continue"},
    {101, "Switching Protocols"},
    {200, "OK"},
    {201, "Created"},
    {202, "Accepted"},
    {203, "Non-Authoritative Information"},
    {204, "No Content"},
    {205, "Reset Content"},
    {206, "Partial Content"},
    {300, "Multiple Choices"},
    {301, "Moved Permanently"},
    {302, "Found"},
    {303, "See Other"},
    {304, "Not Modified"},
    {305, "Use Proxy"},
    {307, "Temporary Redirect"},
    {400, "Bad Request"},
    {401, "Unauthorized"},
    {402, "Payment Required"},
    {403, "Forbidden"},
    {404, "Not Found"},
    {405, "Method Not Allowed"},
    {406, "Not Acceptable"},
    {407, "Proxy Authentication Required"},
    {408, "Request Timeout"},
    {409, "Conflict"},
    {410, "Gone"},
    {411, "Length Required"},
    {412, "Precondition Failed"},
    {413, "Payload Too Large"},
    {414, "URI Too Long"},
    {415, "Unsupported Media Type"},
    {416, "Range Not Satisfiable"},
    {417, "Expectation Failed"},
    {426, "Upgrade Required"},
    {500, "Internal Server Error"},
    {501, "Not Implemented"},
    {502, "Bad Gateway"},
    {503, "Service Unavailable"},
    {504, "Gateway Timeout"},
    {505, "HTTP Version Not Supported"}
  ]

  # FIXME allow only iodata to be body, can't find is_iodata guard
  # https://tools.ietf.org/html/rfc2616#section-6.1.1
  for {status_code, reason_phrase} <- statuses do
    function_name = reason_phrase |> String.downcase |> String.replace(" ", "_") |> String.to_atom
    if status_code != 200 do
      @doc false
    end
    def unquote(function_name)(body \\ "", headers \\ []) do
      %{status: unquote(status_code), body: body, headers: fix_headers(headers)}
    end
  end

  # Variable naming from https://www.w3.org/Protocols/rfc2616/rfc2616-sec6.html
  for {status_code, reason_phrase} <- statuses do
    def status_line(unquote(status_code)) do
      ["HTTP/1.1 ", unquote(:erlang.integer_to_binary(status_code)), " ", unquote(reason_phrase), "\r\n"]
    end
  end

  def header_lines(headers) do
    (Enum.map(headers, fn({x, y}) -> "#{x}: #{y}" end) |> Enum.join("\r\n")) <> "\r\n"
  end

  defp fix_headers(headers_list) when is_list(headers_list) do
    # Enum.map(headers_list, )
    headers_list
  end
  defp fix_headers(headers_map) when is_map(headers_map) do
    headers_map
    |> Enum.map(fn
      # FIXME could be an issue with iodata that should be single header getting split
      ({name, value} when is_binary(value)) ->
        {name, [value]}
      ({name, value} when is_list(value)) ->
        {name, value}
    end)
    |> Enum.into(%{})
  end

  def informational?(%{status: code}), do: 100 <= code and code < 200
  def success?(%{status: code}), do: 200 <= code and code < 300
  def redirect?(%{status: code}), do: 300 <= code and code < 400
  def client_error?(%{status: code}), do: 400 <= code and code < 500
  def server_error?(%{status: code}), do: 500 <= code and code < 600

  @doc """
  Adds a set cookie header to the response.

  For options see `Raxx.Cookie.Attributes`
  """
  def set_cookie(r = %{headers: headers}, key, value, options \\ %{}) do
    cookies = Map.get(headers, "set-cookie", [])
    %{r | headers: Map.merge(headers, %{"set-cookie" => cookies ++ [Raxx.Cookie.new(key, value, options) |> Raxx.Cookie.set_cookie_string]})}
  end

  @doc """
  Adds a cookie header to the response, that will expire the cookie with the given key.

  **NOTE:** Will not expire session cookies.
  """
  def expire_cookie(r = %{headers: headers}, key) do
    cookies = Map.get(headers, "set-cookie", [])
    %{r | headers: %{"set-cookie" => cookies ++ ["#{key}=; expires=Thu, 01 Jan 1970 00:00:00 GMT; path=/"]}}
  end

  # TODO move escapse to util
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

  defp escape(buffer) do
    IO.iodata_to_binary(for <<char <- buffer>>, do: escape_char(char))
  end
end
