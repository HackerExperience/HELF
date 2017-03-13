defmodule HELF.Flow.Manager do
  @moduledoc false

  @timeout 300_000

  @typep callback :: (() -> any)

  @typep t :: %__MODULE__{
    success: [callback],
    fail: [callback],
    always: [callback]
  }

  defstruct [success: [], fail: [], always: []]

  @spec start() :: pid
  def start do
    me = self()

    spawn fn ->
      Process.monitor(me)
      loop(%__MODULE__{})
    end
  end

  @spec loop(t) :: no_return
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

  @spec handle_cast({:callback, :sucess | :fail | :always, callback}, t) :: {:noreply, t}
  @spec handle_cast({:DOWN, term, :process, term, term}, t) :: {:stop, t}
  @spec handle_cast(:success | :fail, t) :: {:stop, t}
  def handle_cast({:callback, :success, callback}, state = %{success: success}),
    do: {:noreply, %{state| success: [callback| success]}}
  def handle_cast({:callback, :fail, callback}, state = %{fail: fail}),
    do: {:noreply, %{state| fail: [callback| fail]}}
  def handle_cast({:callback, :always, callback}, state = %{always: always}),
    do: {:noreply, %{state| always: [callback| always]}}
  def handle_cast({:DOWN, _, :process, _, _}, state),
    do: handle_cast(:fail, state)
  def handle_cast(:success, state) do
    spawn fn ->
      state.success
      |> :lists.reverse()
      |> Enum.each(fn callback -> callback.() end)
    end

    spawn fn ->
      state.always
      |> :lists.reverse()
      |> Enum.each(fn callback -> callback.() end)
    end

    {:stop, state}
  end
  def handle_cast(:fail, state) do
    spawn fn ->
      state.fail
      |> :lists.reverse()
      |> Enum.each(fn callback -> callback.() end)
    end

    spawn fn ->
      state.always
      |> :lists.reverse()
      |> Enum.each(fn callback -> callback.() end)
    end

    {:stop, state}
  end
  def handle_cast(msg, state) do
    handle_cast(:fail, state)

    raise "FLOW MANAGER RECEIVED UNEXPECTED MESSAGE: #{inspect msg}"
  end
end