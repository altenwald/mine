defmodule Mine.ReleaseTasksTest do
  use ExUnit.Case, async: false
  alias Mine.ReleaseTasks

  test "migrations are idempotent and preserve scores" do
    {:ok, score} = Mine.HiScore.save("Migration test", 10, 5, "127.0.0.1")
    assert :ok = ReleaseTasks.run_migrations()
    assert :ok = ReleaseTasks.run_migrations()
    assert Mine.Repo.get!(Mine.HiScore, score.id).name == "Migration test"
    Mine.Repo.delete!(score)
  end
end
