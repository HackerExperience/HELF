defmodule HELF.Router.Request do
  @derive [Poison.Encoder]
  defstruct [:topic, :args, :request_id, debug: false]
end
