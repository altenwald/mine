defmodule Mine.Websocket do
  require Logger
  alias Mine.{Board, HiScore}
  alias Mine.Board.OnePlayer
  
  @behaviour :cowboy_websocket

  def init(req, opts) do
    Logger.info "[websocket] init req => #{inspect req}"
    remote_ip = case :cowboy_req.peer(req) do
      {{127, 0, 0, 1}, _} ->
        case :cowboy_req.header("x-forwarded-for", req) do
          {remote_ip, _} -> remote_ip
          _ -> "127.0.0.1"
        end
      {remote_ip, _} ->
        to_string(:inet.ntoa(remote_ip))
    end
    {:cowboy_websocket, req, [{:remote_ip, remote_ip}|opts]}
  end

  def websocket_init(remote_ip: remote_ip) do
    vsn = to_string(Application.spec(:mine)[:vsn])
    send self(), {:send, Jason.encode!(%{"type" => "vsn", "vsn" => vsn})}
    {:ok, %{board: nil, remote_ip: remote_ip}}
  end

  def websocket_handle({:text, msg}, state) do
    msg
    |> Jason.decode!()
    |> process_data(state)
  end

  def websocket_handle(_any, state) do
    {:reply, {:text, "eh?"}, state}
  end

  def websocket_info({:send, data}, state) do
    {:reply, {:text, data}, state}
  end
  def websocket_info({:timeout, _ref, msg}, state) do
    {:reply, {:text, msg}, state}
  end
  def websocket_info(:tick, %{board: board} = state) do
    time = Timex.Duration.from_erl({0, Board.time(board), 0})
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
    Logger.info "info => #{inspect info}"
    {:ok, state}
  end

  def websocket_terminate(reason, _state) do
    Logger.info "reason => #{inspect reason}"
    :ok
  end

  defp send_hiscore(order \\ nil, state) do
    msg = %{"type" => "hiscore",
            "top_list" => build_top_list(),
            "position" => order}
    {:reply, {:text, Jason.encode!(msg)}, state}
  end

  defp process_data(%{"type" => "create"}, state) do
    board = UUID.uuid4()
    {:ok, _board} = OnePlayer.start(board)
    Board.subscribe(board)
    msg = %{"type" => "id", "id" => board}
    {:reply, {:text, Jason.encode!(msg)}, %{state | board: board}}
  end
  defp process_data(%{"type" => "join", "id" => board}, state) do
    if Board.exists?(board) do
      Board.subscribe(board)
      {:ok, %{state | board: board}}
    else
      msg = %{"type" => "gameover", "error" => true}
      {:reply, {:text, Jason.encode!(msg)}, state}
    end  
  end
  defp process_data(%{"type" => "sweep", "x" => x, "y" => y}, %{board: board} = state) do
    if Board.exists?(board) do
      Board.sweep(board, x, y)
      draw(state)
    else
      msg = %{"type" => "gameover", "error" => true}
      {:reply, {:text, Jason.encode!(msg)}, state}  
    end
  end
  defp process_data(%{"type" => "flag", "x" => x, "y" => y}, %{board: board} = state) do
    if Board.exists?(board) do
      Board.toggle_flag(board, x, y)
      draw(state)
    else
      msg = %{"type" => "gameover", "error" => true}
      {:reply, {:text, Jason.encode!(msg)}, state}  
    end
  end
  defp process_data(%{"type" => "show"}, %{board: board} = state) do
    if Board.exists?(board) do
      draw(state)
    else
      msg = %{"type" => "gameover", "error" => true}
      {:reply, {:text, Jason.encode!(msg)}, state}
    end
  end
  defp process_data(%{"type" => "restart"}, %{board: board} = state) do
    if Board.exists?(board), do: Board.stop(board)
    {:ok, _} = OnePlayer.start(board)
    draw(state)
  end
  defp process_data(%{"type" => "toggle-pause"}, %{board: board} = state) do
    if Board.exists?(board) do
      Board.toggle_pause(board)
      draw(state)
    else
      msg = %{"type" => "gameover", "error" => true}
      {:reply, {:text, Jason.encode!(msg)}, state}
    end
  end
  defp process_data(%{"type" => "stop"}, %{board: board} = state) do
    if Board.exists?(board), do: Board.stop(board)
    {:ok, state}
  end
  defp process_data(%{"type" => "hiscore"}, state) do
    send_hiscore(state)
  end
  defp process_data(%{"type" => "set-hiscore-name", "name" => username}, state) do
    Board.hiscore(state.board, username, state.remote_ip)
    {:ok, state}
  end

  defp draw(%{board: board} = state) do
    flags = Board.flags(board)
    score = Board.score(board)
            |> Number.Delimit.number_to_delimited()
    msg = %{"type" => "draw",
            "html" => build_show(board),
            "score" => score,
            "flags" => flags}
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
    |> add(HiScore.top_list()
           |> Enum.with_index(1)
           |> Enum.map(&to_top_entry/1)
           |> Enum.join("</tr><tr>"))
    |> add("</tr></tbody></table>")
  end

  defp to_top_entry({entry, position}) do
    time = Timex.Duration.from_erl({0, OnePlayer.get_total_time() - entry.time, 0})
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
    "<table id='board'><tr>"
    |> add(cells
           |> Enum.with_index(1)
           |> Enum.map(&to_img/1)
           |> Enum.join("</tr><tr>"))
    |> add("</tr></table>")
  end
  defp build_show(board), do: build_show(Board.show(board))

  defp add(str1, str2), do: str1 <> str2

  defp img_src({_piece, :flag}), do: "img/cell_flag.png"
  defp img_src({_piece, :mine}), do: "img/cell_mine.png"
  defp img_src({_piece, :hidden}), do: "img/cell_hidden.png"
  defp img_src({piece, :show}), do: "img/cell_#{piece}.png"

  defp img(x, y, piece) do
    class = if rem(x + y, 2) == 0, do: "tile1", else: "tile2"
    "<td class='#{class}'><img src='#{img_src piece}' id='row#{y}-col#{x}' class='cell'></td>"
  end

  defp to_img({col, y}) do
    col
    |> Enum.with_index(1)
    |> Enum.map(fn {src, x} -> img(x, y, src) end)
    |> Enum.join()
  end
end
