defmodule HELF.Broker do
  use Supervisor

  alias HELF.Error
  alias HeBroker.Publisher

  @doc ~S"""
    Starts `HELF.Broker` using the default backend.
  """
  def start_link, do: Supervisor.start_link(__MODULE__, [:he_broker, []])

  @doc ~S"""
    Starts `HELF.Broker` using given backend.
  """
  def start_link(backend, args \\ []) do
    Supervisor.start_link(__MODULE__, [backend, args])
  end

  @doc ~S"""
    Allows `HELF.Broker` to boot on default mode.
  """
  def init([:he_broker, args]), do: do_init(worker(HeBroker, args))

  # Starts supervising the backend
  defp do_init(backend) do
    supervise([backend], strategy: :one_for_one)
  end

  @doc ~S"""
    Subscribes to given route.
  """
  def subscribe(app, route, fun) do
    HeBroker.Consumer.subscribe(app, route, fun)
  end

  @doc ~S"""
    Sends a synchronous message to given route.
  """
  def call(topic, args) do
    publisher = Publisher.start_link
    case Publisher.call(publisher, topic, args) do
      {:reply, res} -> res
       :noreply -> {:error, Error.format_reply(:noreply, 500, "Did not get a reply")}
    end
  end

  @doc ~S"""
    Sends an asynchronous message to given route.
  """
  def cast(topic, args) do
    Publisher.start_link
      |> Publisher.cast(topic, args)
  end

  @doc ~S"""
    Sends an asynchronous message to all listeners of given route.
  """
  def broadcast(topic, args) do
    # TODO: use a real HeBroker broadcast function
    HELF.Broker.cast(topic, args)
  end
end
