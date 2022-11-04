defmodule Mine do
  @moduledoc """
  Documentation for Mine.
  """

  alias Mine.Board.OnePlayer
  alias Mine.Board

  @name __MODULE__

  def start do
    OnePlayer.start(@name)
    show()
  end

  def stop do
    Board.stop(@name)
  end

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

  def show do
    IO.puts(IO.ANSI.clear() <> "Mine " <> to_string(Application.spec(:mine)[:vsn]))
    IO.puts(IO.ANSI.underline() <> "Score" <> IO.ANSI.reset() <> ": #{Board.score(@name)}")
    IO.puts(IO.ANSI.underline() <> "Flags" <> IO.ANSI.reset() <> ": #{Board.flags(@name)}")
    board = Board.show(@name)

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

    if Board.status(@name) == :gameover do
      IO.puts(IO.ANSI.blink_slow() <> "G A M E   O V E R ! ! !" <> IO.ANSI.blink_off())
    end

    :ok
  end

  defp to_cell({_, :hidden}), do: hidden_text("[   ]")
  defp to_cell({_, :flag}), do: hidden_text("[ ⛳ ]")
  defp to_cell({_, :flag_error}), do: hidden_text("[ 💥 ]")
  defp to_cell({:mine, _}), do: show_text("[ ☠ ]")
  defp to_cell({0, _}), do: show_text("[   ]")
  defp to_cell({n, _}), do: show_text("[ #{n} ]")

  def sweep(x, y) do
    Board.sweep(@name, x, y)
    show()
  end

  def flag(x, y) do
    Board.flag(@name, x, y)
    show()
  end
end
