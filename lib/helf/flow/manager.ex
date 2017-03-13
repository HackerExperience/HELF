defmodule HELF.Flow.Manager do
  @moduledoc false

  @timeout 300_000

  @typep callback :: (() -> any)

  @typep callback_collection :: [{:success | :fail | :always, callback}]

  require Logger

  @spec start() :: pid
  def start do
    me = self()

    spawn fn ->
      Process.monitor(me)
      loop([])
    end
  end

  @spec loop(callback_collection) :: no_return
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

  @spec handle_cast({:callback, :sucess | :fail | :always, callback}, callback_collection) :: {:noreply, callback_collection}
  @spec handle_cast({:DOWN, term, :process, term, term}, callback_collection) :: {:stop, callback_collection}
  @spec handle_cast(:success | :fail, callback_collection) :: {:stop, callback_collection}
  def handle_cast({:callback, kind, callback}, state) when kind in [:success, :fail, :always],
    do: {:noreply, [{kind, callback}| state]}
  def handle_cast({:DOWN, _, :process, _, _}, state),
    do: handle_cast(:fail, state)
  def handle_cast(:success, state) do
    spawn(fn -> execute_callbacks(:lists.reverse(state), [:success, :always]) end)

    {:stop, state}
  end
  def handle_cast(:fail, state) do
    spawn(fn -> execute_callbacks(:lists.reverse(state), [:fail, :always]) end)

    {:stop, state}
  end
  def handle_cast(msg, state) do
    handle_cast(:fail, state)

    raise "FLOW MANAGER RECEIVED UNEXPECTED MESSAGE: #{inspect msg}"
  end

  @spec execute_callbacks([callback], [:success | :fail | :always]) :: :ok
  defp execute_callbacks(callbacks, acceptable_kinds) do
    Enum.each(callbacks, fn {kind, callback} ->
      try do
        # TODO: Handle potential unending loops (probably by spawning a
        #   process for the callback and waiting a maximum timeout for it to
        #   complete)
        if kind in acceptable_kinds do
          callback.()
        end
      catch
        kind, reason ->
          # Logs the exception as it would be if not caught
          Logger.error(Exception.format(kind, reason, System.stacktrace()))
      end
    end)
  end
end