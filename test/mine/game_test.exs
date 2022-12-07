defmodule Mine.Game.BoardTest do
  use ExUnit.Case
  alias Mine.Game
  import Mine.BoardHelper

  setup do
    Application.put_env(:mine, :mines, 40)
    Application.put_env(:mine, :height, 16)
    Application.put_env(:mine, :width, 16)
    Application.put_env(:mine, :total_time, 999)
    :ok
  end

  describe "build board" do
    test "start/stop" do
      game_id = Ecto.UUID.generate()
      Application.put_env(:mine, :width, 4)
      Application.put_env(:mine, :height, 4)
      Application.put_env(:mine, :mines, [{1, 1}, {2, 2}, {3, 3}, {4, 4}])
      assert {:ok, pid} = Game.start(game_id)
      assert Game.exists?(game_id)

      ref = Process.monitor(pid)
      assert :ok = Game.stop(game_id)
      assert_receive {:DOWN, ^ref, :process, ^pid, _reason}
      refute Game.exists?(game_id)

      Enum.reduce_while(1..1_000, nil, fn _, _ ->
        if Game.get_pid(game_id), do: {:cont, :still_alive!}, else: {:halt, :ok}
      end)
    end

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

  describe "gameover" do
    test "cannot sweep" do
      game_id = Ecto.UUID.generate()
      Application.put_env(:mine, :width, 4)
      Application.put_env(:mine, :height, 4)
      Application.put_env(:mine, :mines, [{1, 1}])
      assert {:ok, _pid} = Game.start(game_id)
      Game.sweep(game_id, 1, 1)

      board = Game.show(game_id)
      Game.sweep(game_id, 2, 2)
      assert board == Game.show(game_id)

      Game.stop(game_id)
    end

    test "cannot flag/unflag" do
      game_id = Ecto.UUID.generate()
      Application.put_env(:mine, :width, 4)
      Application.put_env(:mine, :height, 4)
      Application.put_env(:mine, :mines, [{1, 1}, {2, 2}, {3, 3}, {4, 4}])
      assert {:ok, _pid} = Game.start(game_id)
      Game.sweep(game_id, 1, 1)

      board = Game.show(game_id)
      Game.flag(game_id, 2, 2)
      assert board == Game.show(game_id)

      Game.unflag(game_id, 2, 2)
      assert board == Game.show(game_id)

      Game.toggle_flag(game_id, 2, 2)
      assert board == Game.show(game_id)

      Game.stop(game_id)
    end

    test "receive last tick" do
      game_id = Ecto.UUID.generate()
      Application.put_env(:mine, :width, 4)
      Application.put_env(:mine, :height, 4)
      Application.put_env(:mine, :mines, [{1, 1}, {2, 2}, {3, 3}, {4, 4}])
      assert {:ok, pid} = Game.start(game_id)
      Game.subscribe(game_id)

      Game.sweep(game_id, 1, 1)
      assert %Game.Worker{timer: timer_ref} = :sys.get_state(pid)
      assert timer_ref != nil

      assert_receive :gameover
      send(pid, :tick)
      assert %Game.Worker{timer: nil} = :sys.get_state(pid)

      Game.stop(game_id)
    end

    test "timeout" do
      game_id = Ecto.UUID.generate()
      Application.put_env(:mine, :width, 4)
      Application.put_env(:mine, :height, 4)
      Application.put_env(:mine, :mines, [{1, 1}, {2, 2}, {3, 3}, {4, 4}])
      Application.put_env(:mine, :total_time, 1)
      assert {:ok, pid} = Game.start(game_id)
      Game.subscribe(game_id)
      Game.sweep(game_id, 1, 2)

      send(pid, :tick)
      assert_receive :gameover

      Game.stop(game_id)
    end

    test "last subscriber terminates process" do
      game_id = Ecto.UUID.generate()
      Application.put_env(:mine, :width, 4)
      Application.put_env(:mine, :height, 4)
      Application.put_env(:mine, :mines, [{1, 1}, {2, 2}, {3, 3}, {4, 4}])
      assert {:ok, pid} = Game.start(game_id)
      ref = Process.monitor(pid)
      parent = self()

      {child_pid, child_ref} =
        spawn_monitor(fn ->
          Game.subscribe(game_id)
          send(parent, :continue)
          assert_receive :gameover, 5_000
        end)

      assert_receive :continue
      Game.sweep(game_id, 1, 1)

      assert_receive {:DOWN, ^child_ref, :process, ^child_pid, _reason}
      assert_receive {:DOWN, ^ref, :process, ^pid, _reason}
    end

    test "subscriber terminates during gameover" do
      game_id = Ecto.UUID.generate()
      Application.put_env(:mine, :width, 4)
      Application.put_env(:mine, :height, 4)
      Application.put_env(:mine, :mines, [{1, 1}, {2, 2}, {3, 3}, {4, 4}])
      assert {:ok, pid} = Game.start(game_id)
      Game.subscribe(game_id)
      ref = Process.monitor(pid)
      parent = self()

      {child_pid, child_ref} =
        spawn_monitor(fn ->
          Game.subscribe(game_id)
          send(parent, :continue)
          assert_receive :gameover, 5_000
        end)

      assert_receive :continue
      Game.sweep(game_id, 1, 1)

      assert_receive {:DOWN, ^child_ref, :process, ^child_pid, _reason}
      refute_receive {:DOWN, ^ref, :process, ^pid, _reason}, 500
      Game.stop(game_id)
    end
  end

  describe "sweep" do
    test "4x4 4 mines block discover (4,1)" do
      game_id = Ecto.UUID.generate()
      Application.put_env(:mine, :width, 4)
      Application.put_env(:mine, :height, 4)
      Application.put_env(:mine, :mines, [{1, 1}, {2, 2}, {3, 3}, {4, 4}])
      assert {:ok, _pid} = Game.start(game_id)

      assert """
             ????
             ????
             ????
             ????
             """ == tr_hidden(Game.show(game_id))

      Game.sweep(game_id, 4, 1)

      assert """
             ??1_
             ??21
             ????
             ????
             """ == tr_hidden(Game.show(game_id))

      assert 3996 == Game.score(game_id)
      Game.stop(game_id)
    end

    test "4x4 4 mines block discover (1,4)" do
      game_id = Ecto.UUID.generate()
      Application.put_env(:mine, :width, 4)
      Application.put_env(:mine, :height, 4)
      Application.put_env(:mine, :mines, [{1, 1}, {2, 2}, {3, 3}, {4, 4}])
      assert {:ok, _pid} = Game.start(game_id)

      Game.sweep(game_id, 1, 3)

      assert """
             ????
             ????
             1???
             ????
             """ == tr_hidden(Game.show(game_id))

      Game.sweep(game_id, 1, 4)

      assert """
             ????
             ????
             12??
             _1??
             """ == tr_hidden(Game.show(game_id))

      assert 3996 == Game.score(game_id)
      Game.stop(game_id)
    end

    test "4x4 4 mines shown discover" do
      game_id = Ecto.UUID.generate()
      Application.put_env(:mine, :width, 4)
      Application.put_env(:mine, :height, 4)
      Application.put_env(:mine, :mines, [{1, 1}, {2, 2}, {3, 3}, {4, 4}])
      assert {:ok, _pid} = Game.start(game_id)

      Game.sweep(game_id, 1, 3)

      assert """
             ????
             ????
             1???
             ????
             """ == tr_hidden(Game.show(game_id))

      # no action if "1" hasn't a "F" around
      Game.sweep(game_id, 1, 3)

      assert """
             ????
             ????
             1???
             ????
             """ == tr_hidden(Game.show(game_id))

      Game.flag(game_id, 2, 2)
      # no action pressing on "F"
      Game.sweep(game_id, 2, 2)

      assert """
             ????
             ?F??
             1???
             ????
             """ == tr_hidden(Game.show(game_id))

      Game.sweep(game_id, 1, 3)
      # no action pressing on "0"
      Game.sweep(game_id, 1, 4)

      assert """
             ????
             2F??
             12??
             _1??
             """ == tr_hidden(Game.show(game_id))

      assert 4995 == Game.score(game_id)
      Game.stop(game_id)
    end

    test "4x4 4 mines wrong discover with a flag" do
      game_id = Ecto.UUID.generate()
      Application.put_env(:mine, :width, 4)
      Application.put_env(:mine, :height, 4)
      Application.put_env(:mine, :mines, [{1, 1}, {2, 2}, {3, 3}, {4, 4}])
      assert {:ok, _pid} = Game.start(game_id)
      Game.subscribe(game_id)

      Game.sweep(game_id, 1, 3)

      assert """
             ????
             ????
             1???
             ????
             """ == tr_hidden(Game.show(game_id))

      Game.flag(game_id, 1, 2)

      assert """
             ????
             F???
             1???
             ????
             """ == tr_hidden(Game.show(game_id))

      Game.sweep(game_id, 1, 3)

      assert """
             MH 2H 1H 0H
             2X MS 2H 1H
             1S 2S MH 2H
             0S 1S 2H MH
             """ == tr(Game.show(game_id))

      assert_receive :gameover
      Game.stop(game_id)
    end

    test "4x4 4 mines wrong discover" do
      game_id = Ecto.UUID.generate()
      Application.put_env(:mine, :width, 4)
      Application.put_env(:mine, :height, 4)
      Application.put_env(:mine, :mines, [{1, 1}, {2, 2}, {3, 3}, {4, 4}])
      assert {:ok, _pid} = Game.start(game_id)
      Game.subscribe(game_id)

      assert :play == Game.status(game_id)

      Game.sweep(game_id, 1, 1)

      assert :gameover == Game.status(game_id)

      assert_receive :gameover
      Game.stop(game_id)
    end

    test "4x4 filled" do
      game_id = Ecto.UUID.generate()
      Application.put_env(:mine, :width, 4)
      Application.put_env(:mine, :height, 4)
      Application.put_env(:mine, :mines, [{1, 1}])
      assert {:ok, _pid} = Game.start(game_id)
      Game.subscribe(game_id)

      assert :play == Game.status(game_id)

      Game.sweep(game_id, 4, 4)

      assert """
             ?1__
             11__
             ____
             ____
             """ == tr_hidden(Game.show(game_id))

      assert 14_985 == Game.score(game_id)
      assert_receive :win
      Game.stop(game_id)
    end
  end

  describe "flags" do
    test "flag/unflag a position" do
      game_id = Ecto.UUID.generate()
      Application.put_env(:mine, :width, 4)
      Application.put_env(:mine, :height, 4)
      Application.put_env(:mine, :mines, [{1, 1}, {2, 2}])
      assert {:ok, _pid} = Game.start(game_id)

      Game.flag(game_id, 1, 1)

      assert """
             F???
             ????
             ????
             ????
             """ == tr_hidden(Game.show(game_id))

      assert 1 == Game.flags(game_id)
      Game.flag(game_id, 1, 1)

      assert """
             F???
             ????
             ????
             ????
             """ == tr_hidden(Game.show(game_id))

      assert 1 == Game.flags(game_id)
      Game.unflag(game_id, 1, 1)
      assert 0 == Game.flags(game_id)

      assert """
             ????
             ????
             ????
             ????
             """ == tr_hidden(Game.show(game_id))

      Game.unflag(game_id, 1, 1)
      assert 0 == Game.flags(game_id)

      assert """
             ????
             ????
             ????
             ????
             """ == tr_hidden(Game.show(game_id))

      Game.stop(game_id)
    end

    test "cannot flag/unflag a shown position" do
      game_id = Ecto.UUID.generate()
      Application.put_env(:mine, :width, 4)
      Application.put_env(:mine, :height, 4)
      Application.put_env(:mine, :mines, [{1, 1}, {2, 2}, {3, 3}, {4, 4}])
      assert {:ok, _pid} = Game.start(game_id)

      Game.sweep(game_id, 1, 3)

      assert """
             ????
             ????
             1???
             ????
             """ == tr_hidden(Game.show(game_id))

      Game.sweep(game_id, 1, 4)

      assert """
             ????
             ????
             12??
             _1??
             """ == tr_hidden(Game.show(game_id))

      assert 0 == Game.flags(game_id)
      Game.flag(game_id, 1, 4)

      assert """
             ????
             ????
             12??
             _1??
             """ == tr_hidden(Game.show(game_id))

      assert 0 == Game.flags(game_id)
      Game.unflag(game_id, 1, 4)

      assert """
             ????
             ????
             12??
             _1??
             """ == tr_hidden(Game.show(game_id))

      assert 0 == Game.flags(game_id)
      Game.toggle_flag(game_id, 1, 4)

      assert """
             ????
             ????
             12??
             _1??
             """ == tr_hidden(Game.show(game_id))

      assert 0 == Game.flags(game_id)
      Game.stop(game_id)
    end

    test "toggle flag" do
      game_id = Ecto.UUID.generate()
      Application.put_env(:mine, :width, 4)
      Application.put_env(:mine, :height, 4)
      Application.put_env(:mine, :mines, [{1, 1}, {2, 2}])
      assert {:ok, _pid} = Game.start(game_id)

      Game.toggle_flag(game_id, 1, 1)

      assert """
             F???
             ????
             ????
             ????
             """ == tr_hidden(Game.show(game_id))

      assert 1 == Game.flags(game_id)
      Game.toggle_flag(game_id, 1, 1)
      assert 0 == Game.flags(game_id)

      assert """
             ????
             ????
             ????
             ????
             """ == tr_hidden(Game.show(game_id))

      Game.stop(game_id)
    end
  end

  describe "timing" do
    test "no starting timer" do
      game_id = Ecto.UUID.generate()
      Application.put_env(:mine, :width, 4)
      Application.put_env(:mine, :height, 4)
      Application.put_env(:mine, :mines, [{1, 1}])
      assert {:ok, pid} = Game.start(game_id)
      time = Game.time(game_id)

      assert :play == Game.status(game_id)

      assert %Game.Worker{timer: nil} = :sys.get_state(pid)
      assert time == Game.time(game_id)

      Game.stop(game_id)
    end

    test "show during pause" do
      game_id = Ecto.UUID.generate()
      Application.put_env(:mine, :width, 4)
      Application.put_env(:mine, :height, 4)
      Application.put_env(:mine, :mines, [{1, 1}, {2, 2}, {3, 3}, {4, 4}])
      assert {:ok, _pid} = Game.start(game_id)

      # starting timer with our first sweep
      Game.sweep(game_id, 4, 1)

      assert :play == Game.status(game_id)

      Game.toggle_pause(game_id)
      assert :pause == Game.status(game_id)

      assert [] == Game.show(game_id)

      Game.stop(game_id)
    end

    test "try flag changing during pause" do
      game_id = Ecto.UUID.generate()
      Application.put_env(:mine, :width, 4)
      Application.put_env(:mine, :height, 4)
      Application.put_env(:mine, :mines, [{1, 1}, {2, 2}, {3, 3}, {4, 4}])
      assert {:ok, pid} = Game.start(game_id)

      # starting timer with our first sweep
      Game.sweep(game_id, 4, 1)

      assert :play == Game.status(game_id)

      Game.toggle_pause(game_id)
      assert :pause == Game.status(game_id)

      assert %Game.Worker{} = state = :sys.get_state(pid)
      Game.toggle_flag(game_id, 1, 1)
      assert %Game.Worker{} = ^state = :sys.get_state(pid)
      Game.flag(game_id, 1, 1)
      assert %Game.Worker{} = ^state = :sys.get_state(pid)
      Game.unflag(game_id, 1, 1)
      assert %Game.Worker{} = ^state = :sys.get_state(pid)

      Game.stop(game_id)
    end

    test "try sweep during pause" do
      game_id = Ecto.UUID.generate()
      Application.put_env(:mine, :width, 4)
      Application.put_env(:mine, :height, 4)
      Application.put_env(:mine, :mines, [{1, 1}, {2, 2}, {3, 3}, {4, 4}])
      assert {:ok, pid} = Game.start(game_id)

      # starting timer with our first sweep
      Game.sweep(game_id, 4, 1)

      assert :play == Game.status(game_id)

      Game.toggle_pause(game_id)
      assert :pause == Game.status(game_id)

      assert %Game.Worker{} = state = :sys.get_state(pid)
      Game.sweep(game_id, 1, 1)
      assert %Game.Worker{} = ^state = :sys.get_state(pid)

      Game.stop(game_id)
    end

    test "pause/unpause game" do
      game_id = Ecto.UUID.generate()
      Application.put_env(:mine, :width, 4)
      Application.put_env(:mine, :height, 4)
      Application.put_env(:mine, :mines, [{1, 1}, {2, 2}, {3, 3}, {4, 4}])
      assert {:ok, pid} = Game.start(game_id)
      time = Game.time(game_id)

      # starting timer with our first sweep
      Game.sweep(game_id, 4, 1)

      assert :play == Game.status(game_id)

      Game.toggle_pause(game_id)
      assert :pause == Game.status(game_id)

      send(pid, :tick)
      assert time == Game.time(game_id)

      Game.toggle_pause(game_id)
      assert :play == Game.status(game_id)

      send(pid, :tick)
      assert time > Game.time(game_id)

      Game.stop(game_id)
    end
  end

  describe "hiscore" do
    test "setting hiscore name" do
      game_id = Ecto.UUID.generate()
      Application.put_env(:mine, :width, 4)
      Application.put_env(:mine, :height, 4)
      Application.put_env(:mine, :mines, [{1, 1}])
      Mine.HiScore.delete_all()
      assert {:ok, _pid} = Game.start(game_id)
      Game.subscribe(game_id)

      assert :play == Game.status(game_id)

      Game.sweep(game_id, 4, 4)

      assert """
             ?1__
             11__
             ____
             ____
             """ == tr_hidden(Game.show(game_id))

      assert 14_985 == Game.score(game_id)
      assert_receive :win
      Game.hiscore(game_id, "Duendecillo salvaje", "127.0.0.1")
      assert_receive {:hiscore, {:ok, 1}}
      Game.stop(game_id)
    end
  end
end
