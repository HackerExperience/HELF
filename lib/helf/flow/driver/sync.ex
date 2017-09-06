defmodule HELF.Flow.Driver.Sync do

  require Logger

  def execute_success(manager) do
    send manager, :success

    receive do
      {:helf, callbacks} ->
        execute_callbacks(callbacks, [:success, :always])
    end
  end

  def execute_fail(manager) do
    send manager, :fail

    receive do
      {:helf, callbacks} ->
        execute_callbacks(callbacks, [:fail, :always])
    end
  end

  def handle_success({callbacks, client}),
    do: send client, {:helf, :lists.reverse(callbacks)}
  def handle_fail({callbacks, client}),
    do: send client, {:helf, callbacks}

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
