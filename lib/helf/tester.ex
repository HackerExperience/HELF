
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
  """

  defstruct target: nil, types: %{cast: %{}, call: %{}}

  @valid_types [:call, :cast]

  def start_link(target) do
    GenServer.start_link(__MODULE__, target)
  end

  def init(target) do
    {:ok, %__MODULE__{target: target}}
  end

  def listen(pid, :call, service, topic) do
    Broker.subscribe(service, topic, call:
      fn _,_,data,_ ->
        notify(pid, :call, topic, data)
      end)
  end

  def listen(pid, :cast, service, topic) do
    Broker.subscribe(service, topic, cast:
      fn _,_,data ->
        notify(pid, :cast, topic, data)
      end)
  end

  def notify(pid, type, topic, req) do
    case type do
      foo when foo in @valid_types -> GenServer.cast(pid, {:notify, type, topic, req})
      _ -> :error
    end
  end

  def handle_cast({:notify, type, topic, req}, state) do
    with topics <- Map.get(state.types, type),
         topics <- Map.put(topics, topic, req),
         types  <- Map.put(state.types, type, topics),
         state  <- Map.put(state, :types, types) do

      send(state.target, {type, topic})

      {:noreply, state}
    end
  end

  def assert(pid, :call, topic) do
    do_assert(pid, :call, topic, 100)
  end

  def assert(pid, :cast, topic) do
    do_assert(pid, :cast, topic, 100)
  end

  def assert(pid, :call, topic, timeout) do
    do_assert(pid, :call, topic, timeout)
  end

  def assert(pid, :cast, topic, timeout) do
    do_assert(pid, :cast, topic, timeout)
  end

  defp do_assert(pid, type, topic, timeout) do
    GenServer.call(pid, {:assert, type, topic}, timeout)
  end

  def handle_call({:assert, type, topic}, _from, state) do
    topics = Map.get(state.types, type)
    case Map.get(topics, topic) do
      reply when not is_nil(reply) ->
        with {_, topics} <- Map.pop(topics, topic),
             types  <- Map.put(state.types, type, topics),
             state  <- Map.put(state, :types, types),
          do: {:reply, {:ok, reply}, state}
      _ -> {:reply, :error, state}
    end
  end
end
