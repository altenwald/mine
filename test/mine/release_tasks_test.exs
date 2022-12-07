defmodule Mine.ReleaseTasksTest do
  use ExUnit.Case, async: false
  alias Mine.ReleaseTasks

  test "drop database and ensure it's created" do
    assert [_ | _] = :mnesia.table_info(:hi_score, :all)
    assert :ok = ReleaseTasks.drop_database()

    assert catch_exit(:mnesia.table_info(:hi_score, :all)) ==
             {:aborted, {:no_exists, :hi_score, :all}}

    assert {:error, :already_up} = ReleaseTasks.ensure_database_created()
    assert ReleaseTasks.run_migrations()
    assert [_ | _] = :mnesia.table_info(:hi_score, :all)
  end
end
