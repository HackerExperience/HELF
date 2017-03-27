defmodule HELF.Event do

  defmacro __using__(_args) do
    quote do
      import unquote(__MODULE__), only: [event: 3, event: 4]

      Module.register_attribute(__MODULE__, :helf_event_events, accumulate: true)

      @before_compile unquote(__MODULE__)

      @spec emit(struct) :: :ok | :noop
      def emit(event = %_{}),
        do: handle_event(event)
    end
  end

  defmacro __before_compile__(_env) do
    quote unquote: false do
      # Group events by the struct module so we can execute all handlers when an
      # event struct is emited
      events = Enum.group_by(
        @helf_event_events,
        &elem(&1, 0),
        fn {_, handler, _opts} -> handler end)

      # Note that this is somewhat temporary. In the future we'll probably just
      # define a supervisor structure that defines GenStage workers to execute
      # those in a predefined way, so handle_event will simply send a message to
      # a named genstage worker
      @spec handle_event(struct) :: :ok | :noop
      for {struct_module, handlers} <- events do
        defp handle_event(e = %unquote(struct_module){}) do
          Enum.each(unquote(handlers), fn {module, function} ->
            spawn(module, function, [e])
          end)

          :ok
        end
      end
      defp handle_event(%_{}),
        do: :noop

      @spec size(struct) :: non_neg_integer
      for {struct_module, handlers} <- events do
        def size(%unquote(struct_module){}),
          do: unquote(Enum.count(handlers))
      end
      def size(%_{}),
        do: 0
    end
  end

  defmacro event(event, handler_module, handler_function, _opts \\ []) do
    quote do
      event_mod = case unquote(event) do
        %mod{} ->
          mod
        mod when is_atom(mod) ->
          mod
      end
      handler_module = unquote(handler_module)
      handler_function = unquote(handler_function)
      event = {event_mod, {handler_module, handler_function}, []}

      cond do
        not Code.ensure_compiled?(event_mod) ->
          raise """
          invalid module passed as event

          module: #{inspect event_mod}
          """
        not :erlang.function_exported(event_mod, :__struct__, 0) ->
          raise "module #{inspect event_mod} does not define a struct and thus cannot be an event"
        not Code.ensure_compiled?(handler_module) ->
          raise """
          invalid module passed as event handler

          module: #{inspect handler_module}
          event: #{inspect event_mod}
          """
        not :erlang.function_exported(handler_module, handler_function, 1) ->
          raise """
          module #{inspect handler_module} does not implement #{inspect handler_function}/1 and thus cannot be an event handler
          """
        :else ->
          "Everything is fine! :)"
      end

      Module.put_attribute(__MODULE__, :helf_event_events, event)
    end
  end
end