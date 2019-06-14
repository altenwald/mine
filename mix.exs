defmodule Mine.MixProject do
  use Mix.Project

  def project do
    [
      app: :mine,
      version: "0.2.0",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

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
      {:jason, "~> 1.1"},
      {:plug_cowboy, "~> 2.0"},
      {:uuid, "~> 1.1"},
      {:etag_plug, "~> 0.2.0"},

      # for releases
      {:distillery, "~> 2.0"},
    ]
  end
end
