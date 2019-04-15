defmodule Raxx.SessionTest do
  use ExUnit.Case
  doctest Raxx.Session

  describe "configuration" do
    test "configuration requires a key" do
      assert_raise(ArgumentError, ~r/:key/, fn ->
        Raxx.Session.config(store: Raxx.Session.SignedCookie)
      end)
    end

    test "configuration requires a store" do
      assert_raise(ArgumentError, ~r/:store/, fn ->
        Raxx.Session.config(key: "my_app_session")
      end)
    end
  end

  describe "default configuration" do
    setup %{} do
      config =
        Raxx.Session.config(
          key: "my_app_session",
          store: Raxx.Session.SignedCookie,
          secret_key_base: "squirrel",
          salt: "epsom"
        )

      {:ok, config: config}
    end

    test "can put, fetch and expire a session", %{config: config} do
      session = %{"user" => "friend"}

      response =
        Raxx.response(:ok)
        |> Raxx.Session.put(session, config)

      cookie_string = Raxx.get_header(response, "set-cookie")
      cookie = SetCookie.parse(cookie_string)
      assert cookie.key == "my_app_session"
      # TODO assert attributes
      session_cookie = cookie.value

      request =
        Raxx.request(:GET, "/")
        |> Raxx.set_header("cookie", Cookie.serialize({"my_app_session", session_cookie}))

      assert {:ok, ^session} = Raxx.Session.fetch(request, config)

      response =
        Raxx.response(:ok)
        |> Raxx.Session.drop(config)

      cookie_string = Raxx.get_header(response, "set-cookie")
      cookie = SetCookie.parse(cookie_string)
      assert cookie.key == "my_app_session"
      assert cookie.attributes.expires == "Thu, 01 Jan 1970 00:00:00 GMT"
      assert cookie.attributes.max_age == "0"
      assert "" = cookie.value
    end

    test "request without cookies returns no session", %{config: config} do
      request = Raxx.request(:GET, "/")
      assert {:ok, nil} = Raxx.Session.fetch(request, config)
    end

    test "request with other cookies returns no session", %{config: config} do
      request =
        Raxx.request(:GET, "/")
        |> Map.put(:headers, [{"cookie", "foo=1"}, {"cookie", "bar=2; baz=3"}])

      assert {:ok, nil} = Raxx.Session.fetch(request, config)
    end

    test "tampered with cookie, different key is an error", %{config: config} do
      session = %{"user" => "foe"}
      store_config = %store_mod{} = config.store
      session_cookie = store_mod.put(session, %{store_config | secret_key_base: "!!TAMPERED!!"})

      request =
        Raxx.request(:GET, "/")
        |> Raxx.set_header("cookie", Cookie.serialize({"my_app_session", session_cookie}))

      assert {:error, _} = Raxx.Session.fetch(request, config)
    end
  end
end
