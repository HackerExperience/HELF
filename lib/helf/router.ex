require Logger

defmodule HELF.Router.Request do
  @derive [Poison.Encoder]
  defstruct [:topic, :args]
end

defmodule HELF.Router do
  alias HELF.Broker
  alias HELF.Router.Request

  @behaviour :cowboy_websocket_handler

  # plain remapping
  @plain_remaps %{
    "account.create" => "account:create",
    "account.login" => "account:login"
  }

  # starts this router
  def run(port \\ 8080) do
    Logger.info "Router is listening at #{port}."

    routes = [
      {"/ws", __MODULE__, []}
    ]

    dispatch = :cowboy_router.compile([{:_, routes}])
    opts = [port: port]
    env = [dispatch: dispatch]

    {:ok, _} = :cowboy.start_http(:http, 100, opts, [env: env])
  end

  # setup cowboy connection type
  def init(_, _req, _opts), do: {:upgrade, :protocol, :cowboy_websocket}

  # setup websocket connection (TODO: check timeout value)
  def websocket_init(_type, req, _opts), do: {:ok, req, %{}, :infinity}

  # ping message handler, always reply with pong
  def websocket_handle({:text, "ping"}, req, state) do
    {:reply, {:text, "pong"}, req, state}
  end

  # json message handler
  def websocket_handle({:text, message}, req, state) do
    res = handle_message(message)
      |> format_reply
      |> Poison.encode!

    {:reply, {:text, res}, req, state}
  end

  # format and forward elixir messages
  def websocket_info(message, req, state) do
    {:reply, {:text, message}, req, state}
  end

  # termination callback
  def websocket_terminate(_reason, _req, _state) do
    :ok # TODO: match termination reason
  end

  # formats the response before serializing
  defp format_reply(reply) do
    case reply do
      {:ok, res} ->
        %{code: 200, data: res}
      {:error, {code, msg}} ->
        %{code: code, data: msg}
    end
  end

  # decodes the message and forward to the topic route handler
  defp handle_message(msg) do
    case Poison.decode(msg, as: %Request{}) do
      {:ok, %{topic: topic, args: args}} ->
        handle_route(topic, args)
      _ ->
        {:error, {400, "SyntaxError"}}
    end
  end

  # try to remap the topic, fallbacks to `do_route`
  defp handle_route(topic, args) do
    case Map.get(@plain_remaps, topic) do
      nil ->
        route(topic, args)
      remap ->
        Broker.call(remap, args)
    end
  end

  # simple ping route using json
  defp route("ping", _) do
    {:ok, "pong"}
  end

  # add composed routes here:


  # route not found
  defp route(name, _) do
    {:error, {404, "Route `#{name}` not found."}}
  end
end
