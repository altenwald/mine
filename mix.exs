defmodule Mine.MixProject do
  use Mix.Project

  def project do
    [
      app: :mine,
      version: "0.4.1",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :mnesia],
      mod: {Mine.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:jason, "~> 1.1"},
      {:plug_cowboy, "~> 2.0"},
      {:uuid, "~> 1.1"},
      {:etag_plug, "~> 0.2.0"},
      {:ecto_mnesia, "~> 0.9.1"},
      {:number, "~> 1.0"},
      {:timex, "~> 3.5.0"},

      # for releases
      {:distillery, "~> 2.0"},
      {:ecto_boot_migration, "~> 0.1.1"},
    ]
  end
end
