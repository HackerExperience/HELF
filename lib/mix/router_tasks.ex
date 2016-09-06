defmodule Mix.Tasks.Router.Start do
  use Mix.Task

  @shortdoc "Starts the router"

  def run(port \\ 8080) do
    {:ok, _} = HELF.Router.start_router port
  end
end
