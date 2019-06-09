defmodule Mine.Board do
  use GenServer

  alias Mine.Board

  @base_points 1

  defstruct cells: [],
            mines: @default_mines,
            width: @default_width,
            height: @default_height,
            flags: 0,
            score: 0,
            status: :play

  @name __MODULE__

  def start_link([width, height, mines]) do
    GenServer.start_link __MODULE__, [width, height, mines], name: @name
  end

  def stop, do: GenServer.stop @name
  def show, do: GenServer.call @name, :show
  def sweep(x, y), do: GenServer.cast @name, {:sweep, x, y}
  def flag(x, y), do: GenServer.cast @name, {:flag, x, y}
  def flags, do: GenServer.call @name, :flags
  def score, do: GenServer.call @name, :score
  def status, do: GenServer.call @name, :status

  @impl true
  def init([width, height, mines]) do
    cells = gen_clean(width, height)
            |> place_mines(width, height, mines)
            |> place_hints(width, height)
    {:ok, %Board{cells: cells}}
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
    if cells[x][y] == {:mine, :hidden} do
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

  @impl true
  def handle_cast({:sweep, _, _}, %Board{status: :gameover} = board) do
    {:noreply, board}
  end
  def handle_cast({:sweep, x, y}, %Board{cells: cells} = board) do
    case cells[y][x] do
      {_, :show} -> {:noreply, board}
      {_, :flag} -> {:noreply, board}
      {:mine, _} ->
        cells = put_in(cells[y][x], {:mine, :show})
        {:noreply, %Board{board | cells: cells, status: :gameover}}
      {0, _} ->
        {cells, score} = discover({cells, board.score}, y, x, board.width, board.height)
        {:noreply, %Board{board | cells: cells, score: score}}
      {n, _} ->
        cells = put_in(cells[y][x], {n, :show})
        {:noreply, %Board{board | cells: cells}}
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
        {:noreply, %Board{board | cells: cells, flags: board.flags + 1}}
    end
  end

  defp discover({cells, score}, 0, _, _w, _h), do: {cells, score}
  defp discover({cells, score}, _, 0, _w, _h), do: {cells, score}
  defp discover({cells, score}, i, _, _w, h) when i > h, do: {cells, score}
  defp discover({cells, score}, _, j, w, _h) when j > w, do: {cells, score}
  defp discover({cells, score}, i, j, w, h) do
    case cells[i][j] do
      {0, :hidden} ->
        cells = cells
                |> put_in([i, j], {0, :show})
        {cells, score}
        |> discover(i-1, j-1, w, h)
        |> discover(i-1, j, w, h)
        |> discover(i-1, j+1, w, h)
        |> discover(i, j+1, w, h)
        |> discover(i+1, j+1, w, h)
        |> discover(i+1, j, w, h)
        |> discover(i+1, j-1, w, h)
        |> discover(i, j-1, w, h)
      {n, :hidden} when is_integer(n) ->
        {put_in(cells[i][j], {n, :show}), score + @base_points}
      {n, :show} when is_integer(n) ->
        {cells, score}
    end
  end
end
