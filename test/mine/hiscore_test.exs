defmodule Mine.HiscoreTest do
  use ExUnit.Case, async: false
  alias Mine.HiScore

  setup do
    HiScore.delete_all()
    :ok
  end

  test "save hiscore" do
    assert {:ok,
            %HiScore{
              id: _,
              name: "Duendecillo",
              score: 1000,
              time: 1000,
              remote_ip: "127.0.0.1"
            }} = HiScore.save("Duendecillo", 1000, 1000, "127.0.0.1")
  end

  test "get hiscore" do
    assert {:ok, _} = HiScore.save("Duendecillo 3", 250, 1000, "127.0.0.1")
    assert {:ok, _} = HiScore.save("Duendecillo 1", 1000, 1000, "127.0.0.1")
    assert {:ok, _} = HiScore.save("Duendecillo 2", 500, 1000, "127.0.0.1")

    assert [
             %HiScore{name: "Duendecillo 1"},
             %HiScore{name: "Duendecillo 2"},
             %HiScore{name: "Duendecillo 3"}
           ] = HiScore.top_list()
  end

  test "get order" do
    assert {:ok, %_{id: d3}} = HiScore.save("Duendecillo 3", 250, 1000, "127.0.0.1")
    assert {:ok, %_{id: d1}} = HiScore.save("Duendecillo 1", 1000, 1000, "127.0.0.1")
    assert {:ok, %_{id: d2}} = HiScore.save("Duendecillo 2", 500, 1000, "127.0.0.1")

    assert {:ok, 1} == HiScore.get_order(d1)
    assert {:ok, 2} == HiScore.get_order(d2)
    assert {:ok, 3} == HiScore.get_order(d3)
    assert {:error, :notfound} == HiScore.get_order(0)
  end
end
