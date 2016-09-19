defmodule HELF.Router.Topics do
  use GenServer

  alias HELF.Broker

  def register(topic, action) when is_binary(topic) and (is_binary(action) or is_function(action, 1)) do
    Broker.broadcast("router:register", {topic, action})
  end

  def forward(topic, args) do
    Broker.call("router:forward", {topic, args})
  end

  def start_link() do
    GenServer.start_link(__MODULE__, [])
  end

  def init(_) do
    Broker.subscribe(:helf, "router:register", cast: &handle_register/3)
    Broker.subscribe(:helf, "router:forward", call: &handle_forward/4)
    {:ok, %{}}
  end

  def handle_register(pid, _, {topic, action}) do
    GenServer.cast(pid, {topic, action})
  end

  def handle_forward(pid, _, {topic, args}, timeout) do
    case GenServer.call(pid, {topic, args}, timeout) do
      :ok -> {:reply, :ok}
      msg -> {:reply, msg}
    end
  end

  def handle_cast({topic, action}, state) do
    {:noreply, Map.put(state, topic, action)}
  end

  def handle_call({"ping", _args}, _from, state) do
    {:reply, {:ok, "pong"}, state}
  end

  def handle_call({topic, args}, _from, state) do
    case Map.fetch(state, topic) do
      {:ok, call} when is_function(call) ->
        {:reply, call.(args), state}
      {:ok, remap} when is_binary(remap) ->
        {:reply, Broker.call(remap, args), state}
      _ ->
        {:reply, {:error, {404, "Route not found"}}, state}
    end
  end
end
