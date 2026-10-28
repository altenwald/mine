defmodule Mine.Repo.Migrations.ImportProductionScores do
  use Ecto.Migration

  def up do
    if repo().aggregate(Mine.HiScore, :count) != 0 do
      raise "Production scores can only be imported into an empty hi_score table"
    end

    snapshot =
      :mine
      |> Application.app_dir("priv/repo/seeds/production_scores.json")
      |> File.read!()
      |> Jason.decode!()

    snapshot["scores"]
    |> Enum.map(fn row ->
      %{
        id: row["id"],
        name: row["name"],
        score: row["score"],
        time: row["time"],
        inserted_at: NaiveDateTime.from_iso8601!(row["inserted_at"]),
        updated_at: NaiveDateTime.from_iso8601!(row["updated_at"])
      }
    end)
    |> Enum.chunk_every(100)
    |> Enum.each(&repo().insert_all(Mine.HiScore, &1))
  end

  def down do
    raise "The production score import cannot be rolled back automatically"
  end
end
