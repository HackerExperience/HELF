defmodule HELF.Router.Topics.TopicRequest do
  @derive [Poison.Encoder]
  defstruct [:topic, :args]
end

defmodule HELF.Router.Topics do
  import Poison.Encoder
  alias HE.Broker

  def route(msg) do
  end

end

