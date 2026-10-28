defmodule Mine.Http.Websocket do
  @moduledoc """
  Establish and handle the WebSocket connection in addition to hearing
  also for incoming requests to be sent via the WebSocket.
  """
  alias Mine.{Game, HiScore}
  alias Timex.Duration
  alias Timex.Format.Duration.Formatters.Humanized

  @behaviour WebSock

  @doc false
  def init(remote_ip: remote_ip) do
    vsn = to_string(Application.spec(:mine, :vsn))
    msg = %{"type" => "vsn", "vsn" => vsn}
    {:push, {:text, Jason.encode!(msg)}, %{game_id: nil, remote_ip: remote_ip}}
  end

  @doc false
  def handle_in({msg, [opcode: :text]}, state) do
    msg
    |> Jason.decode!()
    |> process_data(state)
  end

  def handle_in(_any, state) do
    {:push, {:text, "eh?"}, state}
  end

  @doc false
  def handle_info(:tick, %{game_id: game_id} = state) do
    time =
      Game.time(game_id)
      |> Duration.from_seconds()
      |> Humanized.format()

    msg = %{"type" => "tick", "time" => time}
    {:push, {:text, Jason.encode!(msg)}, state}
  end

  def handle_info(:gameover, state) do
    msg = %{"type" => "gameover"}
    {:push, {:text, Jason.encode!(msg)}, state}
  end

  def handle_info(:win, state) do
    msg = %{"type" => "win"}
    {:push, {:text, Jason.encode!(msg)}, state}
  end

  def handle_info({:hiscore, {:ok, order}}, state) do
    send_hiscore(order, state)
  end

  defp send_hiscore(order \\ nil, state) do
    msg = %{"type" => "hiscore", "top_list" => build_top_list(), "position" => order}
    {:push, {:text, Jason.encode!(msg)}, state}
  end

  defp process_data(%{"type" => "create"}, state) do
    game_id = Ecto.UUID.generate()
    {:ok, _game} = Game.start(game_id)
    Game.subscribe(game_id)
    msg = %{"type" => "id", "id" => game_id}
    {:push, {:text, Jason.encode!(msg)}, %{state | game_id: game_id}}
  end

  defp process_data(%{"type" => "join", "id" => game_id}, state) do
    if Game.exists?(game_id) do
      Game.subscribe(game_id)
      {:ok, %{state | game_id: game_id}}
    else
      msg = %{"type" => "gameover", "error" => true}
      {:push, {:text, Jason.encode!(msg)}, state}
    end
  end

  defp process_data(%{"type" => "sweep", "x" => x, "y" => y}, %{game_id: game_id} = state) do
    if Game.exists?(game_id) do
      Game.sweep(game_id, x, y)
      draw(state)
    else
      msg = %{"type" => "gameover", "error" => true}
      {:push, {:text, Jason.encode!(msg)}, state}
    end
  end

  defp process_data(%{"type" => "flag", "x" => x, "y" => y}, %{game_id: game_id} = state) do
    if Game.exists?(game_id) do
      Game.toggle_flag(game_id, x, y)
      draw(state)
    else
      msg = %{"type" => "gameover", "error" => true}
      {:push, {:text, Jason.encode!(msg)}, state}
    end
  end

  defp process_data(%{"type" => "show"}, %{game_id: game_id} = state) do
    if Game.exists?(game_id) do
      draw(state)
    else
      msg = %{"type" => "gameover", "error" => true}
      {:push, {:text, Jason.encode!(msg)}, state}
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
      {:push, {:text, Jason.encode!(msg)}, state}
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
      |> format_score()

    msg = %{"type" => "draw", "html" => build_show(game_id), "score" => score, "flags" => flags}
    {:push, {:text, Jason.encode!(msg)}, state}
  end

  defp format_score(score) do
    score
    |> Integer.to_string()
    |> String.reverse()
    |> String.graphemes()
    |> Enum.chunk_every(3)
    |> Enum.map_join(".", &Enum.join/1)
    |> String.reverse()
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
      (Game.get_total_time() - entry.time)
      |> Duration.from_seconds()
      |> Humanized.format()

    score = format_score(entry.score)

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
