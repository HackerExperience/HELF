defmodule HELF.Router do

  use Supervisor

  alias HELF.Router

  require Logger

  @doc """
  Starts `HELF.Router` using the default backend.
  """
  def start_link do
    port = get_port()
    Supervisor.start_link(__MODULE__, [:cowboy, port])
  end

  @doc """
  Starts `HELF.Router` using the default backend on given port.
  """
  def start_link(port) when is_integer(port) do
    Supervisor.start_link(__MODULE__, [:cowboy, port])
  end

  @doc """
  Starts `HELF.Router` using given backend.
  """
  def start_link(backend, args \\ []) when is_atom(backend) do
    Supervisor.start_link(__MODULE__, [backend, args])
  end

  @doc """
  Starts `HELF.Router` using the default backend.
  """
  def init([:cowboy, port]),
    do: do_init(worker(Router.Server, [port], function: :run))

  # Starts both backend and topic registering service.
  defp do_init(backend) do
    children = [
      backend,
      worker(Router.Topics, [])
    ]

    supervise(children, strategy: :one_for_one)
  end

  defp get_port(),
    do: Application.fetch_env!(:helf, :router_port)

  @doc """
  Forwards params to `Router.Topics.register`.
  """
  def register(topic, action, _atoms \\ []),
    do: Router.Topics.register(topic, action)
end
