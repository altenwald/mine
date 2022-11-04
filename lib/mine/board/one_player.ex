defmodule Mine.Board.OnePlayer do
  @moduledoc """
  Defines the interaction between the game and the player. It's intended
  that this module let us play as a stand-alone user.
  """
  use GenServer
  require Logger

  alias Mine.{Board, HiScore}
  alias Mine.Board.OnePlayer
  import Mine.Board, only: [via: 1, send_to_all: 2]

  @default_time 999

  defstruct board: %Board{},
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

  def get_total_time do
    Application.get_env(:mine, :total_time, @default_time)
  end

  def start_link(name) do
    time = get_total_time()
    GenServer.start_link(__MODULE__, [time], name: via(name))
  end

  def start(board) do
    DynamicSupervisor.start_child(Mine.Boards, {__MODULE__, board})
  end

  @impl true
  def init([time]) do
    board = Board.init()
    {:ok, %OnePlayer{board: board, time: time}}
  end

  @impl true
  def handle_call(:show, _from, %OnePlayer{status: :pause} = state) do
    {:reply, [], state}
  end

  def handle_call(:show, _from, state) do
    cells = Board.get_naive_cells(state.board)
    {:reply, cells, state}
  end

  def handle_call(:flags, _from, state), do: {:reply, state.flags, state}
  def handle_call(:score, _from, state), do: {:reply, state.score, state}
  def handle_call(:status, _from, state), do: {:reply, state.status, state}
  def handle_call(:time, _from, state), do: {:reply, state.time, state}

  @impl true
  def handle_cast(:toggle_pause, %OnePlayer{status: :play} = state) do
    {:noreply, %OnePlayer{state | status: :pause}}
  end

  def handle_cast(:toggle_pause, %OnePlayer{status: :pause} = state) do
    {:noreply, %OnePlayer{state | status: :play}}
  end

  def handle_cast({:hiscore, username, remote_ip}, %OnePlayer{score: score, time: time} = state) do
    {:ok, hiscore} = HiScore.save(username, score, time, remote_ip)
    send_to_all(state.consumers, {:hiscore, HiScore.get_order(hiscore.id)})
    {:noreply, %OnePlayer{state | username: username}}
  end

  def handle_cast({:sweep, _, _}, %OnePlayer{status: :gameover} = state) do
    {:noreply, state}
  end

  def handle_cast({:sweep, _, _}, %OnePlayer{status: :pause} = state) do
    {:noreply, state}
  end

  def handle_cast({:sweep, _, _} = msg, %OnePlayer{timer: nil} = state) do
    {:ok, timer} = :timer.send_interval(:timer.seconds(1), self(), :tick)
    handle_cast(msg, %OnePlayer{state | timer: timer})
  end

  def handle_cast({:sweep, x, y}, state) do
    process_sweep(Board.get_cell(state.board, x, y), x, y, state)
  end

  def handle_cast({:flag, _, _}, %OnePlayer{status: :gameover} = state) do
    {:noreply, state}
  end

  def handle_cast({:flag, _, _}, %OnePlayer{status: :pause} = state) do
    {:noreply, state}
  end

  def handle_cast({:flag, x, y}, %OnePlayer{board: board} = state) do
    case Board.get_cell(board, x, y) do
      {_, :flag} ->
        {:noreply, state}

      {_, :show} ->
        {:noreply, state}

      {value, :hidden} ->
        board = Board.put_cell(board, x, y, {value, :flag})

        status =
          if Board.is_filled?(board) do
            Board.send_to_all(state.consumers, :win)
            :gameover
          else
            state.status
          end

        {:noreply, %OnePlayer{state | board: board, flags: state.flags + 1, status: status}}
    end
  end

  def handle_cast({:unflag, _, _}, %OnePlayer{status: :gameover} = state) do
    {:noreply, state}
  end

  def handle_cast({:unflag, _, _}, %OnePlayer{status: :pause} = state) do
    {:noreply, state}
  end

  def handle_cast({:unflag, x, y}, %OnePlayer{board: board} = state) do
    case Board.get_cell(board, x, y) do
      {value, :flag} ->
        board = Board.put_cell(board, x, y, {value, :hidden})
        {:noreply, %OnePlayer{state | board: board, flags: state.flags - 1}}

      {_, :show} ->
        {:noreply, state}

      {_, :hidden} ->
        {:noreply, state}
    end
  end

  def handle_cast({:toggle_flag, _, _}, %OnePlayer{status: :gameover} = state) do
    {:noreply, state}
  end

  def handle_cast({:toggle_flag, _, _}, %OnePlayer{status: :pause} = state) do
    {:noreply, state}
  end

  def handle_cast({:toggle_flag, x, y}, %OnePlayer{board: board} = state) do
    case Board.get_cell(board, x, y) do
      {value, :flag} ->
        board = Board.put_cell(board, x, y, {value, :hidden})
        {:noreply, %OnePlayer{state | board: board, flags: state.flags - 1}}

      {_, :show} ->
        {:noreply, state}

      {value, :hidden} ->
        board = Board.put_cell(board, x, y, {value, :flag})

        status =
          if Board.is_filled?(board) do
            Board.send_to_all(state.consumers, :win)
            :gameover
          else
            state.status
          end

        {:noreply, %OnePlayer{state | board: board, flags: state.flags + 1, status: status}}
    end
  end

  def handle_cast({:subscribe, from}, %OnePlayer{consumers: pids} = state) do
    Process.monitor(from)
    {:noreply, %OnePlayer{state | consumers: [from | pids]}}
  end

  @impl true
  def handle_info(:tick, %OnePlayer{status: :gameover} = state) do
    :timer.cancel(state.timer)
    {:noreply, %OnePlayer{state | timer: nil}}
  end

  def handle_info(:tick, %OnePlayer{status: :pause} = state) do
    {:noreply, state}
  end

  def handle_info(:tick, %OnePlayer{time: 1, consumers: pids} = state) do
    :timer.cancel(state.timer)
    Board.send_to_all(pids, :gameover)
    {:noreply, %OnePlayer{state | time: 0, timer: nil, status: :gameover}}
  end

  def handle_info(:tick, %OnePlayer{time: time, consumers: pids} = state) do
    Board.send_to_all(pids, :tick)
    {:noreply, %OnePlayer{state | time: time - 1}}
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    consumers = state.consumers -- [pid]

    if state.status == :gameover and consumers == [] do
      {:stop, :normal, state}
    else
      {:noreply, %OnePlayer{state | consumers: consumers}}
    end
  end

  defp process_sweep({n, :show}, x, y, %OnePlayer{board: board} = state) when is_integer(n) and n > 0 do
    try do
      {:noreply, check_discover(state, x, y)}
    catch
      :boom ->
        board = Board.discover_error(board, x, y)
        send_to_all(state.consumers, :gameover)
        {:noreply, %OnePlayer{state | board: board, status: :gameover}}
    end
  end

  defp process_sweep({_, :show}, _x, _y, state), do: {:noreply, state}

  defp process_sweep({_, :flag}, _x, _y, state), do: {:noreply, state}

  defp process_sweep({:mine, _}, x, y, %OnePlayer{board: board} = state) do
    board = Board.put_cell(board, x, y, {:mine, :show})
    send_to_all(state.consumers, :gameover)
    {:noreply, %OnePlayer{state | board: board, status: :gameover}}
  end

  defp process_sweep({0, _}, x, y, %OnePlayer{board: board, status: status} = state) do
    {board, score} = Board.discover({board, state.score}, x, y, state.time)
    status = update_status(status, board, state.consumers)
    {:noreply, %OnePlayer{state | board: board, score: score, status: status}}
  end

  defp process_sweep({n, _}, x, y, %OnePlayer{board: board, status: status} = state) do
    board = Board.put_cell(board, x, y, {n, :show})
    status = update_status(status, board, state.consumers)
    {:noreply, %OnePlayer{state | board: board, status: status}}
  end

  defp update_status(status, board, consumers) do
    if Board.is_filled?(board) do
      send_to_all(consumers, :win)
      :gameover
    else
      status
    end
  end

  defp check_discover(%OnePlayer{board: board, score: score} = state, x, y) do
    %{flags: flags, points: to_discover} = Board.check_around(board, x, y)

    {board, score} =
      case Board.get_cell(board, x, y) do
        {^flags, :show} ->
          discover = fn {x, y}, {board, score} ->
            Board.discover({board, score}, x, y, state.time)
          end

          List.foldl(to_discover, {board, score}, discover)

        _ ->
          {board, score}
      end

    %OnePlayer{state | board: board, score: score}
  end
end
