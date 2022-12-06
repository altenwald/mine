defmodule Mine.HttpTest do
  use ExUnit.Case, async: false
  use Plug.Test
  alias Mine.Http.Router

  describe "router" do
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

  describe "websocket" do
    test "connecting" do
      Application.put_env(:mine, :width, 4)
      Application.put_env(:mine, :height, 4)
      Application.put_env(:mine, :mines, [{1, 1}, {2, 2}, {3, 3}, {4, 4}])

      assert {:ok, pid} = Mine.WSCLI.start_link("http://localhost:4001/websession")
      assert_receive {:text, msg}
      assert %{"type" => "vsn", "vsn" => _} = Jason.decode!(msg)

      Mine.WSCLI.cast(pid, {:text, Jason.encode!(%{"type" => "create"})})
      assert_receive {:text, msg}
      assert %{"type" => "id", "id" => _game_id} = Jason.decode!(msg)

      Mine.WSCLI.cast(pid, {:text, Jason.encode!(%{"type" => "sweep", "x" => 1, "y" => 1})})
      assert_receive {:text, msg}

      assert %{"type" => "draw", "flags" => 0, "score" => "0", "html" => _html} =
               Jason.decode!(msg)

      assert_receive {:text, msg}
      assert %{"type" => "gameover"} = Jason.decode!(msg)
      refute_receive _
    end
  end
end
