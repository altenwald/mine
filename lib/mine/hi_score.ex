defmodule Mine.HiScore do
  @moduledoc """
  Schema for storing the high scores from players.
  """
  use Ecto.Schema

  import Ecto.Query, only: [from: 2]
  import Ecto.Changeset

  alias Mine.{HiScore, Repo}

  @top_num 20

  schema "hi_score" do
    field(:name)
    field(:score, :integer)
    field(:time, :integer)
    field(:remote_ip)

    timestamps()
  end

  @required_fields [:name, :score, :time, :remote_ip]
  @optional_fields []

  def changeset(model, params \\ %{}) do
    model
    |> cast(params, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
  end

  def save(name, score, time, remote_ip) do
    changeset(%HiScore{}, %{
      "name" => name,
      "score" => score,
      "time" => time,
      "remote_ip" => remote_ip
    })
    |> Repo.insert()
  end

  defp get_order_index([]), do: {:error, :notfound}
  defp get_order_index([{%HiScore{}, order} | _]), do: {:ok, order}

  def get_order(my_id) do
    from(h in HiScore, order_by: [desc: h.score])
    |> Repo.all()
    |> Enum.with_index(1)
    |> Enum.filter(fn {%HiScore{id: id}, _} -> id == my_id end)
    |> get_order_index()
  end

  def top_list do
    from(h in HiScore, order_by: [desc: h.score, desc: h.time], limit: @top_num)
    |> Repo.all()
  end
end
