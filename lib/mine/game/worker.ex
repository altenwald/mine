defmodule Mine.Game.Worker do
  @moduledoc """
  Defines the interaction between the game and the player. It's intended
  that this module let us play as a stand-alone user.
  """
  use GenServer, restart: :transient
  require Logger

  alias Mine.Game
  alias Mine.Game.Board
  alias Mine.HiScore

  @default_mines 40
  @default_height 16
  @default_width 16

  @type t() :: %__MODULE__{
          board: Board.t(),
          flags: non_neg_integer(),
          score: Board.score(),
          status: Game.game_status(),
          timer: nil | :timer.tref(),
          time: non_neg_integer(),
          consumers: [pid()],
          username: nil | String.t()
        }

  defstruct board: nil,
            flags: 0,
            score: 0,
            status: :play,
            timer: nil,
            time: nil,
            consumers: [],
            username: nil

  @doc """
  Start the server process.
  """
  @spec start_link(Game.game_id()) :: GenServer.on_start()
  def start_link(name) do
    time = Game.get_total_time()
    GenServer.start_link(__MODULE__, [time], name: Game.via(name))
  end

  @impl GenServer
  @doc false
  def init([time]) do
    width = Application.get_env(:mine, :width, @default_width)
    height = Application.get_env(:mine, :height, @default_height)
    mines = Application.get_env(:mine, :mines, @default_mines)
    board = Board.new(width, height, mines)
    {:ok, %__MODULE__{board: board, time: time}}
  end

  @impl GenServer
  @doc false
  def format_status(_reason, [_pdict, state]) do
    %__MODULE__{state |
      board: if(board = state.board, do: Board.get_naive_cells(board))
    }
  end

  @impl GenServer
  @doc false
  def handle_call(:show, _from, %__MODULE__{status: :pause} = state) do
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

  defp send_to_all(pids, msg) do
    Enum.each(pids, &send(&1, msg))
  end

  @impl GenServer
  @doc false
  def handle_cast(:toggle_pause, %__MODULE__{status: :play} = state) do
    {:noreply, %__MODULE__{state | status: :pause}}
  end

  def handle_cast(:toggle_pause, %__MODULE__{status: :pause} = state) do
    {:noreply, %__MODULE__{state | status: :play}}
  end

  def handle_cast({:hiscore, username, remote_ip}, %__MODULE__{score: score, time: time} = state) do
    {:ok, hiscore} = HiScore.save(username, score, time, remote_ip)
    send_to_all(state.consumers, {:hiscore, HiScore.get_order(hiscore.id)})
    {:noreply, %__MODULE__{state | username: username}}
  end

  def handle_cast({:sweep, _, _}, %__MODULE__{status: :gameover} = state) do
    {:noreply, state}
  end

  def handle_cast({:sweep, _, _}, %__MODULE__{status: :pause} = state) do
    {:noreply, state}
  end

  def handle_cast({:sweep, _, _} = msg, %__MODULE__{timer: nil} = state) do
    {:ok, timer} = :timer.send_interval(:timer.seconds(1), self(), :tick)
    handle_cast(msg, %__MODULE__{state | timer: timer})
  end

  def handle_cast({:sweep, x, y}, state) do
    process_sweep(Board.get_cell(state.board, x, y), x, y, state)
  end

  def handle_cast({:flag, _, _}, %__MODULE__{status: :gameover} = state) do
    {:noreply, state}
  end

  def handle_cast({:flag, _, _}, %__MODULE__{status: :pause} = state) do
    {:noreply, state}
  end

  def handle_cast({:flag, x, y}, %__MODULE__{board: board} = state) do
    case Board.get_cell(board, x, y) do
      {_, :flag} ->
        {:noreply, state}

      {_, :show} ->
        {:noreply, state}

      {value, :hidden} ->
        board = Board.put_cell(board, x, y, {value, :flag})
        {:noreply, %__MODULE__{state | board: board, flags: state.flags + 1}}
    end
  end

  def handle_cast({:unflag, _, _}, %__MODULE__{status: :gameover} = state) do
    {:noreply, state}
  end

  def handle_cast({:unflag, _, _}, %__MODULE__{status: :pause} = state) do
    {:noreply, state}
  end

  def handle_cast({:unflag, x, y}, %__MODULE__{board: board} = state) do
    case Board.get_cell(board, x, y) do
      {value, :flag} ->
        board = Board.put_cell(board, x, y, {value, :hidden})
        {:noreply, %__MODULE__{state | board: board, flags: state.flags - 1}}

      {_, :show} ->
        {:noreply, state}

      {_, :hidden} ->
        {:noreply, state}
    end
  end

  def handle_cast({:toggle_flag, _, _}, %__MODULE__{status: :gameover} = state) do
    {:noreply, state}
  end

  def handle_cast({:toggle_flag, _, _}, %__MODULE__{status: :pause} = state) do
    {:noreply, state}
  end

  def handle_cast({:toggle_flag, x, y}, %__MODULE__{board: board} = state) do
    case Board.get_cell(board, x, y) do
      {value, :flag} ->
        board = Board.put_cell(board, x, y, {value, :hidden})
        {:noreply, %__MODULE__{state | board: board, flags: state.flags - 1}}

      {_, :show} ->
        {:noreply, state}

      {value, :hidden} ->
        board = Board.put_cell(board, x, y, {value, :flag})
        {:noreply, %__MODULE__{state | board: board, flags: state.flags + 1}}
    end
  end

  def handle_cast({:subscribe, from}, %__MODULE__{consumers: pids} = state) do
    Process.monitor(from)
    {:noreply, %__MODULE__{state | consumers: [from | pids]}}
  end

  @impl GenServer
  @doc false
  def handle_info(:tick, %__MODULE__{status: :gameover} = state) do
    :timer.cancel(state.timer)
    {:noreply, %__MODULE__{state | timer: nil}}
  end

  def handle_info(:tick, %__MODULE__{status: :pause} = state) do
    {:noreply, state}
  end

  def handle_info(:tick, %__MODULE__{time: 1, consumers: pids} = state) do
    :timer.cancel(state.timer)
    send_to_all(pids, :gameover)
    {:noreply, %__MODULE__{state | time: 0, timer: nil, status: :gameover}}
  end

  def handle_info(:tick, %__MODULE__{time: time, consumers: pids} = state) do
    send_to_all(pids, :tick)
    {:noreply, %__MODULE__{state | time: time - 1}}
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    consumers = state.consumers -- [pid]

    if state.status == :gameover and consumers == [] do
      {:stop, :normal, state}
    else
      {:noreply, %__MODULE__{state | consumers: consumers}}
    end
  end

  defp process_sweep({n, :show}, x, y, %__MODULE__{board: board} = state)
       when is_integer(n) and n > 0 do
    {:noreply, check_discover(state, x, y)}
  catch
    :boom ->
      board = Board.discover_error(board, x, y)
      send_to_all(state.consumers, :gameover)
      {:noreply, %__MODULE__{state | board: board, status: :gameover}}
  end

  defp process_sweep({_, :show}, _x, _y, state), do: {:noreply, state}

  defp process_sweep({_, :flag}, _x, _y, state), do: {:noreply, state}

  defp process_sweep({:mine, _}, x, y, %__MODULE__{board: board} = state) do
    board = Board.put_cell(board, x, y, {:mine, :show})
    send_to_all(state.consumers, :gameover)
    {:noreply, %__MODULE__{state | board: board, status: :gameover}}
  end

  defp process_sweep({n, _}, x, y, %__MODULE__{board: board, status: status} = state)
       when is_integer(n) do
    {board, score} = Board.discover({board, state.score}, x, y, state.time)
    status = update_status(status, board, state.consumers)
    {:noreply, %__MODULE__{state | board: board, score: score, status: status}}
  end

  defp update_status(status, board, consumers) do
    if Board.is_filled?(board) do
      send_to_all(consumers, :win)
      :gameover
    else
      status
    end
  end

  defp check_discover(%__MODULE__{board: board, score: score} = state, x, y) do
    %{flags: flags, points: to_discover} = Board.check_around(board, x, y)

    case Board.get_cell(board, x, y) do
      {^flags, :show} ->
        discover = fn {x, y}, {board, score} ->
          Board.discover({board, score}, x, y, state.time)
        end

        {board, score} = Enum.reduce(to_discover, {board, score}, discover)
        status = update_status(state.status, board, state.consumers)
        %__MODULE__{state | board: board, score: score, status: status}

      _ ->
        state
    end
  end
end
