defmodule HELF.Tester.CheckError do
  defexception message: "No given reason."
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
        end
      end)

    Tester.broker_cast(pid, "event:name", "a") # -> should pass
    Tester.broker_cast(pid, "event:name", "b") # -> should fail and crash the server

  Things TODO: Check if there is better ways to crash the server
  """

  alias HELF.Tester
  alias HELF.Broker

  defstruct(name: nil)

  @doc ~S"""
  """
  def register(pid, topic, call: checker) do
    GenServer.call(pid, {:add_call, topic, checker})
  end

  @doc ~S"""
  """
  def register(pid, topic, cast: checker) do
    GenServer.call(pid, {:add_cast, topic, checker})
  end

  @doc ~S"""
  """
  def broker_call(pid, topic, args, timeout \\ 5000) do
    GenServer.cast(pid, {:broker_call, topic, args, timeout})
  end

  @doc ~S"""
  """
  def broker_cast(pid, topic, args) do
    GenServer.cast(pid, {:broker_cast, topic, args})
  end

  # Checks
  defp check(checker, args, state) do
    case checker.(args) do
      :ok -> :ok
      :error ->
        raise(Tester.CheckError,
          message: "Tester '#{state.name}' failed with no explicit reason.")
      {:error, msg} ->
        raise(Tester.CheckError,
          message: "Tester '#{state.name}' failed:\n  #{msg}")
    end
  end

  # callbacks

  @doc ~S"""
  """
  def start_link(name) do
    GenServer.start_link(__MODULE__, name)
  end

  @doc ~S"""
  """
  def init(name) do
    {:ok, %__MODULE__{name: name}}
  end

  @doc ~S"""
  """
  def handle_call({:add_call, topic, checker}, _from, state) do
    Broker.subscribe(state.name, topic, call:
      fn pid,_,args,timeout ->
        check(checker, args, state)
      end)

    {:reply, :ok, state}
  end

  @doc ~S"""
  """
  def handle_call({:add_cast, topic, checker}, _from, state) do
    Broker.subscribe(state.name, topic, cast:
      fn pid,_,args ->
        check(checker, args, state)
      end)

    {:reply, :ok, state}
  end

  @doc ~S"""
  """
  def handle_cast({:broker_call, topic, args, timeout}, state) do
    Task.async(fn -> Broker.call(topic, args, timeout) end)
    {:noreply, state}
  end

  @doc ~S"""
  """
  def handle_cast({:broker_cast, topic, args}, state) do
    Broker.cast(topic, args)
    {:noreply, state}
  end
end
