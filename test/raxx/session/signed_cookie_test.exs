defmodule Raxx.Session.SignedCookieTest do
  use ExUnit.Case

  alias Raxx.Session.SignedCookie
  doctest SignedCookie

  setup %{} do
    config = SignedCookie.config(secret: "super secret", previous_secrets: ["old secret"])

    Raxx.response(:no_content)
    |> SignedCookie.embed({:user, 25}, config)
    |> Raxx.get_header("set-cookie")

    {:ok, %{config: config}}
  end

  test "A secret must be provided when configuring signed cookie sessions" do
    assert_raise RuntimeError, fn() ->
      SignedCookie.config([])
    end
  end

  test "sessions can be verified against previous secrets", %{config: config} do
    cookie = "raxx.session=g2gCZAAEdXNlcmEZ--Y-hUeuqz5kR6y9AmF5QdTGnQ7uFme90zqYIICuekdp0="
    assert {:ok, {:user, 25}} = Raxx.request(:GET, "/")
    |> Raxx.set_header("cookie", cookie)
    |> SignedCookie.extract(config)
  end

  test "Error for no cookies sent", %{config: config} do
    assert {:error, :no_cookies_sent} = Raxx.request(:GET, "/")
    |> SignedCookie.extract(config)
  end

  test "Error for no session cookie sent", %{config: config} do
    assert {:error, :no_session_cookie} = Raxx.request(:GET, "/")
    |> Raxx.set_header("cookie", "")
    |> SignedCookie.extract(config)
  end

  test "Error for unsigned session", %{config: config} do
    assert {:error, :invalid_session_cookie} = Raxx.request(:GET, "/")
    |> Raxx.set_header("cookie", "raxx.session=g2gCZAAEdXNlcmEZ")
    |> SignedCookie.extract(config)
  end

  test "Error for tampered session", %{config: config} do
    assert {:error, :could_not_verify_signature} = Raxx.request(:GET, "/")
    |> Raxx.set_header("cookie", "raxx.session=g2gCZAAEdXNlcmEZ--5jKDb7R4i5HOq9ZSbeIAxB4GaO5RXfkOKm4CX7YSeJk=")
    |> SignedCookie.extract(config)
  end
end
