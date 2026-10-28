defmodule Mine.HttpTest do
  use ExUnit.Case, async: false
  use Plug.Test
  alias Mine.Http.Router

  test "retrieve index.html" do
    conn = conn(:get, "/")

    opts = Router.init([])
    conn = Router.call(conn, opts)

    assert conn.state == :file
    assert conn.status == 200
    assert get_resp_header(conn, "content-type") == ["text/html; charset=utf-8"]
    assert conn.resp_body =~ "<title>Mine</title>"
  end

  test "retrieve index.js" do
    conn = conn(:get, "/js/index.js")

    opts = Router.init([])
    conn = Router.call(conn, opts)

    assert conn.state == :file
    assert conn.status == 200
    assert conn.resp_body =~ ~s|send({type: "hiscore"})|
  end

  test "not found" do
    conn = conn(:get, "/not-found")

    opts = Router.init([])
    conn = Router.call(conn, opts)

    assert conn.state == :sent
    assert conn.status == 404
  end

  test "forwarded client addresses are only accepted from trusted proxies" do
    local = conn(:get, "/") |> put_req_header("x-forwarded-for", "203.0.113.5")
    assert Router.remote_ip(local) == "203.0.113.5"

    direct = %{
      local
      | adapter:
          {Plug.Adapters.Test.Conn,
           %{
             elem(local.adapter, 1)
             | peer_data: %{address: {198, 51, 100, 7}, port: 1234, ssl_cert: nil}
           }}
    }

    assert Router.remote_ip(direct) == "198.51.100.7"
  end
end
