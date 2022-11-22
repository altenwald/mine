defmodule Mine.Http.Websocket do
  @moduledoc """
  Establish and handle the WebSocket connection in addition to hearing
  also for incoming requests to be sent via the WebSocket.
  """
  require Logger
  alias Mine.{Game, HiScore}

  @behaviour :cowboy_websocket

  @doc false
  def init(req, opts) do
    Logger.info("[websocket] init req => #{inspect(req)}")

    remote_ip =
      case :cowboy_req.peer(req) do
        {{127, 0, 0, 1}, _} ->
          :cowboy_req.header("x-forwarded-for", req, "127.0.0.1")

        {remote_ip, _} ->
          to_string(:inet.ntoa(remote_ip))
      end

    {:cowboy_websocket, req, [{:remote_ip, remote_ip} | opts]}
  end

  @doc false
  def websocket_init(remote_ip: remote_ip) do
    vsn = to_string(Application.spec(:mine)[:vsn])
    send(self(), {:send, Jason.encode!(%{"type" => "vsn", "vsn" => vsn})})
    {:ok, %{game_id: nil, remote_ip: remote_ip}}
  end

  @doc false
  def websocket_handle({:text, msg}, state) do
    msg
    |> Jason.decode!()
    |> process_data(state)
  end

  def websocket_handle(_any, state) do
    {:reply, {:text, "eh?"}, state}
  end

  @doc false
  def websocket_info({:send, data}, state) do
    {:reply, {:text, data}, state}
  end

  def websocket_info({:timeout, _ref, msg}, state) do
    {:reply, {:text, msg}, state}
  end

  def websocket_info(:tick, %{game_id: game_id} = state) do
    time =
      Timex.Duration.from_erl({0, Game.time(game_id), 0})
      |> Timex.Format.Duration.Formatters.Humanized.format()

    msg = %{"type" => "tick", "time" => time}
    {:reply, {:text, Jason.encode!(msg)}, state}
  end

  def websocket_info(:gameover, state) do
    msg = %{"type" => "gameover"}
    {:reply, {:text, Jason.encode!(msg)}, state}
  end

  def websocket_info(:win, state) do
    msg = %{"type" => "win"}
    {:reply, {:text, Jason.encode!(msg)}, state}
  end

  def websocket_info({:hiscore, {:ok, order}}, state) do
    send_hiscore(order, state)
  end

  def websocket_info(info, state) do
    Logger.info("info => #{inspect(info)}")
    {:ok, state}
  end

  @doc false
  def websocket_terminate(reason, _state) do
    Logger.info("reason => #{inspect(reason)}")
    :ok
  end

  defp send_hiscore(order \\ nil, state) do
    msg = %{"type" => "hiscore", "top_list" => build_top_list(), "position" => order}
    {:reply, {:text, Jason.encode!(msg)}, state}
  end

  defp process_data(%{"type" => "create"}, state) do
    game_id = Ecto.UUID.generate()
    {:ok, _game} = Game.start(game_id)
    Game.subscribe(game_id)
    msg = %{"type" => "id", "id" => game_id}
    {:reply, {:text, Jason.encode!(msg)}, %{state | game_id: game_id}}
  end

  defp process_data(%{"type" => "join", "id" => game_id}, state) do
    if Game.exists?(game_id) do
      Game.subscribe(game_id)
      {:ok, %{state | game_id: game_id}}
    else
      msg = %{"type" => "gameover", "error" => true}
      {:reply, {:text, Jason.encode!(msg)}, state}
    end
  end

  defp process_data(%{"type" => "sweep", "x" => x, "y" => y}, %{game_id: game_id} = state) do
    if Game.exists?(game_id) do
      Game.sweep(game_id, x, y)
      draw(state)
    else
      msg = %{"type" => "gameover", "error" => true}
      {:reply, {:text, Jason.encode!(msg)}, state}
    end
  end

  defp process_data(%{"type" => "flag", "x" => x, "y" => y}, %{game_id: game_id} = state) do
    if Game.exists?(game_id) do
      Game.toggle_flag(game_id, x, y)
      draw(state)
    else
      msg = %{"type" => "gameover", "error" => true}
      {:reply, {:text, Jason.encode!(msg)}, state}
    end
  end

  defp process_data(%{"type" => "show"}, %{game_id: game_id} = state) do
    if Game.exists?(game_id) do
      draw(state)
    else
      msg = %{"type" => "gameover", "error" => true}
      {:reply, {:text, Jason.encode!(msg)}, state}
    end
  end

  defp process_data(%{"type" => "restart"}, %{game_id: game_id} = state) do
    if Game.exists?(game_id), do: Game.stop(game_id)
    {:ok, _} = Game.start(game_id)
    draw(state)
  end

  defp process_data(%{"type" => "toggle-pause"}, %{game_id: game_id} = state) do
    if Game.exists?(game_id) do
      Game.toggle_pause(game_id)
      draw(state)
    else
      msg = %{"type" => "gameover", "error" => true}
      {:reply, {:text, Jason.encode!(msg)}, state}
    end
  end

  defp process_data(%{"type" => "stop"}, %{game_id: game_id} = state) do
    if Game.exists?(game_id), do: Game.stop(game_id)
    {:ok, state}
  end

  defp process_data(%{"type" => "hiscore"}, state) do
    send_hiscore(state)
  end

  defp process_data(%{"type" => "set-hiscore-name", "name" => username}, state) do
    Game.hiscore(state.game_id, username, state.remote_ip)
    {:ok, state}
  end

  defp draw(%{game_id: game_id} = state) do
    flags = Game.flags(game_id)

    score =
      Game.score(game_id)
      |> Number.Delimit.number_to_delimited()

    msg = %{"type" => "draw", "html" => build_show(game_id), "score" => score, "flags" => flags}
    {:reply, {:text, Jason.encode!(msg)}, state}
  end

  defp build_top_list do
    """
    <table class="table table-stripped table-sm" id="toplist">
    <thead>
      <tr>
        <th>#</th>
        <th>Name</th>
        <th class="text-right">Time</th>
        <th class="text-right">Score</th>
      </tr>
    </thead>
    <tbody>
      <tr>
    """
    |> add(
      HiScore.top_list()
      |> Enum.with_index(1)
      |> Enum.map_join("</tr><tr>", &to_top_entry/1)
    )
    |> add("</tr></tbody></table>")
  end

  defp to_top_entry({entry, position}) do
    time =
      Timex.Duration.from_erl({0, Game.get_total_time() - entry.time, 0})
      |> Timex.Format.Duration.Formatters.Humanized.format()

    score = Number.Delimit.number_to_delimited(entry.score)

    """
    <th scope="row">#{position}</td>
    <td>#{entry.name}</td>
    <td class="text-right">#{time}</td>
    <td class="text-right">#{score}</td>
    """
  end

  defp build_show(cells) when is_list(cells) do
    "<table id='game_id'><tr>"
    |> add(
      cells
      |> Enum.with_index(1)
      |> Enum.map_join("</tr><tr>", &to_img/1)
    )
    |> add("</tr></table>")
  end

  defp build_show(game_id), do: build_show(Game.show(game_id))

  defp add(str1, str2), do: str1 <> str2

  defp img_src({_piece, :flag}), do: "img/cell_flag.png"
  defp img_src({_piece, :flag_error}), do: "img/cell_flag_error.png"
  defp img_src({_piece, :mine}), do: "img/cell_mine.png"
  defp img_src({_piece, :hidden}), do: "img/cell_hidden.png"
  defp img_src({piece, :show}), do: "img/cell_#{piece}.png"

  defp img(x, y, piece) do
    class = if rem(x + y, 2) == 0, do: "tile1", else: "tile2"
    "<td class='#{class}'><img src='#{img_src(piece)}' id='row#{y}-col#{x}' class='cell'></td>"
  end

  defp to_img({col, y}) do
    col
    |> Enum.with_index(1)
    |> Enum.map_join(fn {src, x} -> img(x, y, src) end)
  end
end
