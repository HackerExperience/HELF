defmodule Mix.Tasks.Router.Start do
  use Mix.Task

  @shortdoc "Starts the router"

  def run(_) do
    Mix.Tasks.App.Start.run([])
    :timer.sleep(:infinity)
  end
end
