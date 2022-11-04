defmodule Mine.ReleaseTasks do
  @moduledoc """
  Specific tasks to be performed from scripts in a release.
  """
  @repos Application.compile_env!(:mine, :ecto_repos)

  def run_migrations do
    Enum.each(@repos, &run_migrations_for/1)
  end

  def drop_database do
    # Create database
    IO.puts("==> Dropping database #{node()}")
    Mine.Repo.__adapter__().storage_down(Mine.Repo.config())
  end

  def ensure_database_created do
    # Config environment
    System.put_env("MNESIA_HOST", to_string(node()))
    File.mkdir_p!(Application.get_env(:mnesia, :dir))

    # Create database
    IO.puts("==> Creating database #{node()}")
    Mine.Repo.__adapter__().storage_up(Mine.Repo.config())
  end

  defp run_migrations_for(repo) do
    app = Keyword.get(repo.config, :otp_app)
    IO.puts("Running migrations for #{app}")
    migrations_path = priv_path_for(repo, "migrations")
    Ecto.Migrator.run(repo, migrations_path, :up, all: true)
  end

  defp priv_path_for(repo, filename) do
    app = Keyword.get(repo.config, :otp_app)

    repo_underscore =
      repo
      |> Module.split()
      |> List.last()
      |> Macro.underscore()

    priv_dir = "#{:code.priv_dir(app)}"

    Path.join([priv_dir, repo_underscore, filename])
  end
end
