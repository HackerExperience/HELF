defmodule HELF.Event do

  defmacro __using__(args) do
    default_driver = if Mix.env == :test, do: &apply/3, else: &spawn/3
    driver = Keyword.get(args, :driver, default_driver)

    quote do
      import unquote(__MODULE__),
        only: [
          event: 1,
          event: 2,
          event: 3,
          event: 4,
          all_events: 2,
          all_events: 3
        ]

      @driver unquote(driver)

      Module.register_attribute(__MODULE__, :helf_event_events, accumulate: true)
      Module.register_attribute(__MODULE__, :helf_event_events_all, accumulate: true)

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
      events =
        Enum.group_by(
          @helf_event_events,
          &elem(&1, 0),
          fn {_, handler, _opts} -> handler end
        )

      # Removes empty handlers, i.e. events that were declared without a handler
      events = Enum.map(events, fn {event, handlers} ->
        handlers = Enum.reject(handlers, &(&1 == nil))
        {event, handlers}
      end)

      # Now we'll add "catch all" events, i.e. events registered as `all_events`
      # We'll skip the events listed under the `skip` section, if any
      events = Enum.map(events, fn {event, handlers} ->
        all_handlers =
          Enum.reduce(@helf_event_events_all, [], fn {handler, skip}, acc ->
            if Enum.member?(skip, event) do
              acc
            else
              acc ++ [handler]
            end
          end)

        {event, Enum.uniq(handlers ++ all_handlers)}
      end)

      # Note that this is somewhat temporary. In the future we'll probably just
      # define a supervisor structure that defines GenStage workers to execute
      # those in a predefined way, so handle_event will simply send a message to
      # a named genstage worker
      @spec handle_event(struct) :: :ok | :noop
      for {struct_module, handlers} <- events do
        defp handle_event(e = %unquote(struct_module){}) do
          Enum.each(unquote(handlers), fn {module, function} ->
            do_handle(module, function, e)
          end)
        end
      end
      defp handle_event(%_{}),
        do: :noop

      defp do_handle(m, f, event),
        do: unquote(@driver).(m, f, [event])

      @spec size(struct) :: non_neg_integer
      for {struct_module, handlers} <- events do
        def size(%unquote(struct_module){}),
          do: unquote(Enum.count(handlers))
      end
      def size(%_{}),
        do: 0
    end
  end

  defmacro event(event, _opts \\ []) do
    quote do
      event_mod =
        case unquote(event) do
          %mod{} ->
            mod
          mod when is_atom(mod) ->
            mod
        end

      event = {event_mod, nil, []}

      cond do
        not Code.ensure_compiled?(event_mod) ->
          raise """
          invalid module passed as event

          module: #{inspect event_mod}
          """
        not :erlang.function_exported(event_mod, :__struct__, 0) ->
          raise \
            "module #{inspect event_mod} does not define a struct and" <>
            "thus cannot be an event"
        :else ->
          "Alright then"
      end

      Module.put_attribute(__MODULE__,  :helf_event_events, event)
    end
  end
  defmacro event(event, handler_module, handler_function, _opts \\ []) do
    quote do
      event_mod =
        case unquote(event) do
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

  defmacro all_events(handler_module, handler_function, opts \\ []) do
    quote do
      handler_module = unquote(handler_module)
      handler_function = unquote(handler_function)

      skip = Keyword.get(unquote(opts), :skip, [])

      event = {{handler_module, handler_function}, skip}

      cond do
        not Code.ensure_compiled?(handler_module) ->
          raise """
          invalid module passed as event handler

          module: #{inspect handler_module}
          """
        not :erlang.function_exported(handler_module, handler_function, 1) ->
          raise """
          module #{inspect handler_module} does not implement #{inspect handler_function}/1 and thus cannot be an event handler
          """
        :else ->
          "Everything is fine! :)"
      end

      Module.put_attribute(__MODULE__, :helf_event_events_all, event)
    end
  end
end
