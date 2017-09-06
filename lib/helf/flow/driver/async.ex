defmodule HELF.Flow.Driver.Async do

  require Logger

  def execute_success(manager),
    do: send manager, :success
  def execute_fail(manager),
    do: send manager, :fail

  def handle_success({callbacks, _}),
    do: execute_callbacks(:lists.reverse(callbacks), [:success, :always])
  def handle_fail({callbacks, _}),
    do: execute_callbacks(callbacks, [:fail, :always])

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
