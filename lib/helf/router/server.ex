defmodule HELF.Router.Server do
  @moduledoc """
  This module is responsible for websocket request and responses.
  It should propagate messages into the Broker, then reply back with the response.
  """

  @behaviour :cowboy_websocket_handler

  alias HELF.Router.{Request, Topics}

  require Logger

  @doc """
  Starts the router, usually called from a supervisor.
  Should return `{:ok, pid}` on normal conditions.
  """
  def run(port) do
    Logger.info "Router is listening at #{port}."

    routes = [
      {"/", __MODULE__, []}
    ]

    dispatch = :cowboy_router.compile([{:_, routes}])
    opts = [port: port]
    env = [dispatch: dispatch]

    {:ok, _} = :cowboy.start_http(:http, 100, opts, [env: env])
  end

  @doc """
  Upgrades the protocol to websocket.
  """
  def init(_, _req, _opts),
    do: {:upgrade, :protocol, :cowboy_websocket}

  @doc """
  Setup websocket connection
  """
  def websocket_init(_type, req, _opts),
    do: {:ok, req, %{}, :infinity}

  @doc """
  Handle ping messages
  """
  def websocket_handle({:text, "ping"}, req, state),
    do: {:reply, {:text, "pong"}, req, state}

  @doc false
  def websocket_handle({:text, message}, req, state) do
    request = decode_message(message)

    return = case request do
      {:ok, request} ->
        {_, result} = Topics.forward(request.topic, request.args)

        result
        |> format_reply()
        |> add_metadata(request)
      {:error, error} ->
        format_reply({:error, error})
    end

    reply = Poison.encode!(return)

    {:reply, {:text, reply}, req, state}
  end

  @doc false
  def websocket_info(message, req, state) do
    {:reply, {:text, message}, req, state}
  end

  @doc false
  def websocket_terminate(_reason, _req, _state),
    do: :ok

  # Add metadata (if any) to the request
  defp add_metadata(reply, payload) do
    maybe_add_request_id = fn (m) ->
      case payload.request_id do
        nil -> m
        request_id -> Map.put(m, :request_id, request_id)
      end
    end

    maybe_add_debug = fn (m) ->
      case payload.debug do
        true -> Map.put(m, :debug, true)
        _ -> m
      end
    end

    reply
    |> maybe_add_request_id.()
    |> maybe_add_debug.()
  end

  # Make the internal response match the router's reply format
  # TODO: Implement Viewables (or something like that; see T424)
  defp format_reply(reply) do
    case reply do
      {:ok, res} ->
        %{code: 200, data: res}
      {:error, {code, msg}} ->
        %{code: code, data: msg}
      {:error, error} ->
        {code, msg} = case error do
          :bad_request ->
            {400, "Bad request"}
          :invalid_atom ->
            {400, "One of your arguments is invalid"}
          :decode_error ->
            {400, "Invalid JSON"}
          :notfound ->
            {404, "Not found"}
          _ ->
            {400, "Unknown error"}
        end
        %{code: code, data: msg}
    end
  end

  # Decode the received JSON (unsafe) into a map
  defp decode_message(msg) do

    # We decode the unsafe JSON to atoms!, which means that if the atom we
    # are decoding does not exist, it will raise an ArgumentError. That's
    # to avoid a potential DoS with Erlang's limited atom count. The allowed
    # atoms are defined when a Route is registered.
    decode = try do
      Poison.decode(msg, as: %Request{}, keys: :atoms!)
    rescue
      ArgumentError ->
        :invalid_atom
    end

    case decode do
      {:ok, request = %{topic: topic, args: args}} when is_binary(topic) and not is_nil(args) ->
        {:ok, request}
      {:ok, _request} ->
        {:error, :bad_request}
      :invalid_atom ->
        {:error, :invalid_atom}
      _ ->
        {:error, :decode_error}
    end
  end

  defp default_internal_error(),
    do: %{code: 500, data: %{}}

end
