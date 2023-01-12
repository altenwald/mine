defmodule Mine.MixProject do
  use Mix.Project

  def project do
    [
      app: :mine,
      version: "1.1.0",
      elixir: "~> 1.8",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      test_coverage: test_coverage(),
      preferred_cli_env: [
        check: :test,
        credo: :test,
        dialyzer: :test,
        doctor: :test
      ]
    ]
  end

  defp test_coverage do
    [
      ignore_modules: [
        Mine.ANSI,
        Mine.BoardHelper,
        Mine.WSCLI
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

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
      {:gen_state_machine, "~> 3.0"},
      {:jason, "~> 1.4"},
      {:plug, "~> 1.14"},
      {:plug_cowboy, "~> 2.6"},
      {:ecto_mnesia, github: "manuel-rubio/ecto_mnesia", branch: "support_for_ecto3"},
      {:number, "~> 1.0"},
      {:timex, "~> 3.7"},

      # for releases
      {:distillery, github: "bors-ng/distillery"},
      {:ecto_boot_migration, "~> 0.3"},

      # for test
      {:websockex, "~> 0.4", only: :test},

      # tooling for quality check
      {:dialyxir, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:credo, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:doctor, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:ex_check, "~> 0.14", only: [:dev, :test], runtime: false},
      {:ex_doc, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:mix_audit, ">= 0.0.0", only: [:dev, :test], runtime: false}
    ]
  end

  defp aliases do
    [
      release: [
        "deps.get",
        "compile",
        "distillery.release --upgrade --env=prod"
      ],
      check: [
        "ecto.create",
        "ecto.migrate",
        "check"
      ]
    ]
  end
end
