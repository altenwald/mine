defmodule Mine.Game.Worker do
  @moduledoc """
  Defines the interaction between the game and the player. It's intended
  that this module let us play as a stand-alone user.
  """
  use GenStateMachine, callback_mode: :handle_event_function, restart: :transient
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
          time: non_neg_integer(),
          consumers: [pid()],
          username: nil | String.t()
        }

  defstruct board: nil,
            flags: 0,
            score: 0,
            time: nil,
            consumers: [],
            username: nil

  @doc """
  Start the server process.
  """
  @spec start_link(Game.game_id()) :: GenServer.on_start()
  def start_link(name) do
    time = Game.get_total_time()
    GenStateMachine.start_link(__MODULE__, [time], name: Game.via(name))
  end

  @impl GenStateMachine
  @doc false
  def init([time]) do
    width = Application.get_env(:mine, :width, @default_width)
    height = Application.get_env(:mine, :height, @default_height)
    mines = Application.get_env(:mine, :mines, @default_mines)
    board = Board.new(width, height, mines)
    {:ok, :clean, %__MODULE__{board: board, time: time}}
  end

  @impl GenStateMachine
  @doc false
  def format_status(_reason, [_pdict, state]) do
    %__MODULE__{state | board: if(board = state.board, do: Board.get_naive_cells(board))}
  end

  defp send_to_all(pids, msg) do
    Enum.each(pids, &send(&1, msg))
  end

  defguard is_playing?(state_name) when state_name in ~w[ playing clean ]a

  @impl GenStateMachine
  @doc false
  def handle_event({:call, from}, :show, :pause, _state_data) do
    {:keep_state_and_data, [{:reply, from, []}]}
  end

  def handle_event({:call, from}, :show, _state_name, state_data) do
    cells = Board.get_naive_cells(state_data.board)
    {:keep_state_and_data, [{:reply, from, cells}]}
  end

  def handle_event({:call, from}, :flags, _state_name, state_data) do
    {:keep_state_and_data, [{:reply, from, state_data.flags}]}
  end

  def handle_event({:call, from}, :score, _state_name, state_data) do
    {:keep_state_and_data, [{:reply, from, state_data.score}]}
  end

  def handle_event({:call, from}, :status, state_name, _state_data) do
    state_name =
      case state_name do
        :clean -> :play
        :playing -> :play
        :pause -> :pause
        :gameover -> :gameover
      end

    {:keep_state_and_data, [{:reply, from, state_name}]}
  end

  def handle_event({:call, from}, :time, _state_name, state_data) do
    {:keep_state_and_data, [{:reply, from, state_data.time}]}
  end

  def handle_event(:cast, :toggle_pause, :playing, state_data) do
    {:next_state, :pause, state_data}
  end

  def handle_event(:cast, :toggle_pause, :pause, state_data) do
    {:next_state, :playing, state_data}
  end

  def handle_event(:cast, :toggle_pause, _state_name, _state_data) do
    :keep_state_and_data
  end

  def handle_event(
        :cast,
        {:hiscore, username, remote_ip},
        _state_name,
        %__MODULE__{score: score, time: time} = state
      ) do
    {:ok, hiscore} = HiScore.save(username, score, time, remote_ip)
    send_to_all(state.consumers, {:hiscore, HiScore.get_order(hiscore.id)})
    {:keep_state, %__MODULE__{state | username: username}}
  end

  def handle_event(:cast, {:sweep, _, _}, state_name, _state_data)
      when not is_playing?(state_name) do
    :keep_state_and_data
  end

  def handle_event(:cast, {:sweep, _, _}, :clean, state_data) do
    actions = [
      :postpone,
      {{:timeout, :clock}, :timer.seconds(1), :tick}
    ]

    {:next_state, :playing, state_data, actions}
  end

  def handle_event(:cast, {:sweep, x, y}, :playing, state_data) do
    process_sweep(Board.get_cell(state_data.board, x, y), x, y, state_data)
  end

  def handle_event(:cast, {:flag, _, _}, state_name, _state_data)
      when not is_playing?(state_name) do
    :keep_state_and_data
  end

  def handle_event(:cast, {:flag, x, y}, _state_name, %__MODULE__{board: board} = state_data) do
    case Board.get_cell(board, x, y) do
      {_, :flag} ->
        :keep_state_and_data

      {_, :show} ->
        :keep_state_and_data

      {value, :hidden} ->
        board = Board.put_cell(board, x, y, {value, :flag})
        {:keep_state, %__MODULE__{state_data | board: board, flags: state_data.flags + 1}}
    end
  end

  def handle_event(:cast, {:unflag, _, _}, state_name, _state_data)
      when not is_playing?(state_name) do
    :keep_state_and_data
  end

  def handle_event(:cast, {:unflag, x, y}, _state_name, %__MODULE__{board: board} = state_data) do
    case Board.get_cell(board, x, y) do
      {value, :flag} ->
        board = Board.put_cell(board, x, y, {value, :hidden})
        {:keep_state, %__MODULE__{state_data | board: board, flags: state_data.flags - 1}}

      {_, :show} ->
        :keep_state_and_data

      {_, :hidden} ->
        :keep_state_and_data
    end
  end

  def handle_event(:cast, {:toggle_flag, _, _}, state_name, _state_data)
      when not is_playing?(state_name) do
    :keep_state_and_data
  end

  def handle_event(
        :cast,
        {:toggle_flag, x, y},
        _state_name,
        %__MODULE__{board: board} = state_data
      ) do
    case Board.get_cell(board, x, y) do
      {value, :flag} ->
        board = Board.put_cell(board, x, y, {value, :hidden})
        {:keep_state, %__MODULE__{state_data | board: board, flags: state_data.flags - 1}}

      {_, :show} ->
        :keep_state_and_data

      {value, :hidden} ->
        board = Board.put_cell(board, x, y, {value, :flag})
        {:keep_state, %__MODULE__{state_data | board: board, flags: state_data.flags + 1}}
    end
  end

  def handle_event(
        :cast,
        {:subscribe, from},
        _state_name,
        %__MODULE__{consumers: pids} = state_data
      ) do
    Process.monitor(from)
    {:keep_state, %__MODULE__{state_data | consumers: [from | pids]}}
  end

  def handle_event({:timeout, :clock}, :tick, :gameover, _state_data) do
    :keep_state_and_data
  end

  def handle_event({:timeout, :clock}, :tick, :pause, state_data) do
    actions = [{{:timeout, :clock}, :timer.seconds(1), :tick}]
    {:keep_state, state_data, actions}
  end

  def handle_event({:timeout, :clock}, :tick, :playing, %__MODULE__{time: 1} = state_data) do
    send_to_all(state_data.consumers, :gameover)
    actions = [{{:timeout, :clock}, :timer.seconds(1), :tick}]
    {:next_state, :gameover, %__MODULE__{state_data | time: 0}, actions}
  end

  def handle_event({:timeout, :clock}, :tick, :playing, %__MODULE__{time: time} = state_data) do
    send_to_all(state_data.consumers, :tick)
    actions = [{{:timeout, :clock}, :timer.seconds(1), :tick}]
    {:keep_state, %__MODULE__{state_data | time: time - 1}, actions}
  end

  def handle_event(:info, {:DOWN, _ref, :process, pid, _reason}, state_name, state_data) do
    consumers = state_data.consumers -- [pid]

    if state_name == :gameover and consumers == [] do
      :stop
    else
      {:keep_state, %__MODULE__{state_data | consumers: consumers}}
    end
  end

  defp process_sweep({n, :show}, x, y, %__MODULE__{board: board} = state_data)
       when is_integer(n) and n > 0 do
    {state_name, state_data} = check_discover(state_data, x, y)

    if state_name != :playing do
      {:next_state, state_name, state_data}
    else
      {:keep_state, state_data}
    end
  catch
    :boom ->
      board = Board.discover_error(board, x, y)
      send_to_all(state_data.consumers, :gameover)
      {:next_state, :gameover, %__MODULE__{state_data | board: board}}
  end

  defp process_sweep({_, :show}, _x, _y, _state_data), do: :keep_state_and_data

  defp process_sweep({_, :flag}, _x, _y, _state_data), do: :keep_state_and_data

  defp process_sweep({:mine, _}, x, y, %__MODULE__{board: board} = state_data) do
    board = Board.put_cell(board, x, y, {:mine, :show})
    send_to_all(state_data.consumers, :gameover)
    {:next_state, :gameover, %__MODULE__{state_data | board: board}}
  end

  defp process_sweep({n, _}, x, y, %__MODULE__{board: board} = state_data)
       when is_integer(n) do
    {board, score} = Board.discover({board, state_data.score}, x, y, state_data.time)
    state_name = update_state_name(board, state_data.consumers)

    if state_name == :playing do
      {:keep_state, %__MODULE__{state_data | board: board, score: score}}
    else
      {:next_state, state_name, %__MODULE__{state_data | board: board, score: score}}
    end
  end

  defp update_state_name(board, consumers) do
    if Board.is_filled?(board) do
      send_to_all(consumers, :win)
      :gameover
    else
      :playing
    end
  end

  defp check_discover(%__MODULE__{board: board, score: score} = state_data, x, y) do
    %{flags: flags, points: to_discover} = Board.check_around(board, x, y)

    case Board.get_cell(board, x, y) do
      {^flags, :show} ->
        discover = fn {x, y}, {board, score} ->
          Board.discover({board, score}, x, y, state_data.time)
        end

        {board, score} = Enum.reduce(to_discover, {board, score}, discover)
        state_name = update_state_name(board, state_data.consumers)
        {state_name, %__MODULE__{state_data | board: board, score: score}}

      _ ->
        {:playing, state_data}
    end
  end
end
