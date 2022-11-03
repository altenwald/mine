defmodule Mine.MixProject do
  use Mix.Project

  def project do
    [
      app: :mine,
      version: "0.6.0",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      preferred_cli_env: [
        check: :test,
        credo: :test,
        dialyzer: :test,
        doctor: :test
      ]
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
      {:jason, "~> 1.4"},
      {:plug, "~> 1.14"},
      {:plug_cowboy, "~> 2.6"},
      {:ecto_mnesia, github: "manuel-rubio/ecto_mnesia", branch: "support_for_ecto3"},
      {:number, "~> 1.0"},
      {:timex, "~> 3.5.0"},

      # for releases
      {:distillery, "~> 2.0"},
      {:ecto_boot_migration, "~> 0.3"},

      # tooling for quality check
      {:dialyxir, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:credo, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:doctor, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:ex_check, "~> 0.14", only: [:dev, :test], runtime: false},
      {:ex_doc, ">= 0.0.0", only: [:dev, :test], runtime: false}
    ]
  end

  defp aliases do
    [
      check: [
        "ecto.create",
        "ecto.migrate",
        "check"
      ]
    ]
  end
end
