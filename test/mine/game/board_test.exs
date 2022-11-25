defmodule Mine.Game.BoardTest do
  use ExUnit.Case
  alias Mine.Game.Board

  defp visibility(:hidden), do: "H"
  defp visibility(:flag), do: "F"
  defp visibility(:show), do: "S"

  defp content(n) when n in 0..9, do: to_string(n)
  defp content(:mine), do: "M"

  defp tr(board) do
    for row <- Board.get_naive_cells(board) do
      for {content, visibility} <- row do
        content(content) <> visibility(visibility)
      end
      |> Enum.join(" ")
      |> String.replace_suffix("", "\n")
    end
    |> Enum.join()
  end

  defp tr_hidden(board) do
    for row <- Board.get_naive_cells(board) do
      for {content, visibility} <- row do
        cond do
          visibility == :hidden -> "?"
          visibility == :flag -> "F"
          content == :mine -> "X"
          content == 0 -> "_"
          :else -> to_string(content)
        end
      end
      |> Enum.join()
      |> String.replace_suffix("", "\n")
    end
    |> Enum.join()
  end

  describe "build board" do
    test "providing positions" do
      board = Board.new(4, 4, [{1, 1}, {2, 2}, {3, 3}, {4, 4}])

      assert """
             MH 2H 1H 0H
             2H MH 2H 1H
             1H 2H MH 2H
             0H 1H 2H MH
             """ == tr(board)
    end

    test "random generation" do
      board = Board.new(4, 4, 4)

      mines =
        board
        |> Board.get_naive_cells()
        |> List.flatten()
        |> Enum.filter(fn {content, _} -> content == :mine end)

      assert 4 == length(mines)
    end
  end

  describe "discover" do
    test "4x4 4 mines block" do
      board = Board.new(4, 4, [{1, 1}, {2, 2}, {3, 3}, {4, 4}])
      {board, score} = Board.discover({board, 10}, 4, 1, 100)

      assert """
             ??1_
             ??21
             ????
             ????
             """ == tr_hidden(board)

      assert 410 == score
    end
  end
end
