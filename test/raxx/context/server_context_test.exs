defmodule Raxx.Context.ServerContextTest do
  use ExUnit.Case

  alias Raxx.Context.ServerContext

  @moduletag :context

  @localhost {127, 0, 0, 1}
  @google_dns {8, 8, 8, 8}

  @server_context_1 %{remote_ip_address: @localhost, properties: %{foo: :bar}}
  @server_context_2 %{remote_ip_address: @google_dns, properties: %{baz: :ban}}

  test "with no server context set, retrieve/0 will return a default structure" do
    assert %{} == ServerContext.retrieve()
  end

  test "set/1 and retrieve/0" do
    ServerContext.set(@server_context_1)

    assert @server_context_1 == ServerContext.retrieve()

    ServerContext.set(@server_context_2)
    assert @server_context_2 == ServerContext.retrieve()
  end

  test "Raxx.Context snapshot contains the Raxx.Context.ServerContext as well" do
    ServerContext.set(@server_context_1)
    snapshot = Raxx.Context.get_snapshot()

    ServerContext.set(@server_context_2)
    assert @server_context_2 == ServerContext.retrieve()

    Raxx.Context.restore_snapshot(snapshot)
    assert @server_context_1 == ServerContext.retrieve()
  end
end
