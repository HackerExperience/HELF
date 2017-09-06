defmodule HELF.Mixfile do
  use Mix.Project

  def project do
    [
      app: :helf,
      version: "0.0.1",
      elixir: "~> 1.3",
      dialyzer: [plt_add_apps: [:mix]],
      deps: deps()
    ]
  end

  def application do
    []
  end

  defp deps do
    [
      {:cowboy,"~> 1.0"},
      {:poison, "~> 2.0"},
      {:bamboo, "~> 0.8"},
      {:hebroker, github: "HackerExperience/HeBroker"}
    ]
  end
end
