require Logger

defmodule HELF.Router.Request do
  @derive [Poison.Encoder]
  defstruct [:topic, :args]
end

defmodule HELF.Router do
  @moduledoc """
  This module is responsible for websocket request and responses.
  It should propagate messages into the Broker, then reply back with the response.
  """

  alias HELF.Broker
  alias HELF.Router.Request

  @behaviour :cowboy_websocket_handler

  # defines plain topic remaps from request topic to broker topic.
  @plain_remaps %{
    "account.create" => "account:create",
    "account.login" => "account:login"
  }

  @doc ~S"""
    Starts the router, usually called from a supervisor.

    Should return `{:ok, pid}` on normal conditions.
  """

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

  # cowboy callbacks

  # setup cowboy connection type
  def init(_, _req, _opts), do: {:upgrade, :protocol, :cowboy_websocket}

  # setup websocket connection (TODO: check timeout value)
  def websocket_init(_type, req, _opts), do: {:ok, req, %{}, :infinity}

  @doc ~S"""
  Ping request handler, simply answers with pong.

  ## Examples

      iex> HELF.Router.websocket_handle({:text, "ping"}, %{}, %{})
      {:reply, {:text, "pong"}, %{}, %{}}
  """
  def websocket_handle({:text, "ping"}, req, state) do
    {:reply, {:text, "pong"}, req, state}
  end

  @doc ~S"""
  Request handler, deals with JSON message propagation and response.

  ## Examples

      iex> HELF.Router.websocket_handle({:text, "{\"topic\":\"ping\",\"data\":[]}"}, %{}, %{})
      {:reply, {:text, "{\"data\":\"pong\",\"code\":200}"}, %{}, %{}}

      iex> HELF.Router.websocket_handle({:text, "{\"topic\":\"void\",\"data\":[]}"}, %{}, %{})
      {:reply, {:text, "{\"data\":\"Route `void` not found.\",\"code\":404}"}, %{}, %{}}
  """
  def websocket_handle({:text, message}, req, state) do
    res = handle_message(message)
      |> format_reply
      |> Poison.encode!

    {:reply, {:text, res}, req, state}
  end

  @doc ~S"""
  Reply handler, formats elixir messages into cowboy messages.

  # Examples

     iex> HELF.Router.websocket_info("test", %{}, %{})
     {:reply, {:text, "test"}, %{}, %{}}
  """
  def websocket_info(message, req, state) do
    {:reply, {:text, message}, req, state}
  end

  @doc ~S"""
  Termination handler, should perform state cleanup, the connection is closed after this call.

  # Examples

      iex> HELF.Router.websocket_terminate(:ok, %{}, %{})
      :ok
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
  defp route(name, _) do
    {:error, {404, "Route `#{name}` not found."}}
  end
end
