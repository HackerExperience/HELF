defmodule HELF.Mixfile do
  use Mix.Project

  def project do
    [
      app: :helf,
      version: "2.0.0",
      elixir: "~> 1.3",
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      deps: deps()]
  end

  def application do
    [
      applications: applications(Mix.env),
      mod: {HELF.App, []}]
  end

  defp applications(:dev), do: default_applications() ++ [:remix]
  defp applications(_), do: default_applications()
  defp default_applications, do: [:logger, :hebroker, :cowboy, :bamboo]

  defp deps do
    [
      {:cowboy,"~> 1.0"},
      {:poison, "~> 2.0"},
      {:bamboo, "~> 0.7"},
      {:hebroker, git: "ssh://git@git.hackerexperience.com/diffusion/BROKER/HEBroker.git", ref: "v0.1"},
      {:remix, "~> 0.0.1", only: :dev}]
  end
end