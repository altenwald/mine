defmodule Mine.Http.WebsocketTest do
  use ExUnit.Case, async: false
  import Mine.WSCLI
  alias Mine.Game
  alias Mine.Http.Websocket

  @url "http://localhost:4001/websession"

  setup do
    Mine.HiScore.delete_all()
    :ok
  end

  test "connecting" do
    Application.put_env(:mine, :width, 4)
    Application.put_env(:mine, :height, 4)
    Application.put_env(:mine, :mines, [{1, 1}, {2, 2}, {3, 3}, {4, 4}])

    assert {:ok, pid} = connect_ws(@url)
    assert_ws_json_receive(%{"type" => "vsn", "vsn" => _})

    send_ws_json(pid, %{"type" => "create"})
    assert_ws_json_receive(%{"type" => "id", "id" => _game_id})

    send_ws_json(pid, %{"type" => "sweep", "x" => 1, "y" => 1})
    assert_ws_json_receive(%{"type" => "draw", "flags" => 0, "score" => "0", "html" => _html})

    assert_ws_json_receive(%{"type" => "gameover"})
    disconnect_ws(pid)
    refute_receive _
  end

  test "connecting from other IP" do
    req = %{
      bindings: %{},
      body_length: 0,
      cert: :undefined,
      has_body: false,
      headers: %{
        "connection" => "Upgrade",
        "host" => "localhost",
        "upgrade" => "websocket"
      },
      host: "localhost",
      host_info: :undefined,
      method: "GET",
      path: "/websession",
      path_info: :undefined,
      peer: {{8, 8, 8, 8}, 63_304},
      pid: self(),
      port: 80,
      qs: "",
      ref: Mine.Router.HTTP,
      scheme: "http",
      sock: {{127, 0, 0, 1}, 4_001},
      streamid: 1,
      version: :"HTTP/1.1"
    }

    assert {:cowboy_websocket, _req, [{:remote_ip, "8.8.8.8"}]} = Websocket.init(req, [])
  end

  test "sending ping" do
    assert {:ok, pid} = connect_ws(@url)
    assert_ws_json_receive(%{"type" => "vsn", "vsn" => _})
    send_ping(pid)
    assert_ws_text_receive("eh?")
    disconnect_ws(pid)
    refute_receive _
  end

  test "tick" do
    Application.put_env(:mine, :width, 4)
    Application.put_env(:mine, :height, 4)
    Application.put_env(:mine, :mines, [{1, 1}, {2, 2}, {3, 3}, {4, 4}])

    assert {:ok, pid} = connect_ws(@url)
    assert_ws_json_receive(%{"type" => "vsn", "vsn" => _})

    send_ws_json(pid, %{"type" => "create"})
    assert_ws_json_receive(%{"type" => "id", "id" => game_id})

    send(Game.get_pid(game_id), :tick)

    assert_ws_json_receive(%{"type" => "tick", "time" => "16 minutes, 38 seconds"})

    disconnect_ws(pid)
    refute_receive _
  end

  test "join" do
    Application.put_env(:mine, :width, 4)
    Application.put_env(:mine, :height, 4)
    Application.put_env(:mine, :mines, [{4, 4}])

    game_id = Ecto.UUID.generate()
    assert {:ok, pid} = connect_ws(@url)
    assert_ws_json_receive(%{"type" => "vsn", "vsn" => _})

    assert {:ok, _game_pid} = Game.start(game_id)
    send_ws_json(pid, %{"type" => "join", "id" => game_id})
    send_ws_json(pid, %{"type" => "show"})
    assert_ws_json_receive(%{"type" => "draw", "flags" => 0, "score" => "0", "html" => _html})

    disconnect_ws(pid)
    Game.stop(game_id)
    refute_receive _
  end

  test "cannot join" do
    assert {:ok, pid} = connect_ws(@url)
    assert_ws_json_receive(%{"type" => "vsn", "vsn" => _})

    game_id = Ecto.UUID.generate()
    send_ws_json(pid, %{"type" => "join", "id" => game_id})
    assert_ws_json_receive(%{"type" => "gameover", "error" => true})

    disconnect_ws(pid)
    refute_receive _
  end

  test "cannot sweep" do
    assert {:ok, pid} = connect_ws(@url)
    assert_ws_json_receive(%{"type" => "vsn", "vsn" => _})

    send_ws_json(pid, %{"type" => "sweep", "x" => 1, "y" => 1})
    assert_ws_json_receive(%{"type" => "gameover", "error" => true})

    disconnect_ws(pid)
    refute_receive _
  end

  test "cannot flag" do
    assert {:ok, pid} = connect_ws(@url)
    assert_ws_json_receive(%{"type" => "vsn", "vsn" => _})

    send_ws_json(pid, %{"type" => "flag", "x" => 1, "y" => 1})
    assert_ws_json_receive(%{"type" => "gameover", "error" => true})

    disconnect_ws(pid)
    refute_receive _
  end

  test "cannot show" do
    assert {:ok, pid} = connect_ws(@url)
    assert_ws_json_receive(%{"type" => "vsn", "vsn" => _})

    send_ws_json(pid, %{"type" => "show", "x" => 1, "y" => 1})
    assert_ws_json_receive(%{"type" => "gameover", "error" => true})

    disconnect_ws(pid)
    refute_receive _
  end

  test "cannot toggle pause" do
    assert {:ok, pid} = connect_ws(@url)
    assert_ws_json_receive(%{"type" => "vsn", "vsn" => _})

    send_ws_json(pid, %{"type" => "toggle-pause"})
    assert_ws_json_receive(%{"type" => "gameover", "error" => true})

    disconnect_ws(pid)
    refute_receive _
  end

  test "stop game" do
    game_id = Ecto.UUID.generate()
    assert {:ok, _game_pid} = Game.start(game_id)
    assert {:ok, pid} = connect_ws(@url)
    assert_ws_json_receive(%{"type" => "vsn", "vsn" => _})
    send_ws_json(pid, %{"type" => "join", "id" => game_id})
    send_ws_json(pid, %{"type" => "stop"})
    send_ws_json(pid, %{"type" => "show"})
    assert_ws_json_receive(%{"type" => "gameover", "error" => true})
    refute Game.exists?(game_id)
    disconnect_ws(pid)
    refute_receive _
  end

  test "restart game" do
    Application.put_env(:mine, :width, 4)
    Application.put_env(:mine, :height, 4)
    Application.put_env(:mine, :mines, [{4, 4}])

    assert {:ok, pid} = connect_ws(@url)
    assert_ws_json_receive(%{"type" => "vsn", "vsn" => _})

    send_ws_json(pid, %{"type" => "create"})
    assert_ws_json_receive(%{"type" => "id", "id" => _game_id})

    send_ws_json(pid, %{"type" => "sweep", "x" => 1, "y" => 1})

    assert_ws_json_receive(%{"type" => "draw", "flags" => 0, "score" => "14.985", "html" => _html})

    assert_ws_json_receive(%{"type" => "win"})

    send_ws_json(pid, %{"type" => "restart"})
    assert_ws_json_receive(%{"type" => "draw", "flags" => 0, "score" => "0", "html" => _html})

    disconnect_ws(pid)
    refute_receive _
  end

  test "win" do
    Application.put_env(:mine, :width, 4)
    Application.put_env(:mine, :height, 4)
    Application.put_env(:mine, :mines, [{4, 4}])

    assert {:ok, pid} = connect_ws(@url)
    assert_ws_json_receive(%{"type" => "vsn", "vsn" => _})

    send_ws_json(pid, %{"type" => "create"})
    assert_ws_json_receive(%{"type" => "id", "id" => _game_id})

    send_ws_json(pid, %{"type" => "sweep", "x" => 1, "y" => 1})

    assert_ws_json_receive(%{"type" => "draw", "flags" => 0, "score" => "14.985", "html" => _html})

    assert_ws_json_receive(%{"type" => "win"})

    send_ws_json(pid, %{"type" => "set-hiscore-name", "name" => "Duendecillo"})

    assert_ws_json_receive(
      %{"type" => "hiscore", "position" => 1, "top_list" => "<table " <> _},
      500
    )

    send_ws_json(pid, %{"type" => "hiscore"})

    assert_ws_json_receive(%{"type" => "hiscore", "position" => nil, "top_list" => "<table " <> _})

    disconnect_ws(pid)
    refute_receive _
  end

  test "boom" do
    Application.put_env(:mine, :width, 4)
    Application.put_env(:mine, :height, 4)
    Application.put_env(:mine, :mines, [{4, 4}])

    assert {:ok, pid} = connect_ws(@url)
    assert_ws_json_receive(%{"type" => "vsn", "vsn" => _})

    send_ws_json(pid, %{"type" => "create"})
    assert_ws_json_receive(%{"type" => "id", "id" => _game_id})

    send_ws_json(pid, %{"type" => "sweep", "x" => 4, "y" => 4})
    assert_ws_json_receive(%{"type" => "draw", "flags" => 0, "score" => "0", "html" => html})
    assert html =~ "cell_mine.png"

    assert_ws_json_receive(%{"type" => "gameover"})

    disconnect_ws(pid)
    refute_receive _
  end

  test "flag error" do
    Application.put_env(:mine, :width, 4)
    Application.put_env(:mine, :height, 4)
    Application.put_env(:mine, :mines, [{1, 1}, {2, 2}, {3, 3}, {4, 4}])

    assert {:ok, pid} = connect_ws(@url)
    assert_ws_json_receive(%{"type" => "vsn", "vsn" => _})

    send_ws_json(pid, %{"type" => "create"})
    assert_ws_json_receive(%{"type" => "id", "id" => _game_id})

    send_ws_json(pid, %{"type" => "sweep", "x" => 1, "y" => 3})
    assert_ws_json_receive(%{"type" => "draw", "flags" => 0, "score" => "999", "html" => _html})

    send_ws_json(pid, %{"type" => "flag", "x" => 2, "y" => 3})
    assert_ws_json_receive(%{"type" => "draw", "flags" => 1, "score" => "999", "html" => _html})

    send_ws_json(pid, %{"type" => "sweep", "x" => 1, "y" => 3})
    assert_ws_json_receive(%{"type" => "draw", "flags" => 1, "score" => "999", "html" => html})
    assert html =~ "cell_flag_error.png"

    assert_ws_json_receive(%{"type" => "gameover"})

    disconnect_ws(pid)
    refute_receive _
  end

  test "toggle flag" do
    Application.put_env(:mine, :width, 4)
    Application.put_env(:mine, :height, 4)
    Application.put_env(:mine, :mines, [{4, 4}])

    assert {:ok, pid} = connect_ws(@url)
    assert_ws_json_receive(%{"type" => "vsn", "vsn" => _})

    send_ws_json(pid, %{"type" => "create"})
    assert_ws_json_receive(%{"type" => "id", "id" => _game_id})

    send_ws_json(pid, %{"type" => "flag", "x" => 4, "y" => 4})
    assert_ws_json_receive(%{"type" => "draw", "flags" => 1, "score" => "0", "html" => _html})

    send_ws_json(pid, %{"type" => "flag", "x" => 4, "y" => 4})
    assert_ws_json_receive(%{"type" => "draw", "flags" => 0, "score" => "0", "html" => _html})

    disconnect_ws(pid)
    refute_receive _
  end

  test "toggle pause" do
    Application.put_env(:mine, :width, 4)
    Application.put_env(:mine, :height, 4)
    Application.put_env(:mine, :mines, [{1, 1}, {2, 2}, {3, 3}, {4, 4}])

    assert {:ok, pid} = connect_ws(@url)
    assert_ws_json_receive(%{"type" => "vsn", "vsn" => _})

    send_ws_json(pid, %{"type" => "create"})
    assert_ws_json_receive(%{"type" => "id", "id" => _game_id})

    send_ws_json(pid, %{"type" => "sweep", "x" => 1, "y" => 4})
    assert_ws_json_receive(%{"type" => "draw", "flags" => 0, "score" => "3.996", "html" => _html})

    assert_ws_json_receive(%{"type" => "tick", "time" => "16 minutes, 38 seconds"}, 2_000)

    send_ws_json(pid, %{"type" => "toggle-pause"})

    assert_ws_json_receive(%{
      "type" => "draw",
      "flags" => 0,
      "score" => "3.996",
      "html" => "<table id='game_id'><tr></tr></table>"
    })

    refute_receive {:text, _data}, 1_500

    send_ws_json(pid, %{"type" => "toggle-pause"})
    assert_ws_json_receive(%{"type" => "draw", "flags" => 0, "score" => "3.996", "html" => html})
    assert html != "<table id='game_id'><tr></tr></table>"

    assert_ws_json_receive(%{"type" => "tick", "time" => "16 minutes, 37 seconds"}, 1_500)

    disconnect_ws(pid)
    refute_receive _
  end
end
