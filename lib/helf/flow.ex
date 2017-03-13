defmodule HELF.Flow do

  defmacro flowing(do: {:with, meta, args}) do
    args = Enum.map(args, fn
      blocks = [_|_] ->
        blocks = Enum.map(blocks, fn
          # If the `with` succeeds, execute the success routine
          {:do, code} ->
            inject = quote do: (Flow.__execute_success__(); unquote(code))

            {:do, inject}

          # If the `with` fails, execute the failure routine, no matter which
          # error clauses it matches
          {:else, clauses} ->
            clauses = Enum.map(clauses, fn {:->, meta, [pattern, code]} ->
              inject = quote do: (Flow.__execute_fail__(); unquote(code))

              {:->, meta, [pattern, inject]}
            end)

            {:else, clauses}

          etc ->
            etc
        end)

        # If the `with` didn't include any `else` clause, we'll inject a default
        # one that has the very same behaviour as the lack of any `else` clause
        # (ie: return the value) but with the addition of executing the failure
        # routine
        on_fail = quote do: Flow.__execute_fail__()

        # AST to bind on any potential value, execute on_fail and return the bound value
        inject = [{:->, [], [[{:error, [], Elixir}], {:__block__, [], [on_fail, {:error, [], Elixir}]}]}]

        Keyword.put_new(blocks, :else, inject)

      etc ->
        etc
    end)

    command = {:with, meta, args}

    quote do
      Flow.__start__()
      return = unquote(command)
      Flow.__finish__()

      return
    end
  end

  @spec on_success((() -> any)) :: :ok
  @doc """
  Stores a callback to be executed if the `with` succeeds

  Eg:
  ```
  flowing do
    with \
      on_fail(fn -> IO.puts "Operation failed" end),
      {:ok, value} <- Map.fetch(%{a: 1}, :a),
      on_success(fn -> IO.puts "Succeeded and got \#{inspect value}" end)
    do
      :gotcha
    end
  end
  ```
  """
  def on_success(callback),
    do: callback(callback, :success)

  @doc """
  Stores a callback to be executed if the `with` fails

  Eg:
  ```
  flowing do
    with \
      on_fail(fn -> IO.puts "Operation failed" end),
      {:ok, value} <- Map.fetch(%{a: 1}, :b),
      on_success(fn -> IO.puts "Succeeded and got \#{inspect value}" end)
    do
      :gotcha
    end
  end
  ```
  """
  @spec on_fail((() -> any)) :: :ok
  def on_fail(callback),
    do: callback(callback, :fail)

  @spec on_done((() -> any)) :: :ok
  @doc """
  Stores a callback to be executed at the end of the `with`, no matter if it succeeds or fails

  Eg:
  ```
  flowing do
    with \
      on_done(fn -> IO.puts "The flow is completed" end),
      {:ok, value} <- Map.fetch(%{a: 1}, :a)
    do
      flowing do
        with \
          on_done(fn -> IO.puts "The other flow is completed" end),
          {:ok, value} <- Map.fetch(%{a: 1}, :b)
        do
          :gotcha
        end
      end
    end
  end
  ```
  """
  def on_done(callback),
    do: callback(callback, :always)

  @spec callback((() -> any), :success | :fail | :always) :: :ok
  defp callback(callback, kind) when is_function(callback, 0) and kind in [:success, :fail, :always] do
    case get_flow() do
      nil ->
        raise "cannot set callback outside of flow"
      {flow, _counter} ->
        send flow, {:callback, kind, callback}
    end
  end

  @doc false
  def __start__ do
    case get_flow() do
      nil ->
        pid = HELF.Flow.Manager.start()
        Process.put(:heflow, {pid, 1})
      {flow, counter} ->
        Process.put(:heflow, {flow, counter + 1})
    end
  end

  @doc false
  def __finish__ do
    case get_flow() do
      {_, 1} ->
        Process.delete(:heflow)
      {flow, n} ->
        Process.put(:heflow, {flow, n - 1})
      nil ->
        :ok
    end
  end

  @doc false
  def __execute_success__ do
    case get_flow() do
      {flow, 1} ->
        send flow, :success
        Process.delete(:heflow)
      _ ->
        :ok
    end
  end

  @doc false
  def __execute_fail__ do
    case get_flow() do
      {flow, 1} ->
        send flow, :fail
        Process.delete(:heflow)
      _ ->
        :ok
    end
  end

  @spec get_flow() :: {pid, pos_integer} | nil
  defp get_flow do
    Process.get(:heflow)
  end
end