defmodule Mine.Board.MultiPlayer do
  use GenStateMachine, callback_mode: :state_functions
  require Logger

  alias Mine.{Board, HiScore}
  alias Mine.Board.MultiPlayer
  import Mine.Board, only: [via: 1, send_to_all: 2]

  @default_time 59
  @add_points_timeout 500
  @substract_points_timeout 0

  defstruct board: %Board{},
            flags: {0, 0},
            score: {0, 0},
            timer: nil,
            time: @default_time,
            players: [],
            consumers: []

  def child_spec(init_args) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [init_args]},
      restart: :transient
    }
  end

  def get_turn_time do
    Application.get_env(:mine, :turn_time, @default_time)
  end

  def start_link(name) do
    time = get_turn_time()
    GenStateMachine.start_link __MODULE__, [time], name: via(name)
  end

  def start(board) do
    DynamicSupervisor.start_child Mine.Boards, {__MODULE__, board}
  end

  @impl true
  def init([time]) do
    board = Board.init()
    {:ok, :wait_for_players, %MultiPlayer{board: board, time: time}}
  end

  # Waiting for players
  def wait_players({:call, {pid, _ref} = from}, {:join, name}, state) do
    Process.monitor(pid)
    player = UUID.uuid4()
    players = state.players ++ [{player, name, 0}]
    consumers = [pid|consumers]
    state = %MultiPlayer{state | players: players, consumers: consumers}
    case length(state.players) do
      n when n >= 2 ->
        {:next_state, :play, state, [{:reply, from, {:player, player}}]}
      n ->
        {:keep_state, state, [{:reply, from, {:player, player}}]}
    end
  end
  def wait_players({:call, {pid, _ref} = from}, {:join, player, name}, state) do
    Process.monitor(pid)
    players = state.players ++ [{player, name}]
    consumers = [pid|consumers]
    state = %MultiPlayer{state | players: players, consumers: consumers}
    case length(state.players) do
      n when n >= 2 ->
        {:next_state, :play, state, [{:reply, from, {:player, player}}]}
      n ->
        {:keep_state, state, [{:reply, from, {:player, player}}]}
    end
  end
  def wait_players(_type, _msg, _state) do
    :keep_state_and_data
  end

  defp round_turn(%MultiPlayer{players: [p1|pn], timer: timer} = state) do
    %MultiPlayer{state | players: pn ++ [p1], time: get_turn_time()}
  end

  # Playing...
  def play({:call, from}, :show, state) do
    cells = Board.get_naive_cells(state.board)
    {:keep_state_and_data, [{:reply, from, cells}]}
  end
  def play(:cast, {:toggle_pause, id}, %MultiPlayer{players: [id|_]} = state) do
    {:next_state, :pause, state}
  end
  def play(:cast, {:sweep, id, _, _} = msg,
           %MultiPlayer{players: [id|_], timer: nil} = state) do
    {:ok, timer} = :timer.send_interval(:timer.seconds(1), self(), :tick)
    state = round_turn(state, @substract_points_timeout, @add_points_timeout)
    {:keep_state, %MultiPlayer{state | timer: timer}, [{:next_event, :cast, msg}]}
  end
  def play(:cast, {:sweep, id, x, y}, %MultiPlayer{players: [id|players]} = state) do
    case Board.get_cell(board, x, y) do
      {n, :show} when is_integer(n) and n > 0 -> :keep_state_and_data
      {_, :show} -> :keep_state_and_data
      {_, :flag} -> :keep_state_and_data
      {:mine, _} ->
        board = Board.put_cell(board, x, y, {:mine, :show})
        [next_id|_] = players
        send_to_all(state.consumers, {:next, next_id})
        state = round_turn(state, 0, get_turn_time() - state.time)
        {:keep_state, %MultiPlayer{state | board: board}}
      {0, _} ->
        {board, score} = Board.discover({board, 0}, x, y, state.time)
        state = round_turn(state, score, 0)
        if Board.is_filled?(board) do
          winner = search_winner(state.players)
          Board.send_to_all(state.consumers, {:win, winner})
          {:next_state, :gameover, state}
        else
          {:keep_state, %MultiPlayer{state | board: board}}
        end
      {n, _} ->
        board = Board.put_cell(board, x, y, {n, :show})
        state = round_turn(state, state.time, 0)
        if Board.is_filled?(board) do
          winner = search_winner(state.players)
          send_to_all(state.consumers, {:win, winner})
          {:next_state, :gameover, state}
        else
          {:keep_state, %MultiPlayer{state | board: board}}
        end
    end
  end
  def play(:cast, {:toggle_flag, id, x, y},
           %MultiPlayer{players: [id|_], board: board} = state) do
    case Board.get_cell(board, x, y) do
      {value, :flag} ->
        board = Board.put_cell(board, x, y, {value, :hidden})
        state = round_turn(state, 0, 0)
        {:keep_state, %MultiPlayer{state | board: board, flags: state.flags - 1}}
      {_, :show} ->
        :keep_state_and_data
      {value, :hidden} ->
        board = Board.put_cell(board, x, y, {value, :flag})
        state = round_turn(state, 0, 0)
        state = %MultiPlayer{state | board: board, flags: state.flags + 1}
        if Board.is_filled?(board) do
          winner = search_winner(state.players)
          Board.send_to_all(state.consumers, {:win, winner})
          {:next_state, :gameover, state}
        else
          {:keep_state, state}          
        end
    end
  end
  def play(:info, :tick, %MultiPlayer{time: 1, consumers: pids} = state) do
    state = round_turn(state, 0, 0)
    [next_id|_] = state.players
    Board.send_to_all(pids, {:next, next_id})
    {:keep_state, state}
  end
  def play(:info, :tick, %MultiPlayer{time: time, consumers: pids} = state) do
    Board.send_to_all(pids, :tick)
    {:keep_state, %MultiPlayer{state | time: time - 1}}
  end
  def play(type, msg, state), do: handle_event(type, msg, :play, state)

  # Pause
  def pause({:call, from}, :show, _state) do
    {:keep_state_and_data, [{:reply, from, []}]}
  end
  def pause(:cast, {:toggle_pause, id}, %MultiPlayer{players: [id|_]} = state) do
    {:next_state, :play, state}
  end
  def pause(type, msg, state), do: handle_event(type, msg, :pause, state)

  # Game Over
  def gameover(:cast, {:sweep, _, _}, state), do: :keep_state_and_data
  def gameover(:info, :tick, state) do
    :timer.cancel(state.timer)
    {:keep_state, %MultiPlayer{state | timer: nil}}
  end
  def gameover(type, msg, state), do: handle_event(type, msg, :gameover, state)

  # Generic events
  def handle_event(:info, {:DOWN, _ref, :process, pid, _reason}, _status, state) do
    {:keep_state, %MultiPlayer{state | consumers: state.consumers -- [pid]}}
  end
  def handle_event(:cast, {:subscribe, from}, _status,
                   %MultiPlayer{consumers: pids} = state) do
    Process.monitor(from)
    {:keep_state, %MultiPlayer{state | consumers: [from|pids]}}
  end
  def handle_event(:info, :tick, _status, _state), do: :keep_state_and_data
  def handle_event(:cast, {:toggle_pause, _}, _status, _state) do
    :keep_state_and_data
  end
  def handle_event(:cast, {:sweep, _id, _x, _y}, _status, _state) do
    :keep_state_and_data
  end
  def handle_event(:cast, {:toggle_flag, _id, _x, _y}, _status, _state) do
    :keep_state_and_data
  end
  def handle_event({:call, from}, :flags, _status, state) do
    {:keep_state_and_data, [{:reply, from, state.flags}]}
  end
  def handle_event({:call, from}, :score, _status, state) do
    {:keep_state_and_data, [{:reply, from, state.score}]}
  end
  def handle_event({:call, from}, :status, status, _state) do
    {:keep_state_and_data, [{:reply, from, status}]}
  end
  def handle_event({:call, from}, :time, _status, state) do
    {:keep_state_and_data, [{:reply, from, state.time}]}
  end

  defp check_discover(%MultiPlayer{board: board, score: score} = state, x, y) do
    %{flags: flags, points: to_discover} = Board.check_around(board, x, y)
    {board, score} = case Board.get_cell(board, x, y) do
      {^flags, :show} ->
        discover = fn {x, y}, {board, score} ->
          Board.discover({board, score}, x, y, state.time)
        end
        List.foldl(to_discover, {board, score}, discover)
      _ ->
        {board, score}
    end
    %MultiPlayer{state | board: board, score: score}
  end
end
