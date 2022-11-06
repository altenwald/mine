defmodule Mine.Board do
  @moduledoc """
  Board abstraction have the abstraction functions to call the server where the
  game logic is stored and functions for handling the board.
  """

  @default_mines 40
  @default_height 16
  @default_width 16

  @typedoc """
  The content of the cell. It's a tuple with two elements: the number 0..9 or
  mine and if the cell is shown, hidden or flagged.
  """
  @type cell() :: {0..9 | :mine, :show | :hidden | :flag}

  @typedoc """
  The board representation for return is a list of lists containing cell
  information.
  """
  @type board() :: [[cell()]]

  @doc """
  The board ID.
  """
  @type board_id() :: String.t() | atom()

  @typedoc """
  Status of the game. It could be play, pause, or gameover.
  """
  @type game_status() :: :play | :pause | :gameover

  @typedoc """
  The time spent in seconds.
  """
  @type time() :: non_neg_integer()

  @typedoc """
  Board structure is storing the cells, number of mines, and weight and height.
  """
  @type t() :: %__MODULE__{
          cells: %{pos_integer() => %{pos_integer() => cell()}},
          mines: non_neg_integer(),
          width: nil | pos_integer(),
          height: nil | pos_integer()
        }

  defstruct cells: [],
            mines: 0,
            width: nil,
            height: nil

  @doc """
  Get the via for locating the board process.
  """
  def via(board) do
    {:via, Registry, {Mine.Board.Registry, board}}
  end

  @doc """
  Check if the process exists returning a boolean value.
  """
  @spec exists?(board_id()) :: boolean()
  def exists?(board) do
    case Registry.lookup(Mine.Board.Registry, board) do
      [{_pid, nil}] -> true
      [] -> false
    end
  end

  @doc """
  Stop the board.
  """
  def stop(name), do: GenServer.stop(via(name))

  @doc """
  Show the board. It's returning the board in the format of a list of
  lists of cells.
  """
  @spec show(board_id()) :: board()
  def show(name), do: GenServer.call(via(name), :show)

  @doc """
  Perform a sweep for a shown cell.
  """
  def sweep(name, x, y), do: GenServer.cast(via(name), {:sweep, x, y})

  @doc """
  Flag the cell for a given position.
  """
  def flag(name, x, y), do: GenServer.cast(via(name), {:flag, x, y})

  @doc """
  Unflag the cell for a given position.
  """
  def unflag(name, x, y), do: GenServer.cast(via(name), {:unflag, x, y})

  @doc """
  Toggle flag content. If the position is flagged then it's removing the flag,
  and if the cell wasn't flagged it's adding the flag.
  """
  def toggle_flag(name, x, y), do: GenServer.cast(via(name), {:toggle_flag, x, y})

  @doc """
  Returns the number of flags.
  """
  @spec flags(board_id()) :: non_neg_integer()
  def flags(name), do: GenServer.call(via(name), :flags)

  @doc """
  Return the current score.
  """
  @spec score(board_id()) :: non_neg_integer()
  def score(name), do: GenServer.call(via(name), :score)

  @doc """
  Return the status of the game.
  """
  @spec status(board_id()) :: game_status()
  def status(name), do: GenServer.call(via(name), :status)

  @doc """
  Subscribe to the game to receive all of the updates.
  """
  def subscribe(name), do: GenServer.cast(via(name), {:subscribe, self()})

  @doc """
  Retrieve the time remained for the game.
  """
  @spec time(board_id()) :: non_neg_integer()
  def time(name), do: GenServer.call(via(name), :time)

  @doc """
  Record a new score.
  """
  def hiscore(name, username, remote_ip) do
    GenServer.cast(via(name), {:hiscore, username, remote_ip})
  end

  @doc """
  Toggle the pause status.
  """
  def toggle_pause(name), do: GenServer.cast(via(name), :toggle_pause)

  @doc """
  Send a message to all of the PIDs.
  """
  def send_to_all(pids, msg) do
    Enum.each(pids, &send(&1, msg))
  end

  @doc false
  def init do
    width = Application.get_env(:mine, :width, @default_width)
    height = Application.get_env(:mine, :height, @default_height)
    mines = Application.get_env(:mine, :mines, @default_mines)

    gen_clean(width, height)
    |> place_mines(mines)
    |> place_hints()
  end

  @doc """
  Get the cell giving its position _x_, and _y_.
  """
  def get_cell(%__MODULE__{cells: cells}, x, y) do
    cells[y][x]
  end

  @doc """
  Put a value for a cell giving the position _x_, _y_, and _value_.
  """
  def put_cell(%__MODULE__{cells: cells} = board, x, y, value) do
    cells = put_in(cells[y][x], value)
    %__MODULE__{board | cells: cells}
  end

  @doc """
  Get the output representation for the board.
  """
  @spec get_naive_cells(t()) :: board()
  def get_naive_cells(%__MODULE__{cells: cells}) do
    for {_, rows} <- cells do
      for {_, cell} <- rows, do: cell
    end
  end

  @doc """
  Return if the board is filled, or the whole cells shown.
  """
  @spec is_filled?(t()) :: boolean()
  def is_filled?(%__MODULE__{cells: cells}) do
    Enum.all?(
      cells,
      fn {_y, col} ->
        Enum.all?(
          col,
          fn
            {_x, {_, :show}} -> true
            {_x, {:mine, _}} -> true
            {_x, {_, _}} -> false
          end
        )
      end
    )
  end

  @typedoc """
  The X position.
  """
  @type pos_x() :: non_neg_integer()

  @typedoc """
  The Y position.
  """
  @type pos_y() :: non_neg_integer()

  @typedoc """
  The point as a tuple for the X and Y position.
  """
  @type point() :: {pos_x(), pos_y()}

  @typedoc """
  The result for checking around. The points and flags.
  """
  @type check_result() :: %{points: [point()], flags: non_neg_integer()}

  @doc """
  Check the positions around the position given and returns the points and the
  number of flags.
  """
  @spec check_around(t(), pos_x(), pos_y()) :: check_result()
  def check_around(%__MODULE__{cells: cells}, x, y) do
    points = [
      {y - 1, x - 1, cells[y - 1][x - 1]},
      {y, x - 1, cells[y][x - 1]},
      {y + 1, x - 1, cells[y + 1][x - 1]},
      {y + 1, x, cells[y + 1][x]},
      {y + 1, x + 1, cells[y + 1][x + 1]},
      {y, x + 1, cells[y][x + 1]},
      {y - 1, x + 1, cells[y - 1][x + 1]},
      {y - 1, x, cells[y - 1][x]}
    ]

    process = fn
      {y, x, {_, :hidden}}, %{points: points} = acc -> Map.put(acc, :points, [{x, y} | points])
      {_y, _x, {_, :flag}}, %{flags: flags} = acc -> Map.put(acc, :flags, flags + 1)
      {_y, _x, _cell}, acc -> acc
    end

    List.foldl(points, %{points: [], flags: 0}, process)
  end

  defp place_hints(%__MODULE__{cells: cells, width: width, height: height} = board) do
    cells =
      for i <- 1..height, into: %{} do
        {i,
         for j <- 1..width, into: %{} do
           case cells[i][j] do
             {:mine, status} ->
               {j, {:mine, status}}

             {0, status} ->
               get_n = fn x, y -> get_n(board, x, y) end

               mines =
                 get_n.(i - 1, j - 1) +
                   get_n.(i - 1, j) +
                   get_n.(i - 1, j + 1) +
                   get_n.(i, j + 1) +
                   get_n.(i + 1, j + 1) +
                   get_n.(i + 1, j) +
                   get_n.(i + 1, j - 1) +
                   get_n.(i, j - 1)

               {j, {mines, status}}
           end
         end}
      end

    %__MODULE__{board | cells: cells}
  end

  defp get_n(_board, 0, _), do: 0
  defp get_n(_board, _, 0), do: 0
  defp get_n(%__MODULE__{height: h}, i, _) when i > h, do: 0
  defp get_n(%__MODULE__{width: w}, _, j) when j > w, do: 0

  defp get_n(%__MODULE__{cells: cells}, i, j) do
    case cells[i][j] do
      {:mine, _} -> 1
      {n, _} when is_integer(n) -> 0
    end
  end

  defp place_mines(board, 0), do: board

  defp place_mines(%__MODULE__{cells: cells, width: width, height: height} = board, i) do
    x = Enum.random(1..width)
    y = Enum.random(1..height)

    if cells[y][x] == {:mine, :hidden} do
      place_mines(board, i)
    else
      mines = board.mines + 1
      cells = put_in(cells, [y, x], {:mine, :hidden})

      %__MODULE__{board | cells: cells, mines: mines}
      |> place_mines(i - 1)
    end
  end

  defp gen_clean(width, height) do
    cells =
      for y <- 1..height, into: %{} do
        {y, for(x <- 1..width, into: %{}, do: {x, {0, :hidden}})}
      end

    %__MODULE__{cells: cells, width: width, height: height}
  end

  @typedoc """
  The score.
  """
  @type score() :: non_neg_integer()

  @typedoc """
  The time used to get a score.
  """
  @type time_score() :: non_neg_integer()

  @doc """
  Discover all of the positions around a giving position (x, y) adding the
  score in each recursion.
  """
  @spec discover({t(), score()}, pos_x(), pos_y(), time_score()) :: {t(), score()}
  def discover(data, 0, _, _t), do: data
  def discover(data, _, 0, _t), do: data
  def discover({%__MODULE__{width: w}, _} = data, x, _, _t) when x > w, do: data
  def discover({%__MODULE__{height: h}, _} = data, _, y, _t) when y > h, do: data

  def discover({%__MODULE__{cells: cells} = board, score}, x, y, t) do
    case cells[y][x] do
      {0, :hidden} ->
        cells =
          cells
          |> put_in([y, x], {0, :show})

        {%__MODULE__{board | cells: cells}, score + t}
        |> discover(x - 1, y - 1, t)
        |> discover(x - 1, y, t)
        |> discover(x - 1, y + 1, t)
        |> discover(x, y + 1, t)
        |> discover(x + 1, y + 1, t)
        |> discover(x + 1, y, t)
        |> discover(x + 1, y - 1, t)
        |> discover(x, y - 1, t)

      {:mine, _} ->
        throw(:boom)

      {n, :hidden} when is_integer(n) ->
        {%__MODULE__{board | cells: put_in(cells[y][x], {n, :show})}, score + t}

      {n, :show} when is_integer(n) ->
        {board, score}
    end
  end

  @doc """
  Discover a position around avoiding recursivity. This is because we found
  a mine.
  """
  @spec discover_error(t(), pos_x(), pos_y()) :: t()
  def discover_error(%__MODULE__{cells: cells} = board, x, y) do
    points = [
      {y - 1, x - 1, cells[y - 1][x - 1]},
      {y, x - 1, cells[y][x - 1]},
      {y + 1, x - 1, cells[y + 1][x - 1]},
      {y + 1, x, cells[y + 1][x]},
      {y + 1, x + 1, cells[y + 1][x + 1]},
      {y, x + 1, cells[y][x + 1]},
      {y - 1, x + 1, cells[y - 1][x + 1]},
      {y - 1, x, cells[y - 1][x]}
    ]

    discover = fn
      {_y, _x, {:mine, :flag}}, cells -> cells
      {y, x, {n, :flag}}, cells -> put_in(cells[y][x], {n, :flag_error})
      {y, x, {n, :hidden}}, cells -> put_in(cells[y][x], {n, :show})
      {_y, _x, {_n, :show}}, cells -> cells
      {_y, _x, nil}, cells -> cells
    end

    cells = List.foldl(points, cells, discover)
    %__MODULE__{board | cells: cells}
  end
end
