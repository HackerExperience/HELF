defmodule HELF.App do
  use Application

  alias HELF.Router

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      worker(HeBroker, []),
      worker(Router, [], function: :run)
    ]

    opts = [strategy: :one_for_one, name: HELF.Supervisor]

    {:ok, pid} = Supervisor.start_link(children, opts)
  end
end
