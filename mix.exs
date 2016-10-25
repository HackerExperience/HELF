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
      applications: [:logger, :hebroker, :cowboy],
      mod: {HELF.App, []}]
  end

  defp deps do
    [
      {:cowboy,"~> 1.0"},
      {:poison, "~> 2.0"},
      {:hebroker, git: "ssh://git@git.hackerexperience.com/diffusion/BROKER/HEBroker.git", ref: "v0.1"}]
  end
end
