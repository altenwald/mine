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
end
