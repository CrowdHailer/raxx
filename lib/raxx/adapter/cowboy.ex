defmodule Raxx.Adapters.Cowboy.Handler do
  def init({:tcp, :http}, req, opts = {router, raxx_opts}) do
    default_headers = %{"content-type" => "text/html"}
    raxx_request = normalise_request(req)
    %{status: status, headers: headers, body: body} = router.call(raxx_request, raxx_opts)
    headers = Map.merge(default_headers, headers) |> Enum.map(fn (x) -> x end)
    {:ok, resp} = :cowboy_req.reply(status, headers, body, req)
    {:ok, resp, opts}
  end

  def handle(req, state) do
    {:ok, req, state}
  end

  def terminate(_reason, _req, _state) do
    :ok
  end

  defp normalise_request(req) do
    # Server information
    {host, req} = :cowboy_req.host req

    {port, req} = :cowboy_req.port req

    # Request header information
    {method, req} = :cowboy_req.method req

    {path, req} = :cowboy_req.path req
    path = String.split(path, "/") |> Enum.reject(fn (segment) ->  segment == "" end)

    {qs, req}   = :cowboy_req.qs req
    query = URI.decode_query(qs)

    {headers, req}   = :cowboy_req.headers req
    headers = Enum.into(headers, %{})

    # Body
    {:ok, content_type, req} = :cowboy_req.parse_header("content-type", req)
    {:ok, body, _req} = parse_req_body(req, content_type)

    # {peer, req} = :cowboy_req.peer req

    # Request
    %Raxx.Request{
      host: host,
      port: port,
      method: method,
      path: path,
      query: query,
      headers: headers,
      body: body
    }
  end

  def parse_req_body(cowboy_req, :undefined) do
    {:ok, nil, cowboy_req}
  end
  def parse_req_body(cowboy_req, {"application", "octet-stream", []}) do
    {:ok, :todo, cowboy_req}
  end
  def parse_req_body(cowboy_req, {"application", "x-www-form-urlencoded", [{"charset", "utf-8"}]}) do
    {:ok, body_qs, cowboy_req}  = :cowboy_req.body_qs(cowboy_req, [])
    body = Enum.into(body_qs, %{})
    {:ok, body, cowboy_req}
  end
  def parse_req_body(cowboy_req, {"multipart", "form-data", _}) do
    {:ok, body, cowboy_req} = multipart(cowboy_req)
    {:ok, body, cowboy_req}
  end
  def parse_req_body(_cowboy_req, content_type) do
    {:error, :unknown_content_type, content_type}
  end

  def multipart(cowboy_req, body \\ []) do
    case :cowboy_req.part(cowboy_req) do
      # DEBT why is this called headers
      {:ok, headers, cowboy_req} ->
        {:ok, part, cowboy_req} = handle_part(headers, cowboy_req)
        multipart(cowboy_req, body ++ part)
      {:done, cowboy_req} ->
        {:ok, Enum.into(body, %{}), cowboy_req}
    end
  end

  def handle_part(headers, cowboy_req) do
    case :cow_multipart.form_data(headers) do
      {:data, field_name} ->
        {:ok, field_value, cowboy_req} = :cowboy_req.part_body(cowboy_req)
        {:ok, [{field_name, field_value}], cowboy_req}
      {:file, field_name, filename, content_type, content_transfer_encoding} ->
        {:ok, file_contents, cowboy_req} = stream_file(cowboy_req)
        {:ok, [{field_name, %{
          filename: filename,
          content_type: content_type,
          contents: file_contents
        }}], cowboy_req}
    end
  end

  def stream_file(cowboy_req, contents \\ []) do
    case :cowboy_req.part_body(cowboy_req) do
      {:ok, body, cowboy_req} ->
        {:ok, contents ++ [body], cowboy_req}
      {:more, body, cowboy_req} ->
        stream_file(cowboy_req, contents ++ body)
    end
  end
end
