defmodule HELF.Tester.CheckError do
  defexception message: ""
end

defmodule HELF.Tester do
  use GenServer

  @moduledoc """
  This is an experimental server for testing the broker.
  It is not stable and may change dramatically.

  Example Usage:

    alias HELF.Tester
    {:ok, pid} = Tester.start_link(:tester_test)

    Tester.register(pid, "event:name", cast:
      fn msg when is_binary(msg) ->
        case msg do
          "a" -> :ok
          _ -> {:error, "Expected \"a\"."}
        enmod
      end)

    Tester.broker_cast(pid, "event:name", "a") # -> should pass
    Tester.broker_cast(pid, "event:name", "b") # -> should fail and crash the server

    Things TODO:
        * Check if there is better ways to crash the server
        * Check how to integrate with ExUnit, a good read is https://goo.gl/JwAck2
  """

  alias HELF.Tester
  alias HELF.Broker

  defstruct(name: nil)

  @doc ~S"""
  Registers a call checker.
  """
  def register(pid, topic, call: checker) do
    GenServer.call(pid, {:add_call, topic, checker})
  end

  @doc ~S"""
  Registers a cast checker
  """
  def register(pid, topic, cast: checker) do
    GenServer.call(pid, {:add_cast, topic, checker})
  end

  @doc ~S"""
  Makes a broker call from the Tester process.
  """
  def broker_call(pid, topic, args, timeout \\ 5000) do
    GenServer.cast(pid, {:broker_call, topic, args, timeout})
  end

  @doc ~S"""
  Makes a broker cast from the Tester process.
  """
  def broker_cast(pid, topic, args) do
    GenServer.cast(pid, {:broker_cast, topic, args})
  end

  # Calls the checker, throws an error with tester name and topic
  defp check(checker, args, topic, state) do
    case checker.(args) do
      :ok -> :ok
      :error ->
        raise(Tester.CheckError,
          message: "Tester '#{state.name}/#{topic}' failed with no explicit reason.")
      {:error, msg} ->
        raise(Tester.CheckError,
          message: "Tester '#{state.name}/#{topic}' failed:\n  #{msg}")
    end
  end

  @doc ~S"""
  Starts the server, takes a name parameter.
  """
  def start_link(name) do
    GenServer.start_link(__MODULE__, name)
  end

  @doc ~S"""
  Stops the server.
  """
  def stop(pid, reason, timeout \\ 5000) do
    GenServer.stop(pid, reason, timeout)
  end

  @doc ~S"""
  Initializes the server with a name parameter.
  """
  def init(name) do
    {:ok, %__MODULE__{name: name}}
  end

  @doc ~S"""
  Adds a call checker to the state.
  """
  def handle_call({:add_call, topic, checker}, _from, state) do
    Broker.subscribe(state.name, topic, call:
      fn _,_,args,_ ->
        check(checker, args, topic,  state)
      end)

    {:reply, :ok, state}
  end

  @doc ~S"""
  Adds a cast checker to the state.
  """
  def handle_call({:add_cast, topic, checker}, _from, state) do
    Broker.subscribe(state.name, topic, cast:
      fn _,_,args ->
        check(checker, args, topic, state)
      end)

    {:reply, :ok, state}
  end

  @doc ~S"""
  Makes an async Broker call.
  """
  def handle_cast({:broker_call, topic, args, timeout}, state) do
    Broker.call(topic, args, timeout)
    {:noreply, state}
  end

  @doc ~S"""
  Makes a Broker cast.
  """
  def handle_cast({:broker_cast, topic, args}, state) do
    Broker.cast(topic, args)
    {:noreply, state}
  end
end
