defmodule Mine.MixProject do
  use Mix.Project

  def project do
    [
      app: :mine,
      version: "1.1.0",
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      releases: releases(),
      test_coverage: test_coverage(),
      dialyzer: dialyzer()
    ]
  end

  def cli do
    [preferred_envs: [check: :test, credo: :test, dialyzer: :test, doctor: :test]]
  end

  defp dialyzer do
    case System.get_env("DIALYZER_PLT_DIR") do
      nil ->
        []

      directory ->
        path = Path.join(directory, to_string(:erlang.system_info(:system_architecture)))
        [plt_local_path: path, plt_core_path: path]
    end
  end

  defp releases do
    [
      mine: [
        steps: [:assemble, :tar]
      ]
    ]
  end

  defp test_coverage do
    [
      summary: [threshold: 90],
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
      extra_applications: [:logger],
      mod: {Mine.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:gen_state_machine, "~> 3.0"},
      {:jason, "~> 1.4"},
      {:plug, "~> 1.14"},
      {:bandit, "~> 1.8"},
      {:websock_adapter, "~> 0.5"},
      {:ecto_sql, "~> 3.13"},
      {:ecto_sqlite3, "~> 0.26.0"},
      {:timex, "~> 3.7"},

      # for test
      {:websockex, "~> 0.4", only: :test},

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
      release: [
        "deps.get --only prod",
        "compile",
        "release --overwrite"
      ],
      check: [
        "ecto.create",
        "ecto.migrate",
        "check"
      ]
    ]
  end
end
