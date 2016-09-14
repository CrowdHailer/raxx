defmodule Raxx.Response do
  defstruct [
    status: 0,
    headers: %{},
    body: []
    # Return page object so you can test on the contents
  ]

  statuses = [
    continue: 100,
    switching_protocols: 101,
    processing: 102,
    ok: 200,
    created: 201,
    accepted: 202,
    non_authoritative_information: 203,
    no_content: 204,
    reset_content: 205,
    partial_content: 206,
    multi_status: 207,
    already_reported: 208,
    instance_manipulation_used: 226,
    multiple_choices: 300,
    moved_permanently: 301,
    found: 302,
    see_other: 303,
    not_modified: 304,
    use_proxy: 305,
    reserved: 306,
    temporary_redirect: 307,
    permanent_redirect: 308,
    bad_request: 400,
    unauthorized: 401,
    payment_required: 402,
    forbidden: 403,
    not_found: 404,
    method_not_allowed: 405,
    not_acceptable: 406,
    proxy_authentication_required: 407,
    request_timeout: 408,
    conflict: 409,
    gone: 410,
    length_required: 411,
    precondition_failed: 412,
    request_entity_too_large: 413,
    request_uri_too_long: 414,
    unsupported_media_type: 415,
    requested_range_not_satisfiable: 416,
    expectation_failed: 417,
    im_a_teapot: 418,
    misdirected_request: 421,
    unprocessable_entity: 422,
    locked: 423,
    failed_dependency: 424,
    upgrade_required: 426,
    precondition_required: 428,
    too_many_requests: 429,
    request_header_fields_too_large: 431,
    internal_server_error: 500,
    not_implemented: 501,
    bad_gateway: 502,
    service_unavailable: 503,
    gateway_timeout: 504,
    http_version_not_supported: 505,
    variant_also_negotiates: 506,
    insufficient_storage: 507,
    loop_detected: 508,
    not_extended: 510,
    network_authentication_required: 511
  ]

  # FIXME allow only iodata to be body, can't find is_iodata guard
  # https://tools.ietf.org/html/rfc2616#section-6.1.1
  for {reason_phrase, status_code} <- statuses do
    def unquote(reason_phrase)(body \\ "", headers_map \\ %{}) do
      %{status: unquote(status_code), body: body, headers: fix_headers(headers_map)}
     end
  end

  def fix_headers(headers_map) do
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

  def redirect(path, headers \\ %{}) do
    # TODO Plug checks that the path does not begin with '//' or no '/'
    %{
      status: 302,
      headers: Map.merge(%{"location" => path}, headers),
      body: redirect_page(path)
    }
  end

  def informational?(%{status: code}), do: 100 <= code and code < 200
  def success?(%{status: code}), do: 200 <= code and code < 300
  def redirect?(%{status: code}), do: 300 <= code and code < 400
  def client_error?(%{status: code}), do: 400 <= code and code < 500
  def server_error?(%{status: code}), do: 500 <= code and code < 600

  def get_header(r = %{headers: headers}, header_name) do
    header_name = String.downcase(header_name)
    [header_value] = headers[header_name]
    header_value
  end

  def set_cookie(r = %{headers: headers}, key, value, options \\ %{}) do
    cookies = Map.get(headers, "set-cookie", [])
    %{r | headers: Map.merge(headers, %{"set-cookie" => cookies ++ [Raxx.Cookie.new(key, value, options) |> Raxx.Cookie.set_cookie_string]})}
  end

  # Will not expire session cookies.
  def expire_cookie(r = %{headers: headers}, key) do
    cookies = Map.get(headers, "set-cookie", [])
    %{r | headers: %{"set-cookie" => cookies ++ ["#{key}=; expires=Thu, 01 Jan 1970 00:00:00 GMT; path=/"]}}
  end

  defp redirect_page(path) do
    """
      <html><body>You are being <a href=\"#{ escape(path) }\">redirected</a>.</body></html>
    """
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

  def escape(buffer) do
    IO.iodata_to_binary(for <<char <- buffer>>, do: escape_char(char))
  end
end
