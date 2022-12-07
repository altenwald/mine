defmodule MineTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureIO

  test "start and stop game" do
    Application.put_env(:mine, :width, 4)
    Application.put_env(:mine, :height, 4)
    Application.put_env(:mine, :mines, [{1, 1}, {2, 2}])
    assert """
           Mine 0.6.0
           Score: 0
           Flags: 0
           1    2    3    4
           1 [   ][   ][   ][   ]   1
           2 [   ][   ][   ][   ]   2
           3 [   ][   ][   ][   ]   3
           4 [   ][   ][   ][   ]   4
           """ == Mine.ANSI.clean(capture_io(fn -> Mine.start() end))

    ref = Process.monitor(Mine.Game.get_pid(Mine))
    Mine.stop()
    assert_receive {:DOWN, ^ref, :process, _pid, _reason}
  end

  test "restart" do
    Application.put_env(:mine, :width, 4)
    Application.put_env(:mine, :height, 4)
    Application.put_env(:mine, :mines, [{1, 1}, {2, 2}])

    assert """
           Mine 0.6.0
           Score: 0
           Flags: 0
           1    2    3    4
           1 [   ][   ][   ][   ]   1
           2 [   ][   ][   ][   ]   2
           3 [   ][   ][   ][   ]   3
           4 [   ][   ][   ][   ]   4
           """ == Mine.ANSI.clean(capture_io(fn -> Mine.start() end))

    assert """
           Mine 0.6.0
           Score: 999
           Flags: 0
           1    2    3    4
           1 [   ][   ][ 1 ][   ]   1
           2 [   ][   ][   ][   ]   2
           3 [   ][   ][   ][   ]   3
           4 [   ][   ][   ][   ]   4
           """ == Mine.ANSI.clean(capture_io(fn -> Mine.sweep(3, 1) end))

    assert """
           Mine 0.6.0
           Score: 1998
           Flags: 0
           1    2    3    4
           1 [   ][   ][ 1 ][   ]   1
           2 [   ][   ][ 1 ][   ]   2
           3 [   ][   ][   ][   ]   3
           4 [   ][   ][   ][   ]   4
           """ == Mine.ANSI.clean(capture_io(fn -> Mine.sweep(3, 2) end))

    assert """
           Mine 0.6.0
           Score: 0
           Flags: 0
           1    2    3    4
           1 [   ][   ][   ][   ]   1
           2 [   ][   ][   ][   ]   2
           3 [   ][   ][   ][   ]   3
           4 [   ][   ][   ][   ]   4
           """ == Mine.ANSI.clean(capture_io(fn -> Mine.restart() end))

    ref = Process.monitor(Mine.Game.get_pid(Mine))
    Mine.stop()
    assert_receive {:DOWN, ^ref, :process, _pid, _reason}
  end

  test "boom" do
    Application.put_env(:mine, :width, 4)
    Application.put_env(:mine, :height, 4)
    Application.put_env(:mine, :mines, [{1, 1}, {2, 2}])
    assert """
           Mine 0.6.0
           Score: 0
           Flags: 0
           1    2    3    4
           1 [   ][   ][   ][   ]   1
           2 [   ][   ][   ][   ]   2
           3 [   ][   ][   ][   ]   3
           4 [   ][   ][   ][   ]   4
           """ == Mine.ANSI.clean(capture_io(fn -> Mine.start() end))

    assert """
           Mine 0.6.0
           Score: 0
           Flags: 0
           1    2    3    4
           1 [ ☠ ][   ][   ][   ]   1
           2 [   ][   ][   ][   ]   2
           3 [   ][   ][   ][   ]   3
           4 [   ][   ][   ][   ]   4
           G A M E   O V E R ! ! !
           """ == Mine.ANSI.clean(capture_io(fn -> Mine.sweep(1, 1) end))

    ref = Process.monitor(Mine.Game.get_pid(Mine))
    Mine.stop()
    assert_receive {:DOWN, ^ref, :process, _pid, _reason}
  end

  test "flag error" do
    Application.put_env(:mine, :width, 4)
    Application.put_env(:mine, :height, 4)
    Application.put_env(:mine, :mines, [{1, 1}, {2, 2}])
    assert """
           Mine 0.6.0
           Score: 0
           Flags: 0
           1    2    3    4
           1 [   ][   ][   ][   ]   1
           2 [   ][   ][   ][   ]   2
           3 [   ][   ][   ][   ]   3
           4 [   ][   ][   ][   ]   4
           """ == Mine.ANSI.clean(capture_io(fn -> Mine.start() end))

    assert """
           Mine 0.6.0
           Score: 999
           Flags: 0
           1    2    3    4
           1 [   ][   ][ 1 ][   ]   1
           2 [   ][   ][   ][   ]   2
           3 [   ][   ][   ][   ]   3
           4 [   ][   ][   ][   ]   4
           """ == Mine.ANSI.clean(capture_io(fn -> Mine.sweep(3, 1) end))

    assert """
           Mine 0.6.0
           Score: 999
           Flags: 1
           1    2    3    4
           1 [   ][   ][ 1 ][ ⚑ ]   1
           2 [   ][   ][   ][   ]   2
           3 [   ][   ][   ][   ]   3
           4 [   ][   ][   ][   ]   4
           """ == Mine.ANSI.clean(capture_io(fn -> Mine.flag(4, 1) end))

    assert """
           Mine 0.6.0
           Score: 999
           Flags: 1
           1    2    3    4
           1 [   ][ 2 ][ 1 ][ ☀︎ ]   1
           2 [   ][ ☠ ][ 1 ][   ]   2
           3 [   ][   ][   ][   ]   3
           4 [   ][   ][   ][   ]   4
           G A M E   O V E R ! ! !
           """ == Mine.ANSI.clean(capture_io(fn -> Mine.sweep(3, 1) end))

    ref = Process.monitor(Mine.Game.get_pid(Mine))
    Mine.stop()
    assert_receive {:DOWN, ^ref, :process, _pid, _reason}
  end

  test "win" do
    Application.put_env(:mine, :width, 4)
    Application.put_env(:mine, :height, 4)
    Application.put_env(:mine, :mines, [{1, 1}, {2, 2}])
    assert """
           Mine 0.6.0
           Score: 0
           Flags: 0
           1    2    3    4
           1 [   ][   ][   ][   ]   1
           2 [   ][   ][   ][   ]   2
           3 [   ][   ][   ][   ]   3
           4 [   ][   ][   ][   ]   4
           """ == Mine.ANSI.clean(capture_io(fn -> Mine.start() end))

    assert """
           Mine 0.6.0
           Score: 11988
           Flags: 0
           1    2    3    4
           1 [   ][   ][ 1 ][   ]   1
           2 [   ][   ][ 1 ][   ]   2
           3 [ 1 ][ 1 ][ 1 ][   ]   3
           4 [   ][   ][   ][   ]   4
           """ == Mine.ANSI.clean(capture_io(fn -> Mine.sweep(1, 4) end))

    assert """
           Mine 0.6.0
           Score: 11988
           Flags: 1
           1    2    3    4
           1 [   ][   ][ 1 ][   ]   1
           2 [   ][ ⚑ ][ 1 ][   ]   2
           3 [ 1 ][ 1 ][ 1 ][   ]   3
           4 [   ][   ][   ][   ]   4
           """ == Mine.ANSI.clean(capture_io(fn -> Mine.flag(2, 2) end))

    assert """
           Mine 0.6.0
           Score: 12987
           Flags: 1
           1    2    3    4
           1 [   ][   ][ 1 ][   ]   1
           2 [ 2 ][ ⚑ ][ 1 ][   ]   2
           3 [ 1 ][ 1 ][ 1 ][   ]   3
           4 [   ][   ][   ][   ]   4
           """ == Mine.ANSI.clean(capture_io(fn -> Mine.sweep(1, 2) end))

    assert """
           Mine 0.6.0
           Score: 13986
           Flags: 1
           1    2    3    4
           1 [   ][ 2 ][ 1 ][   ]   1
           2 [ 2 ][ ⚑ ][ 1 ][   ]   2
           3 [ 1 ][ 1 ][ 1 ][   ]   3
           4 [   ][   ][   ][   ]   4
           G A M E   O V E R ! ! !
           """ == Mine.ANSI.clean(capture_io(fn -> Mine.sweep(3, 2) end))

    ref = Process.monitor(Mine.Game.get_pid(Mine))
    Mine.stop()
    assert_receive {:DOWN, ^ref, :process, _pid, _reason}
  end
end
