defmodule HELF.Router do
  use Supervisor

  alias HELF.Router.{Server, Topics}

  def start_link do
    Supervisor.start_link(__MODULE__, [])
  end

  def init([]) do
    children = [
      worker(Server, [], function: :run),
      worker(Topics, [])
    ]

    supervise(children, strategy: :one_for_one)
  end
end
