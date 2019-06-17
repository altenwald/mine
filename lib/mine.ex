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

  def show do
    IO.puts IO.ANSI.clear() <> "Mine " <> to_string(Application.spec(:mine)[:vsn])
    IO.puts IO.ANSI.underline() <> "Score" <> IO.ANSI.reset() <> ": #{Board.score(@name)}"
    IO.puts IO.ANSI.underline() <> "Flags" <> IO.ANSI.reset() <> ": #{Board.flags(@name)}"
    board = Board.show(@name)
    for i <- 0..length(board) do
      if i == 0 do
        "\n     "
      else
        :io_lib.format(" ~2b  ", [i])
      end
    end
    |> IO.puts()
    for {rows, i} <- Enum.with_index(board, 1) do
      :io.format " ~3b ", [i]
      for cell <- rows, into: "" do
        case cell do
          {_, :hidden} -> hidden_text("[   ]")
          {_, :flag} -> hidden_text("[ ⛳ ]")
          {:mine, _} -> show_text("[ ☠ ]")
          {0, _} -> show_text("[   ]")
          {n, _} -> show_text("[ #{n} ]")
        end
      end <> to_string(:io_lib.format(" ~3b ", [i]))
      |> IO.puts()
    end
    IO.puts(IO.ANSI.reset())
    if Board.status(@name) == :gameover do
      IO.puts IO.ANSI.blink_slow() <> "G A M E   O V E R ! ! !" <> IO.ANSI.blink_off()
    end
    :ok
  end

  def sweep(x, y) do
    Board.sweep(@name, x, y)
    show()
  end

  def flag(x, y) do
    Board.flag(@name, x, y)
    show()
  end
end
