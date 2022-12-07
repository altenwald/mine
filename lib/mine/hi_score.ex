defmodule Mine.HiScore do
  @moduledoc """
  Schema for storing the high scores from players.
  """
  use Ecto.Schema

  import Ecto.Query, only: [from: 2]
  import Ecto.Changeset

  alias Mine.{Game, HiScore, Repo}
  alias Mine.Game.Board

  @top_num 20

  @type hiscore_id() :: non_neg_integer()

  @type t() :: %__MODULE__{
          id: hiscore_id(),
          name: String.t(),
          score: non_neg_integer(),
          time: non_neg_integer(),
          remote_ip: String.t(),
          inserted_at: NaiveDateTime.t(),
          updated_at: NaiveDateTime.t()
        }

  schema "hi_score" do
    field(:name)
    field(:score, :integer)
    field(:time, :integer)
    field(:remote_ip)

    timestamps()
  end

  @required_fields [:name, :score, :time, :remote_ip]
  @optional_fields []

  @doc false
  def changeset(model, params) do
    model
    |> cast(params, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
  end

  @doc """
  Save a high score entry.
  """
  @spec save(String.t(), Board.score(), Game.time(), String.t()) :: {:ok, t()} | {:error, term()}
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

  @doc """
  Retrieve the order number base on the provided ID.
  """
  @spec get_order(hiscore_id()) :: {:ok, non_neg_integer()} | {:error, :notfound}
  def get_order(my_id) do
    from(h in HiScore, order_by: [desc: h.score])
    |> Repo.all()
    |> Enum.with_index(1)
    |> Enum.filter(fn {%HiScore{id: id}, _} -> id == my_id end)
    |> get_order_index()
  end

  @spec top_list() :: [t()]
  def top_list do
    from(h in HiScore, order_by: [desc: h.score, desc: h.time], limit: @top_num)
    |> Repo.all()
  end

  @doc false
  def delete_all do
    Repo.delete_all(__MODULE__)
  end
end
