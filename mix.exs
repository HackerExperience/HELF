defmodule HELF.Mixfile do
  use Mix.Project

  def project do
    [
      app: :helf,
      version: "0.0.1",
      elixir: "~> 1.3",
      deps: deps()]
  end

  def application do
    [
      mod: {HELF.App, []}]
  end

  defp deps do
    [
      {:cowboy,"~> 1.0"},
      {:poison, "~> 2.0"},
      {:bamboo, "~> 0.7"},
      {:hebroker, github: "HackerExperience/HeBroker"}
    ]
  end
end