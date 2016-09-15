defmodule HELF.Broker do
  alias HELF.{Error, Broker}
  alias HeBroker.Publisher

  def subscribe(app, route, fun) do
    HeBroker.Consumer.subscribe(app, route, fun)
  end

  def call(topic, args) do
    publisher = Publisher.start_link
    case Publisher.call(publisher, topic, args) do
      {:reply, res} -> res
       :noreply -> {:error, Error.format_reply(:noreply, 500, "Did not get a reply")}
    end
  end

  def cast(topic, args) do
    Publisher.start_link
      |> Publisher.cast(topic, args)
  end

  def broadcast(topic, args) do
    # TODO: use a real HeBroker broadcast function
    Broker.cast(topic, args)
  end
end
