defmodule HELF.Router do

  use Supervisor

  require Logger

  alias HELF.Router

  @doc """
  Starts `HELF.Router` using the default backend.
  """
  def start_link do
    port = do_get_port
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
  def init([:cowboy, port]), do: do_init(worker(Router.Server, [port], function: :run))

  # Starts both backend and topic registering service.
  defp do_init(backend) do
    children = [
      backend,
      worker(Router.Topics, [])
    ]

    supervise(children, strategy: :one_for_one)
  end

  # Tries to get the port without breaking compatibility with HELF 2
  defp do_get_port do
    case Application.fetch_env(:helf, :port) do
      {:ok, port} ->
        Logger.warn "Invalid :helf configuration, :port is deprecated, change to :router_port."
        port
      :error -> Application.fetch_env!(:helf, :router_port)
    end
  end

  @doc """
  Forwards params to `Router.Topics.register`.
  """
  def register(topic, action), do: Router.Topics.register(topic, action)
end