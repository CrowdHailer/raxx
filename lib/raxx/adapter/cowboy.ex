defmodule Raxx.Adapters.Cowboy.ServerSentEvents do
  def upgrade(cowboy_request, %{handler: handler, options: options}) do
    # If invalid content headers should return a 501
    # http://ninenines.eu/docs/en/cowboy/1.0/guide/rest_flowcharts/
    # If not a get method should return 405
    # ^^^ This logic should be in Raxx.SSE not in the adapter as same for all servers
    {:ok, req1} = :cowboy_req.chunked_reply(
      200,
      [{"content-type", "text/event-stream"},
      {"cache-control", "no-cache"},
      {"connection", "keep-alive"}],
      cowboy_request
    )


    case handler.open(options) do
      # Possibly return list of events so we can send each an noop is empty list
      :nil -> :no_op
      #  FIXME event untested
      event ->
        :ok = :cowboy_req.chunk(Raxx.ServerSentEvents.event_to_string(event), cowboy_request)
      # FIXME if closes connection at this point should return 204
    end
    {:loop, req1, {handler, options}}
  end
  # FIXME test what happens when a request that does not accept text/event-stream is sent to a SSE endpoint
  # Send an open or failure message to the SSE Handler
  # Might want the failure message to just be part of a generalised error handler

  def info(message, req, state = {router, raxx_options}) do
    case router.info(message, raxx_options) do
      # FIXME nil untested
      :nil ->
        {:loop, req, state}
      event ->
        :ok = :cowboy_req.chunk(Raxx.ServerSentEvents.event_to_string(event), req)
        # Empty string closes communication from client end so loop is fine return value here
        {:loop, req, state}
    end
  end
end

defmodule Raxx.Adapters.Cowboy.Handler do
  def init({:tcp, :http}, req, opts = {router, raxx_options}) do
    case router.handle_request(normalise_request(req), raxx_options) do
      upgrade = %{upgrade: Raxx.ServerSentEvents} ->
        Raxx.Adapters.Cowboy.ServerSentEvents.upgrade(req, upgrade)
      response ->
        respond(req, response, opts)
    end
  end

  def info(message, req, state) do
    Raxx.Adapters.Cowboy.ServerSentEvents.info(message, req, state)
  end

  def handle(req, state) do
    # FIXME work out if this is needed anywhere
    {:ok, req, state}
  end

  def terminate(_reason, _req, _state) do
    # TODO closing message on SSE events
    :ok
  end

  def respond(cowboy_request, %{status: status, headers: headers, body: body}, opts) do
    headers = Map.merge(%{"content-type" => "text/html"}, headers) |> Enum.map(fn (x) -> x end)
    {:ok, resp} = :cowboy_req.reply(status, headers, body, cowboy_request)
    {:ok, resp, opts}
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
  # Untested, consider case without charset.
  def parse_req_body(cowboy_req, {"application", "x-www-form-urlencoded", []}) do
    {:ok, body_qs, cowboy_req}  = :cowboy_req.body_qs(cowboy_req, [])
    body = Enum.into(body_qs, %{})
    {:ok, body, cowboy_req}
  end
  def parse_req_body(cowboy_req, {"multipart", "form-data", _}) do
    {:ok, body, cowboy_req} = multipart(cowboy_req)
    {:ok, body, cowboy_req}
  end
  def parse_req_body(cowboy_req, content_type) do
    {:ok, body, cowboy_req}  = :cowboy_req.body(cowboy_req, [])
    {:ok, body, cowboy_req}
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
      {:file, field_name, filename, content_type, _content_transfer_encoding} ->
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
