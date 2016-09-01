defmodule HE.Broker do
  alias HE.Error
  alias HeBroker.Publisher

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
end
