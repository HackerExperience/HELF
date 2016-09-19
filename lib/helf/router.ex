defmodule HELF.Router do
  use Supervisor

  alias HELF.Router.{Server, Topics}

  def start_link do
    Supervisor.start_link(__MODULE__, [])
  end

  def register_route(topic, action), do: Topics.register(topic, action)
  
  def init([]) do
    children = [
      worker(Server, [], function: :run),
      worker(Topics, [])
    ]

    supervise(children, strategy: :one_for_one)
  end
end
