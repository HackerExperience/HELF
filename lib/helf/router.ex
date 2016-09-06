require Logger

defmodule HELF.Router do
  @behaviour :cowboy_websocket_handler

  alias HELF.Router.Topics

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
    res = route(message)
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

  defp route(msg) do
    case Poison.decode(msg, as: %Topics.Request{}) do
      {:ok, %{topic: topic, args: args}} ->
        Topics.handle_route(topic, args)
      _ ->
        {:error, {400, "SyntaxError"}}
    end
  end

  defp format_reply(reply) do
    case reply do
      {:ok, res} ->
        %{code: 200, data: res}
      {:error, {code, msg}} ->
        %{code: code, data: msg}
    end
  end
end
