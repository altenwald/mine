defmodule Mine do
  @moduledoc """
  Documentation for Mine.
  """

  alias Mine.Game

  @game_id __MODULE__

  @doc """
  Start the one player game with a name.
  """
  @spec start :: :ok
  def start do
    Game.start(@game_id)
    show()
  end

  @doc """
  Stop a the game.
  """
  @spec stop :: :ok
  def stop do
    Game.stop(@game_id)
  end

  @doc """
  Perform a stop and start.
  """
  @spec restart :: :ok
  def restart do
    stop()
    start()
  end

  defp hidden_text(text) do
    IO.ANSI.white_background() <> IO.ANSI.black() <> text <> IO.ANSI.reset()
  end

  defp show_text(text) do
    IO.ANSI.black_background() <> IO.ANSI.white() <> text <> IO.ANSI.reset()
  end

  defp num(num, leading_pad \\ 4, trailing_pad \\ 5) do
    num
    |> to_string()
    |> String.pad_leading(leading_pad)
    |> String.pad_trailing(trailing_pad)
  end

  @doc """
  Show the board in a pretty way.
  """
  @spec show :: :ok
  def show do
    IO.puts(IO.ANSI.clear() <> "Mine " <> to_string(Application.spec(:mine)[:vsn]))
    IO.puts(IO.ANSI.underline() <> "Score" <> IO.ANSI.reset() <> ": #{Game.score(@game_id)}")
    IO.puts(IO.ANSI.underline() <> "Flags" <> IO.ANSI.reset() <> ": #{Game.flags(@game_id)}")
    board = Game.show(@game_id)

    1..length(board)
    |> Enum.reduce("\n     ", &"#{&2}#{num(&1, 3)}")
    |> IO.puts()

    Enum.with_index(board, 1)
    |> Enum.map(fn {rows, i} ->
      header = num(i)
      [header, Enum.map(rows, &to_cell/1), header, "\n"]
    end)
    |> IO.puts()

    IO.puts(IO.ANSI.reset())

    if Game.status(@game_id) == :gameover do
      IO.puts(IO.ANSI.blink_slow() <> "G A M E   O V E R ! ! !" <> IO.ANSI.blink_off())
    end

    :ok
  end

  defp to_cell({_, :hidden}), do: hidden_text("[   ]")
  defp to_cell({_, :flag}), do: hidden_text("[ ⚑ ]")
  defp to_cell({_, :flag_error}), do: hidden_text("[ ☀︎ ]")
  defp to_cell({:mine, _}), do: show_text("[ ☠ ]")
  defp to_cell({0, _}), do: show_text("[   ]")
  defp to_cell({n, _}), do: show_text("[ #{n} ]")

  @doc """
  Perform a sweep on the board. The sweep consist on unveil
  all of the still hidden blocks when an shown number is clicked.
  """
  @spec sweep(x :: pos_integer(), y :: pos_integer()) :: :ok
  def sweep(x, y) do
    Game.sweep(@game_id, x, y)
    show()
  end

  @doc """
  Flag an unveil cell avoiding it could be revealed.
  """
  @spec flag(x :: pos_integer(), y :: pos_integer()) :: :ok
  def flag(x, y) do
    Game.flag(@game_id, x, y)
    show()
  end
end
