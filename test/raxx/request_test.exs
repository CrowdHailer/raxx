defmodule Raxx.RequestTest do
  use ExUnit.Case
  import Raxx.Request

  test "get sets the correct http method" do
    assert :GET == get("/").method
  end

  test "post sets the correct http method" do
    assert :POST == post("/").method
  end

  test "put sets the correct http method" do
    assert :PUT == put("/").method
  end

  test "patch sets the correct http method" do
    assert :PATCH == patch("/").method
  end

  test "delete sets the correct http method" do
    assert :DELETE == delete("/").method
  end

  test "options sets the correct http method" do
    assert :OPTIONS == options("/").method
  end

  test "head sets the correct http method" do
    assert :HEAD == head("/").method
  end

  test "scheme should be set from url, if provided" do
    # DEBT would prefer this to return atom.
    # Don't know what that would mean for non standard schemes, if such a thing is a concern of raxx.
    assert "http" == get("http:///").scheme
    assert "https" == get("https:///").scheme
    assert nil == get("/").scheme
  end

  test "host should be set from url if provided" do
    assert "myhost.com" == get("//myhost.com/").host
    assert nil == get("/").host
  end

  test "port should be set from url if provided" do
    # should port be assumed from scheme?
    # consider having a `Raxx.HTTP.get/1,2,3` function
    assert 80 == get("//myhost.com:80/").port
    assert nil == get("//myhost.com/").port
  end

  test "path should be set from url" do
    assert [] == get("/").path
    assert ["some", "path"] == get("/some/path").path
  end

  test "query should be set from url, if provided" do
    assert %{} == get("/").query
    assert %{} == get("/?").query
    assert %{"foo" => "bar"} == get("/?foo=bar").query
  end

  test "query can be passed as tuple" do
    assert %{"foo" => "bar"} == get({"/", %{"foo" => "bar"}}).query
    assert %{"foo" => "bar"} == get({"/?", %{"foo" => "bar"}}).query
  end

  test "tuple query is merged with query in string" do
    assert %{"foo" => "bar", "baz" => "foo"} == get({"/?baz=foo", %{"foo" => "bar"}}).query
    assert %{"foo" => "baz"} == get({"/?foo=bar", %{foo: "baz"}}).query
  end

  test "query with non_binary content is converted" do
    assert %{"foo" => "bar"} == get({"/", %{foo: "bar"}}).query
    assert %{"foo" => "5"} == get({"/", %{"foo" => 5}}).query
  end

  test "query can be built from nested query string" do
    assert %{"foo" => %{"bar" => "baz"}} == get("/?foo[bar]=baz").query
    assert %{"foo" => %{"bar" => "5"}} == get({"/", %{foo: %{bar: 5}}}).query
  end

  test "body can be set as binary" do
    assert "Hello, World!" == get("/", "Hello, World!").body
  end

  test "body can be an iolist" do
    assert ["Hello, World!"] == get("/", ["Hello, World!"]).body
  end

  test "body can be set as part of content map" do
    content = %{body: "Hello, World!", headers: [{"content-type", "application/x-www-form-urlencoded"}]}
    assert "Hello, World!" == get("/", content).body
  end

  test "extra headers can be added as last argument" do
    assert [{"referer", "/home"}] == get("/", [{"referer", "/home"}]).headers
    assert [{"referer", "/home"}] == get("/", "Hello, World!", [{"referer", "/home"}]).headers
  end

  # TODO pass in uri as map
  # TODO deep merge query
  # TODO pass in path as list
  # TODO document constructor methods
  # TODO consider invalid cases. i.e. get request with a body (probably rely on user to not ask for invalid queries)
end
