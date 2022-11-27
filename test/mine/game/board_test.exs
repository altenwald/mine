defmodule Mine.Game.BoardTest do
  use ExUnit.Case
  alias Mine.Game.Board
  import Mine.BoardHelper

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

    test "exhausted options" do
      assert catch_throw(Board.new(4, 4, 17)) == :exhausted
    end
  end

  describe "discover" do
    test "4x4 4 mines block discover (4,1)" do
      board = Board.new(4, 4, [{1, 1}, {2, 2}, {3, 3}, {4, 4}])

      assert """
             ????
             ????
             ????
             ????
             """ == tr_hidden(board)

      {board, score} = Board.discover({board, 10}, 4, 1, 100)

      assert """
             ??1_
             ??21
             ????
             ????
             """ == tr_hidden(board)

      assert 410 == score
    end

    test "4x4 4 mines block discover (1,4)" do
      board = Board.new(4, 4, [{1, 1}, {2, 2}, {3, 3}, {4, 4}])
      {board, score1} = Board.discover({board, 10}, 1, 3, 100)

      assert """
              ????
              ????
              1???
              ????
              """ == tr_hidden(board)

      {board, score2} = Board.discover({board, 10}, 1, 4, 100)

      assert """
             ????
             ????
             12??
             _1??
             """ == tr_hidden(board)

      assert 420 == score1 + score2
    end

    test "4x4 4 mines wrong discover" do
      board = Board.new(4, 4, [{1, 1}, {2, 2}, {3, 3}, {4, 4}])
      assert catch_throw(Board.discover({board, 10}, 1, 1, 100)) == :boom
    end
  end

  describe "discover error" do
    test "4x4 4 mines discover error (1,1)" do
      board =
        Board.new(4, 4, [{1, 1}, {2, 2}, {3, 3}, {4, 4}])
        |> Board.discover_error(1, 2)

      assert """
             X2??
             ?X??
             12??
             ????
             """ == tr_hidden(board)
    end
  end

  describe "get and put cells" do
    test "get cells" do
      board = Board.new(4, 4, [{1, 1}, {2, 1}, {3, 2}, {2, 4}])

      assert """
             MH MH 2H 1H
             2H 3H MH 1H
             1H 2H 2H 1H
             1H MH 1H 0H
             """ == tr(board)

      assert {:mine, :hidden} = Board.get_cell(board, 1, 1)
      assert {:mine, :hidden} = Board.get_cell(board, 2, 1)
      assert {:mine, :hidden} = Board.get_cell(board, 2, 4)
      assert {3, :hidden} = Board.get_cell(board, 2, 2)
      assert {0, :hidden} = Board.get_cell(board, 4, 4)
    end
  end
end
