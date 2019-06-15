defmodule Mine.Board do
  use GenServer

  alias Mine.{Board, HiScore}

  @default_mines 40
  @default_height 16
  @default_width 16
  @default_time 999

  defstruct cells: [],
            mines: nil,
            width: nil,
            height: nil,
            flags: 0,
            score: 0,
            status: :play,
            timer: nil,
            time: @default_time,
            consumers: [],
            username: nil

  def child_spec(init_args) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [init_args]},
      restart: :transient
    }
  end

  defp via(board) do
    {:via, Registry, {Mine.Board.Registry, board}}
  end

  def start_link(name) do
    width = Application.get_env(:mine, :width, @default_width)
    height = Application.get_env(:mine, :height, @default_height)
    mines = Application.get_env(:mine, :mines, @default_mines)
    time = Application.get_env(:mine, :total_time, @default_time)
    GenServer.start_link __MODULE__, [width, height, mines, time], name: via(name)
  end

  def start(board) do
    DynamicSupervisor.start_child Mine.Boards, {__MODULE__, board}
  end

  def exists?(board) do
    case Registry.lookup(Mine.Board.Registry, board) do
      [{_pid, nil}] -> true
      [] -> false
    end
  end

  def stop(name), do: GenServer.stop via(name)
  def show(name), do: GenServer.call via(name), :show
  def sweep(name, x, y), do: GenServer.cast via(name), {:sweep, x, y}
  def flag(name, x, y), do: GenServer.cast via(name), {:flag, x, y}
  def unflag(name, x, y), do: GenServer.cast via(name), {:unflag, x, y}
  def toggle_flag(name, x, y), do: GenServer.cast via(name), {:toggle_flag, x, y}
  def flags(name), do: GenServer.call via(name), :flags
  def score(name), do: GenServer.call via(name), :score
  def status(name), do: GenServer.call via(name), :status
  def subscribe(name), do: GenServer.cast via(name), {:subscribe, self()}
  def time(name), do: GenServer.call via(name), :time
  def hiscore(name, username, remote_ip) do
    GenServer.cast via(name), {:hiscore, username, remote_ip}
  end

  @impl true
  def init([width, height, mines, time]) do
    cells = gen_clean(width, height)
            |> place_mines(width, height, mines)
            |> place_hints(width, height)
    {:ok, timer} = :timer.send_interval :timer.seconds(1), self(), :tick
    {:ok, %Board{cells: cells,
                 width: width,
                 height: height,
                 mines: mines,
                 time: time,
                 timer: timer}}
  end

  defp place_hints(cells, width, height) do
    for i <- 1..height, into: %{} do
      {i, for j <- 1..width, into: %{} do
        case cells[i][j] do
          {:mine, status} ->
            {j, {:mine, status}}
          {0, status} ->
            get_n = fn(x, y) -> get_n(cells, x, y, width, height) end
            mines = get_n.(i-1, j-1) +
                    get_n.(i-1, j) +
                    get_n.(i-1, j+1) +
                    get_n.(i, j+1) +
                    get_n.(i+1, j+1) +
                    get_n.(i+1, j) +
                    get_n.(i+1, j-1) +
                    get_n.(i, j-1)
            {j, {mines, status}}
        end
      end}
    end
  end

  defp get_n(_cells, 0, _, _w, _h), do: 0
  defp get_n(_cells, _, 0, _w, _h), do: 0
  defp get_n(_cells, i, _, _w, h) when i > h, do: 0
  defp get_n(_cells, _, j, w, _h) when j > w, do: 0
  defp get_n(cells, i, j, _w, _h) do
    case cells[i][j] do
      {:mine, _} -> 1
      {n, _} when is_integer(n) -> 0
    end
  end

  defp place_mines(cells, _width, _height, 0), do: cells
  defp place_mines(cells, width, height, i) do
    x = Enum.random(1..width)
    y = Enum.random(1..height)
    if cells[y][x] == {:mine, :hidden} do
      place_mines(cells, width, height, i)
    else
      cells
      |> put_in([y, x], {:mine, :hidden})
      |> place_mines(width, height, i - 1)
    end
  end

  defp gen_clean(width, height) do
    for y <- 1..height, into: %{} do
      {y, for(x <- 1..width, into: %{}, do: {x, {0, :hidden}})}
    end
  end

  @impl true
  def handle_call(:show, _from, board) do
    cells = for {_, rows} <- board.cells do
      for {_, cell} <- rows, do: cell
    end
    {:reply, cells, board}
  end

  def handle_call(:flags, _from, board), do: {:reply, board.flags, board}
  def handle_call(:score, _from, board), do: {:reply, board.score, board}
  def handle_call(:status, _from, board), do: {:reply, board.status, board}
  def handle_call(:time, _from, board), do: {:reply, board.time, board}

  @impl true
  def handle_cast({:hiscore, username, remote_ip}, %Board{score: score, time: time} = board) do
    {:ok, hiscore} = HiScore.save(username, score, time, remote_ip)
    send_to_all(board.consumers, {:hiscore, HiScore.get_order(hiscore.id)})
    {:noreply, %Board{board | username: username}}
  end
  def handle_cast({:sweep, _, _}, %Board{status: :gameover} = board) do
    {:noreply, board}
  end
  def handle_cast({:sweep, x, y}, %Board{cells: cells} = board) do
    case cells[y][x] do
      {_, :show} -> {:noreply, board}
      {_, :flag} -> {:noreply, board}
      {:mine, _} ->
        cells = put_in(cells[y][x], {:mine, :show})
        send_to_all(board.consumers, :gameover)
        {:noreply, %Board{board | cells: cells, status: :gameover}}
      {0, _} ->
        {cells, score} = discover({cells, board.score}, y, x, board.width, board.height, board.time)
        status = if is_filled?(cells) do
          send_to_all(board.consumers, :win)
          :gameover
        else
          board.status
        end
        {:noreply, %Board{board | cells: cells, score: score, status: status}}
      {n, _} ->
        cells = put_in(cells[y][x], {n, :show})
        status = if is_filled?(cells) do
          send_to_all(board.consumers, :win)
          :gameover
        else
          board.status
        end
        {:noreply, %Board{board | cells: cells, status: status}}
    end
  end

  def handle_cast({:flag, _, _}, %Board{status: :gameover} = board) do
    {:noreply, board}
  end
  def handle_cast({:flag, x, y}, %Board{cells: cells} = board) do
    case cells[y][x] do
      {_, :flag} -> {:noreply, board}
      {_, :show} -> {:noreply, board}
      {value, :hidden} ->
        cells = put_in(cells[y][x], {value, :flag})
        status = if is_filled?(cells) do
          send_to_all(board.consumers, :win)
          :gameover
        else
          board.status
        end
        {:noreply, %Board{board | cells: cells, flags: board.flags + 1, status: status}}
    end
  end

  def handle_cast({:unflag, _, _}, %Board{status: :gameover} = board) do
    {:noreply, board}
  end
  def handle_cast({:unflag, x, y}, %Board{cells: cells} = board) do
    case cells[y][x] do
      {value, :flag} ->
        cells = put_in(cells[y][x], {value, :hidden})
        {:noreply, %Board{board | cells: cells, flags: board.flags - 1}}
      {_, :show} -> {:noreply, board}
      {_, :hidden} -> {:noreply, board}
    end
  end

  def handle_cast({:toggle_flag, _, _}, %Board{status: :gameover} = board) do
    {:noreply, board}
  end
  def handle_cast({:toggle_flag, x, y}, %Board{cells: cells} = board) do
    case cells[y][x] do
      {value, :flag} ->
        cells = put_in(cells[y][x], {value, :hidden})
        {:noreply, %Board{board | cells: cells, flags: board.flags - 1}}
      {_, :show} -> {:noreply, board}
      {value, :hidden} ->
        cells = put_in(cells[y][x], {value, :flag})
        status = if is_filled?(cells) do
          send_to_all(board.consumers, :win)
          :gameover
        else
          board.status
        end
        {:noreply, %Board{board | cells: cells, flags: board.flags + 1, status: status}}
    end
  end
  def handle_cast({:subscribe, from}, %Board{consumers: pids} = board) do
    Process.monitor(from)
    {:noreply, %Board{board | consumers: [from|pids]}}
  end

  @impl true
  def handle_info(:tick, %Board{status: :gameover} = board) do
    :timer.cancel(board.timer)
    {:noreply, %Board{board | timer: nil}}
  end
  def handle_info(:tick, %Board{time: 1, consumers: pids} = board) do
    :timer.cancel(board.timer)
    send_to_all(pids, :gameover)
    {:noreply, %Board{board | time: 0, timer: nil, status: :gameover}}
  end
  def handle_info(:tick, %Board{time: time, consumers: pids} = board) do
    send_to_all(pids, :tick)
    {:noreply, %Board{board | time: time - 1}}
  end
  def handle_info({:DOWN, _ref, :process, pid, _reason}, board) do
    {:noreply, %Board{board | consumers: board.consumers -- [pid]}}
  end

  defp send_to_all(pids, msg) do
    for pid <- pids, do: send(pid, msg)
  end

  defp is_filled?(cells) do
    Enum.all?(cells,
              fn {_y, col} ->
                Enum.all?(col,
                          fn {_x, {_, :show}} -> true
                             {_x, {:mine, _}} -> true
                             {_x, {_, _}} -> false
                          end)
              end)
  end

  defp discover({cells, score}, 0, _, _w, _h, _t), do: {cells, score}
  defp discover({cells, score}, _, 0, _w, _h, _t), do: {cells, score}
  defp discover({cells, score}, i, _, _w, h, _t) when i > h, do: {cells, score}
  defp discover({cells, score}, _, j, w, _h, _t) when j > w, do: {cells, score}
  defp discover({cells, score}, i, j, w, h, t) do
    case cells[i][j] do
      {0, :hidden} ->
        cells = cells
                |> put_in([i, j], {0, :show})
        {cells, score + t}
        |> discover(i-1, j-1, w, h, t)
        |> discover(i-1, j, w, h, t)
        |> discover(i-1, j+1, w, h, t)
        |> discover(i, j+1, w, h, t)
        |> discover(i+1, j+1, w, h, t)
        |> discover(i+1, j, w, h, t)
        |> discover(i+1, j-1, w, h, t)
        |> discover(i, j-1, w, h, t)
      {n, :hidden} when is_integer(n) ->
        {put_in(cells[i][j], {n, :show}), score + t}
      {n, :show} when is_integer(n) ->
        {cells, score}
    end
  end
end
