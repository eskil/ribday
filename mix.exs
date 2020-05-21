defmodule Ribday.Mixfile do
  use Mix.Project

  def project do
    [
      app: :ribday,
      version: "0.1.0",
      elixir: "~> 1.5",
      start_permanent: Mix.env == :prod,
      escript: escript(),
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :httpoison, :timex, :tzdata]
    ]
  end

  def escript do
    [main_module: Main]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:gen_stage, "~> 1.0.0"},
      {:optimus, "~> 0.1.0"},
      {:httpoison, "~> 1.6"},
      {:poison, "~> 3.1"},
      {:morphix, git: "https://github.com/philosodad/morphix"},
      {:timex, "~> 3.6"},
      {:tzdata, "~> 0.1.8"}
    ]
  end
end
