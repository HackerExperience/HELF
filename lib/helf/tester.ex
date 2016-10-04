
defmodule HELF.Tester do
  use GenServer

  alias HELF.Broker

  @moduledoc """
  Experimental HELF Tester module.
  It's currently not stable, but the API might not change that much.

  Example Usage:

      # starts the tester genserver
      {:ok, pid} = Tester.start_link(self())

      # listen to this route
      Tester.listen(pid, :cast, :test_service, "event:account:created")

      # payload for account creation
      account = %{
        email: "exampl@test.com",
        password: "12345678",
        password_confirmation: "12345678"
      }

      # call a broker route you know that should ping the route we just listened
      Broker.call("account:create", account)

      # assert that the route was called
      assert_receive {:cast, "event:account:created"}

      # get the state while asserting that the message arrived
      {:ok, params} = Tester.assert(pid, :cast, "event:account:created")

      # make assertions with the parameters
      assert is_binary(params)

  This example is not the best use case since we used Broker.call, but it shows
  how to listen to cast routes.

  TODO: add unsubscribe
  """

  # state format
  defstruct id: nil, target: nil, types: %{cast: %{}, call: %{}}

  # valid types
  @valid_types [:call, :cast]

  @doc ~S"""
  Starts the Tester server.
  """
  def start_link(id, target) do
    GenServer.start_link(__MODULE__, [id, target])
  end

  @doc ~S"""
  Initializes the Tester state.
  """
  def init([id, target]) do
    {:ok, %__MODULE__{id: id, target: target}}
  end

  @doc ~S"""
  Adds a listener to any Broker.call that targets given topic.
  """
  def listen(pid, :call, service, topic) do
    Broker.subscribe(service, topic, call:
      fn _,_,data,_ ->
        notify(pid, :call, topic, data)
      end)
  end

  @doc ~S"""
  Adds a listener to any Broker.cast that targets given topic.
  """
  def listen(pid, :cast, service, topic) do
    Broker.subscribe(service, topic, cast:
      fn _,_,data ->
        notify(pid, :cast, topic, data)
      end)
  end

  @doc ~S"""
  Called from Broker to notify the Tester.
  """
  def notify(pid, type, topic, req) do
    case type do
      foo when foo in @valid_types -> GenServer.cast(pid, {:notify, type, topic, req})
      _ -> :error
    end
  end

  @doc ~S"""
  Handles notifications, sends a message to the father process with the type and topic
  of the notification.
  """
  def handle_cast({:notify, type, topic, req}, state) do
    with topics <- Map.get(state.types, type),
         topics <- Map.put(topics, topic, req),
         types  <- Map.put(state.types, type, topics),
         state  <- Map.put(state, :types, types) do

      send(state.target, {type, state.id, topic})

      {:noreply, state}
    end
  end

  @doc ~S"""
  Checks if a Broker.call was received, returns a tuple holding `:ok` or `:error`, and the data.
  Timeout defaults to 100.
  """
  def assert(pid, :call, topic) do
    assert(pid, :call, topic, 100)
  end

  @doc ~S"""
  Checks if a Broker.cast was received, returns a tuple holding `:ok` or `:error`, and the data.
  Timeout defaults to 100.
  """
  def assert(pid, :cast, topic) do
    assert(pid, :cast, topic, 100)
  end

  @doc ~S"""
  Checks if a Broker.cast was received, returns a tuple holding `:ok` or `:error`, and the data.
  Also accepts a timeout parameter.
  """
  def assert(pid, :call, topic, timeout) do
    GenServer.call(pid, {:assert, :call, topic}, timeout)
  end

  @doc ~S"""
  Checks if a Broker.cast was received, returns a tuple holding `:ok` or `:error`, and the data.
  Also accepts a timeout parameter.
  """
  def assert(pid, :cast, topic, timeout) do
    GenServer.call(pid, {:assert, :cast, topic}, timeout)
  end

  @doc ~S"""
  Tries to find data from given type and topic, returns {:ok, data} when the data is
  found, and :error when not.
  """
  def handle_call({:assert, type, topic}, _from, state) do
    topics = Map.get(state.types, type)
    case Map.get(topics, topic) do
      reply when not is_nil(reply) ->
        with {_, topics} <- Map.pop(topics, topic),
             types       <- Map.put(state.types, type, topics),
             state       <- Map.put(state, :types, types),
          do: {:reply, {:ok, reply}, state}
      _ -> {:reply, :error, state}
    end
  end
end
