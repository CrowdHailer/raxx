defmodule Raxx.Headers do
  @moduledoc """
  BETA: unsure if this module should world on request/response objects?
  """

  @doc """
  content type is a field of type media type (same as Accept)
  https://tools.ietf.org/html/rfc7231#section-3.1.1.5

  Content type should be send with any content.
  If not can assume "application/octet-stream" or try content sniffing.
  because of security risks it is recommended to be able to disable sniffing
  """
  def content_type(%{headers: headers}) do
    case :proplists.get_value("content-type", headers) do
      :undefined ->
        :undefined
      media_type ->
        parse_media_type(media_type)
    end
  end

  @doc """
  https://tools.ietf.org/html/rfc7231#section-3.1.1.1
  """
  def parse_media_type(media_type) do
    case String.split(media_type, ";") do
      [type, modifier] ->
        {type, String.strip(modifier)}
      [type] ->
        {type, ""}
    end
  end
end
