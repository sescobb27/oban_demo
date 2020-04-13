defmodule ObanDemo.MixProject do
  use Mix.Project

  def project do
    [
      app: :oban_demo,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {ObanDemo.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:oban, "~> 1.2"},
      {:ecto, "~> 3.4"},
      {:postgrex, ">= 0.0.0"}
    ]
  end
end
