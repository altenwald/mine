defmodule Mine.Game do
  @moduledoc """
  Supervisor to handle the dynamic supervisor for creating the games,
  and the registry where we can find the games.
  """
  use Supervisor
  alias Mine.Game.Board

  @registry_name Mine.Game.Registry
  @dynsup_name Mine.Games
  @default_time 999

  @typedoc """
  The game ID is the way we can search the game in the Registry.
  """
  @type game_id() :: String.t() | atom()

  @typedoc """
  Status of the game. It could be play, pause, or gameover.
  """
  @type game_status() :: :play | :pause | :gameover

  @typedoc """
  The time spent in seconds.
  """
  @type time() :: non_neg_integer()

  @doc false
  def start_link([]) do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Get the via for locating the game process.
  """
  def via(game_id) do
    {:via, Registry, {@registry_name, game_id}}
  end

  @doc """
  Check if the game process exists returning a boolean value.
  """
  @spec exists?(game_id()) :: boolean()
  def exists?(game_id) do
    case Registry.lookup(@registry_name, game_id) do
      [{_pid, nil}] -> true
      [] -> false
    end
  end

  @doc """
  Stop the game.
  """
  def stop(game_id), do: GenServer.stop(via(game_id))

  @doc """
  Show the board. It's returning the board in the format of a list of
  lists of cells.
  """
  @spec show(game_id()) :: Board.board()
  def show(game_id), do: GenServer.call(via(game_id), :show)

  @doc """
  Perform a sweep for a shown cell.
  """
  def sweep(game_id, x, y), do: GenServer.cast(via(game_id), {:sweep, x, y})

  @doc """
  Flag the cell for a given position.
  """
  def flag(game_id, x, y), do: GenServer.cast(via(game_id), {:flag, x, y})

  @doc """
  Unflag the cell for a given position.
  """
  def unflag(game_id, x, y), do: GenServer.cast(via(game_id), {:unflag, x, y})

  @doc """
  Toggle flag content. If the position is flagged then it's removing the flag,
  and if the cell wasn't flagged it's adding the flag.
  """
  def toggle_flag(game_id, x, y), do: GenServer.cast(via(game_id), {:toggle_flag, x, y})

  @doc """
  Returns the number of flags.
  """
  @spec flags(game_id()) :: non_neg_integer()
  def flags(game_id), do: GenServer.call(via(game_id), :flags)

  @doc """
  Return the current score.
  """
  @spec score(game_id()) :: non_neg_integer()
  def score(game_id), do: GenServer.call(via(game_id), :score)

  @doc """
  Return the status of the game.
  """
  @spec status(game_id()) :: game_status()
  def status(game_id), do: GenServer.call(via(game_id), :status)

  @doc """
  Subscribe to the game to receive all of the updates.
  """
  def subscribe(game_id), do: GenServer.cast(via(game_id), {:subscribe, self()})

  @doc """
  Retrieve the time remained for the game.
  """
  @spec time(game_id()) :: non_neg_integer()
  def time(game_id), do: GenServer.call(via(game_id), :time)

  @doc """
  Get the total time for a new game.
  """
  @spec get_total_time() :: non_neg_integer()
  def get_total_time do
    Application.get_env(:mine, :total_time, @default_time)
  end

  @doc """
  Record a new score.
  """
  def hiscore(game_id, username, remote_ip) do
    GenServer.cast(via(game_id), {:hiscore, username, remote_ip})
  end

  @doc """
  Toggle the pause status.
  """
  def toggle_pause(game_id), do: GenServer.cast(via(game_id), :toggle_pause)

  @impl Supervisor
  @doc false
  def init([]) do
    children = [
      # Start the Registry for boards and the DynamicSupervisor
      {Registry, keys: :unique, name: @registry_name},
      {DynamicSupervisor, strategy: :one_for_one, name: @dynsup_name}
    ]

    options = [strategy: :one_for_all]
    Supervisor.init(children, options)
  end

  @doc """
  Start a new process under the dynamic supervisor.
  """
  @spec start(game_id()) :: DynamicSupervisor.on_start_child()
  def start(board) do
    DynamicSupervisor.start_child(@dynsup_name, {Mine.Game.Worker, board})
  end
end
