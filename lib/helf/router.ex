defmodule HELF.Router do
  @behavior :cowboy_websocket_handler

  # starts this router
  def start_router(port \\ 8080) do
    routes = [
      {"/ws", __MODULE__, []}
    ]

    dispatch = :cowboy_router.compile([{:_, routes}])
    opts = [port: port]
    env = [dispatch: dispatch]

    {:ok, pid} = :cowboy.start_http(:http, 100, opts, [env: env])
  end

  # ping handle to help with connection tests 
  def websocket_handle({:text, "ping"}, req, state) do
    {:reply, {:text, "pong"}, req, state}
  end

  # generic message handler
  def websocket_handle({:text, message}, req, state) do
  end
end
