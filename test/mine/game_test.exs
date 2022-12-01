defmodule Mine.Game.BoardTest do
  use ExUnit.Case
  alias Mine.Game
  import Mine.BoardHelper

  describe "build board" do
    test "providing positions" do
      game_id = Ecto.UUID.generate()
      Application.put_env(:mine, :width, 4)
      Application.put_env(:mine, :height, 4)
      Application.put_env(:mine, :mines, [{1, 1}, {2, 2}, {3, 3}, {4, 4}])
      assert {:ok, _pid} = Game.start(game_id)

      board = Game.show(game_id)

      assert """
             MH 2H 1H 0H
             2H MH 2H 1H
             1H 2H MH 2H
             0H 1H 2H MH
             """ == tr(board)

      assert :ok = Game.stop(game_id)
    end

    test "random generation" do
      game_id = Ecto.UUID.generate()
      Application.put_env(:mine, :width, 4)
      Application.put_env(:mine, :height, 4)
      Application.put_env(:mine, :mines, 4)
      assert {:ok, _pid} = Game.start(game_id)

      mines =
        game_id
        |> Game.show()
        |> List.flatten()
        |> Enum.filter(fn {content, _} -> content == :mine end)

      assert 4 == length(mines)
      assert :ok = Game.stop(game_id)
    end

    test "exhausted options" do
      game_id = Ecto.UUID.generate()
      Application.put_env(:mine, :width, 4)
      Application.put_env(:mine, :height, 4)
      Application.put_env(:mine, :mines, 17)
      assert {:error, {:bad_return_value, :exhausted}} = Game.start(game_id)
    end
  end
end
