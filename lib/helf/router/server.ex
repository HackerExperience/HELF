
defmodule HELF.Router.Request do
  @derive [Poison.Encoder]
  defstruct [:topic, :args]
end

defmodule HELF.Router.Server do
  @moduledoc """
  This module is responsible for websocket request and responses.
  It should propagate messages into the Broker, then reply back with the response.
  """

  require Logger

  alias HELF.Router.{Request, Topics}

  @behaviour :cowboy_websocket_handler

  @doc """
  Starts the router, usually called from a supervisor.
  Should return `{:ok, pid}` on normal conditions.
  """
  def run(port) do
    Logger.info "Router is listening at #{port}."

    routes = [
      {"/ws", __MODULE__, []}
    ]

    dispatch = :cowboy_router.compile([{:_, routes}])
    opts = [port: port]
    env = [dispatch: dispatch]

    {:ok, _} = :cowboy.start_http(:http, 100, opts, [env: env])
  end

  # cowboy callbacks

  # setup cowboy connection type
  @doc """
  Upgrades the protocol to websocket.
  """
  def init(_, _req, _opts), do: {:upgrade, :protocol, :cowboy_websocket}

  # setup websocket connection
  @doc """
  Negotiates the protocol with the client, also sets the connection timeout.
  """
  def websocket_init(_type, req, _opts), do: {:ok, req, %{}, :infinity}

  @doc """
  Ping request handler, replies with pong.
  """
  def websocket_handle({:text, "ping"}, req, state) do
    {:reply, {:text, "pong"}, req, state}
  end

  @doc """
  Request handler, deals with JSON message propagation and response.
  """
  def websocket_handle({:text, message}, req, state) do
    res = handle_message(message)
      |> format_reply
      |> Poison.encode!

    {:reply, {:text, res}, req, state}
  end

  @doc """
  Reply handler, formats elixir messages into cowboy messages.
  """
  def websocket_info(message, req, state) do
    {:reply, {:text, message}, req, state}
  end

  @doc """
  Termination handler, should perform state cleanup, the connection is closed
  after this call.
  """
  def websocket_terminate(_reason, _req, _state) do
    :ok # TODO: match termination reason
  end

  # private functions

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
      {:ok, %{topic: topic, args: args}} when not is_binary(topic) or is_nil(args) ->
        {:error, {400, "Invalid request"}}
      {:ok, %{topic: topic, args: args}} ->
        {_, result} = Topics.forward(topic, args)
        result
      :decode_error ->
        {:error, {400, "One of your arguments is invalid"}}
      _ ->
        {:error, {400, "Invalid JSON"}}
    end
  end
end