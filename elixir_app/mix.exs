defmodule ElixirApp.MixProject do
  use Mix.Project

  def project do
    [
      app: :elixir_app,
      version: "0.1.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
#      included_applications: [:config_reader]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:socket, "~> 0.3"},
      {:mime, git: "https://github.com/dynamo/mime.git", tag: "master"},
      {:timex, "~> 3.1"}
      # {:memoize, "~> 1.2"}
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"},
    ]
  end
end
