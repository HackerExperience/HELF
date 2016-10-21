defmodule HELF.Mixfile do
  use Mix.Project

  def project do
    [app: :helf,
     version: "2.0.0",
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: applications(Mix.env),
     mod: {HELF.App, []}]
  end

  defp applications(:dev), do: default_applications ++ [:remix]
  defp applications(_), do: default_applications()
  defp default_applications, do: [:logger, :he_broker, :cowboy, :bamboo]

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:cowboy,"~> 1.0"},
      {:poison, "~> 2.0"},
      {:he_broker, git: "ssh://git@git.hackerexperience.com/diffusion/BROKER/HEBroker.git"},
      {:remix, "~> 0.0.1", only: :dev},
      {:bamboo, "~> 0.7"}
    ]
  end
end
