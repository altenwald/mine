defmodule Mine.Websocket do
  require Logger
  alias Mine.Board
  
  @behaviour :cowboy_websocket

  def init(req, opts) do
    Logger.info "[websocket] init req => #{inspect req}"
    {:cowboy_websocket, req, opts}
  end

  def websocket_init(_opts) do
    vsn = to_string(Application.spec(:mine)[:vsn])
    send self(), {:send, Jason.encode!(%{"type" => "vsn", "vsn" => vsn})}
    {:ok, nil}
  end

  def websocket_handle({:text, msg}, board) do
    msg
    |> Jason.decode!()
    |> process_data(board)
  end

  def websocket_handle(_any, board) do
    {:reply, {:text, "eh?"}, board}
  end

  def websocket_info({:send, data}, board) do
    {:reply, {:text, data}, board}
  end
  def websocket_info({:timeout, _ref, msg}, board) do
    {:reply, {:text, msg}, board}
  end

  def websocket_info(info, board) do
    Logger.info "info => #{inspect info}"
    {:ok, board}
  end

  def websocket_terminate(reason, _board) do
    Logger.info "reason => #{inspect reason}"
    :ok
  end

  defp process_data(%{"type" => "create"}, _board) do
    board = UUID.uuid4()
    {:ok, _board} = Board.start_link(board)
    msg = %{"type" => "id", "id" => board}
    {:reply, {:text, Jason.encode!(msg)}, board}
  end
  defp process_data(%{"type" => "join", "id" => board}, _board) do
    if Board.exists?(board) do
      {:ok, board}
    else
      msg = %{"type" => "gameover", "error" => true}
      {:reply, {:text, Jason.encode!(msg)}, board}
    end  
  end
  defp process_data(%{"type" => "sweep", "x" => x, "y" => y}, board) do
    if Board.exists?(board) do
      Board.sweep(board, x, y)
      draw(board)
    else
      msg = %{"type" => "gameover", "error" => true}
      {:reply, {:text, Jason.encode!(msg)}, board}  
    end
  end
  defp process_data(%{"type" => "flag", "x" => x, "y" => y}, board) do
    if Board.exists?(board) do
      Board.toggle_flag(board, x, y)
      draw(board)
    else
      msg = %{"type" => "gameover", "error" => true}
      {:reply, {:text, Jason.encode!(msg)}, board}  
    end
  end
  defp process_data(%{"type" => "show"}, board) do
    if Board.exists?(board) do
      draw(board)
    else
      msg = %{"type" => "gameover", "error" => true}
      {:reply, {:text, Jason.encode!(msg)}, board}
    end
  end
  defp process_data(%{"type" => "restart"}, board) do
    if Board.exists?(board), do: Board.stop(board)
    {:ok, _} = Board.start_link(board)
    draw(board)
  end
  defp process_data(%{"type" => "stop"}, board) do
    if Board.exists?(board), do: Board.stop(board)
    {:ok, board}
  end

  defp draw(board) do
    flags = Board.flags(board)
    score = Board.score(board)
    msg = %{"type" => "draw",
            "html" => build_show(board),
            "score" => score,
            "flags" => flags}
    {:reply, {:text, Jason.encode!(msg)}, board}
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
    "<td><img src='#{img_src piece}' id='row#{y}-col#{x}' class='cell'></td>"
  end

  defp to_img({col, y}) do
    col
    |> Enum.with_index(1)
    |> Enum.map(fn {src, x} -> img(x, y, src) end)
    |> Enum.join()
  end
end
