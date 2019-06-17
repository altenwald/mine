defmodule Mine.Board do
  alias Mine.Board

  @default_mines 40
  @default_height 16
  @default_width 16

  defstruct cells: [],
            mines: 0,
            width: nil,
            height: nil

  def via(board) do
    {:via, Registry, {Mine.Board.Registry, board}}
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
  def toggle_pause(name), do: GenServer.cast via(name), :toggle_pause

  def send_to_all(pids, msg) do
    for pid <- pids, do: send(pid, msg)
  end

  def init do
    width = Application.get_env(:mine, :width, @default_width)
    height = Application.get_env(:mine, :height, @default_height)
    mines = Application.get_env(:mine, :mines, @default_mines)
    gen_clean(width, height)
    |> place_mines(mines)
    |> place_hints()
  end

  def get_cell(%Board{cells: cells}, x, y) do
    cells[y][x]
  end

  def put_cell(%Board{cells: cells} = board, x, y, value) do
    cells = put_in(cells[y][x], value)
    %Board{board | cells: cells}
  end

  def get_naive_cells(%Board{cells: cells}) do
    for {_, rows} <- cells do
      for {_, cell} <- rows, do: cell
    end
  end

  def is_filled?(%Board{cells: cells}) do
    Enum.all?(cells,
              fn {_y, col} ->
                Enum.all?(col,
                          fn {_x, {_, :show}} -> true
                             {_x, {:mine, _}} -> true
                             {_x, {_, _}} -> false
                          end)
              end)
  end

  def check_around(%Board{cells: cells}, x, y) do
    points = [
      {y-1, x-1, cells[y-1][x-1]},
      {y, x-1, cells[y][x-1]},
      {y+1, x-1, cells[y+1][x-1]},
      {y+1, x, cells[y+1][x]},
      {y+1, x+1, cells[y+1][x+1]},
      {y, x+1, cells[y][x+1]},
      {y-1, x+1, cells[y-1][x+1]},
      {y-1, x, cells[y-1][x]},
    ]
    process = fn {y, x, {_, :hidden}}, %{points: points} = acc -> Map.put(acc, :points, [{x, y}|points])
                 {_y, _x, {_, :flag}}, %{flags: flags} = acc -> Map.put(acc, :flags, flags + 1)
                 {_y, _x, _cell}, acc -> acc
              end
    List.foldl(points, %{points: [], flags: 0}, process)
  end

  defp place_hints(%Board{cells: cells, width: width, height: height} = board) do
    cells = for i <- 1..height, into: %{} do
      {i, for j <- 1..width, into: %{} do
        case cells[i][j] do
          {:mine, status} ->
            {j, {:mine, status}}
          {0, status} ->
            get_n = fn(x, y) -> get_n(board, x, y) end
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
    %Board{board | cells: cells}
  end

  defp get_n(_board, 0, _), do: 0
  defp get_n(_board, _, 0), do: 0
  defp get_n(%Board{height: h}, i, _) when i > h, do: 0
  defp get_n(%Board{width: w}, _, j) when j > w, do: 0
  defp get_n(%Board{cells: cells}, i, j) do
    case cells[i][j] do
      {:mine, _} -> 1
      {n, _} when is_integer(n) -> 0
    end
  end

  defp place_mines(board, 0), do: board
  defp place_mines(%Board{cells: cells, width: width, height: height} = board, i) do
    x = Enum.random(1..width)
    y = Enum.random(1..height)
    if cells[y][x] == {:mine, :hidden} do
      place_mines(board, i)
    else
      mines = board.mines + 1
      cells = put_in(cells, [y, x], {:mine, :hidden})
      %Board{board | cells: cells, mines: mines}
      |> place_mines(i - 1)
    end
  end

  defp gen_clean(width, height) do
    cells = for y <- 1..height, into: %{} do
      {y, for(x <- 1..width, into: %{}, do: {x, {0, :hidden}})}
    end
    %Board{cells: cells, width: width, height: height}
  end

  def discover(data, 0, _, _t), do: data
  def discover(data, _, 0, _t), do: data
  def discover({%Board{width: w}, _} = data, x, _, _t) when x > w, do: data
  def discover({%Board{height: h}, _} = data, _, y, _t) when y > h, do: data
  def discover({%Board{cells: cells} = board, score}, x, y, t) do
    case cells[y][x] do
      {0, :hidden} ->
        cells = cells
                |> put_in([y, x], {0, :show})
        {%Board{board | cells: cells}, score + t}
        |> discover(x-1, y-1, t)
        |> discover(x-1, y, t)
        |> discover(x-1, y+1, t)
        |> discover(x, y+1, t)
        |> discover(x+1, y+1, t)
        |> discover(x+1, y, t)
        |> discover(x+1, y-1, t)
        |> discover(x, y-1, t)
      {n, :hidden} when is_integer(n) ->
        {%Board{board | cells: put_in(cells[y][x], {n, :show})}, score + t}
      {n, :show} when is_integer(n) ->
        {board, score}
    end
  end
end
