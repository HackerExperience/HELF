defmodule HELF.Flow.Manager do
  @moduledoc false

  alias HELF.Flow

  @timeout 300_000

  @typep callback :: (() -> any)

  @typep callback_collection :: [{:success | :fail | :always, callback}]
  @typep state :: {callback_collection, pid}

  @spec start() :: pid
  def start do
    me = self()

    spawn fn ->
      Process.monitor(me)
      loop({[], me})
    end
  end

  @spec loop(state) :: no_return
  def loop(state) do
    receive do
      message ->
        case handle_cast(message, state) do
          {:noreply, state} ->
            loop(state)
          {:stop, _} ->
            :ok
        end
    after
      @timeout ->
        handle_cast(:fail, state)
        raise "FLOW MANAGER TIMEOUT AFTER #{div(@timeout, 1_000)} SECONDS"
    end
  end

  @spec handle_cast({:callback, :sucess | :fail | :always, callback}, state) :: {:noreply, state}
  @spec handle_cast({:DOWN, term, :process, term, term}, state) :: {:stop, state}
  @spec handle_cast(:success | :fail, state) :: {:stop, state}
  def handle_cast({:callback, kind, callback}, state) when kind in [:success, :fail, :always],
    do: {:noreply, accumulate_callback({kind, callback}, state)}
  def handle_cast({:DOWN, _, :process, _, _}, state),
    do: handle_cast(:fail, state)
  def handle_cast(:success, state) do
    Flow.__driver__.handle_success(state)

    {:stop, state}
  end
  def handle_cast(:fail, state) do
    Flow.__driver__.handle_fail(state)

    {:stop, state}
  end
  def handle_cast(msg, state) do
    handle_cast(:fail, state)

    raise "FLOW MANAGER RECEIVED UNEXPECTED MESSAGE: #{inspect msg}"
  end

  defp accumulate_callback({kind, callback}, {callbacks, process}),
    do: {[{kind, callback}| callbacks], process}
end
