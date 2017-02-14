defmodule HELF.Router.Topics do
  use GenServer

  alias HELF.Broker

  def register(topic, action)
  when is_binary(topic) and (is_binary(action) or is_function(action, 1))
  do
    Broker.cast("router:register", {topic, action})
  end

  def forward(topic, args) do
    case Broker.call("router:forward", {topic, args}) do
      {_, {:call, {topic, message}}} ->
        Broker.call(topic, message)
      {_, return} ->
        return
    end
  end

  def start_link() do
    GenServer.start_link(__MODULE__, [])
  end

  def init(_) do
    Broker.subscribe("router:register", cast: &handle_register/4)
    Broker.subscribe("router:forward", call: &handle_forward/4)
    {:ok, %{}}
  end

  @doc false
  def handle_register(pid, _topic, {topic, action}, _request) do
    GenServer.cast(pid, {topic, action})
  end

  @doc false
  def handle_forward(pid, _topic, {topic, args}, _request) do
    msg = GenServer.call(pid, {topic, args})

    {:reply, msg}
  end

  @doc false
  def handle_cast({topic, action}, state) do
    {:noreply, Map.put(state, topic, action)}
  end

  @doc false
  def handle_call({"ping", _args}, _from, state) do
    {:reply, {:ok, "pong"}, state}
  end

  def handle_call({topic, args}, _from, state) do
    case Map.fetch(state, topic) do
      {:ok, call} when is_function(call) ->
        {:reply, call.(args), state}
      {:ok, remap} when is_binary(remap) ->
        {:reply, {:call, {remap, args}}, state}
      _ ->
        {:reply, {:error, {404, "Route not found"}}, state}
    end
  end
end
