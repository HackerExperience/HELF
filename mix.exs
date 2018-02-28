defmodule HELF.Mixfile do
  use Mix.Project

  def project do
    [
      app: :helf,
      version: "0.0.3",
      elixir: "~> 1.5",
      dialyzer: [plt_add_apps: [:mix]],
      deps: deps(),
      description: description(),
      package: package()
    ]
  end

  def application do
    []
  end

  defp deps do
    [
      {:cowboy,"~> 1.1.2"},
      {:poison, "~> 3.1.0"},
      {:bamboo, "~> 0.8"},
      {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end

  defp description do
    "HELF - Hacker Experience Lovely Framework"
  end

  defp package do
    [
      maintainers: ["Renato Massaro"],
      licenses: ["Apache 2.0"],
      links: %{"GitHub" => "https://github.com/HackerExperience/HELF"}
    ]
  end
end
