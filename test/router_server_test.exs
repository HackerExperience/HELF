defmodule HELF.Router.ServerTest do
  use ExUnit.Case

  alias HELF.Router

  test "the truth" do
    assert 1 + 1 == 2
  end

  test "raw ping request" do
    expected = {:reply, {:text, "pong"}, %{}, %{}}
    got = Router.Server.websocket_handle({:text, "ping"}, %{}, %{})
    assert expected == got
  end

  test "json ping request" do
    request = "{\"topic\":\"ping\",\"args\":[]}"
    expected = "{\"data\":\"pong\",\"code\":200}"
    {:reply, {:text, got}, _, _} = Router.Server.websocket_handle({:text, request}, %{}, %{})
    assert expected == got
  end

  test "invalid request" do
    request = "invalid"
    expected = "{\"data\":\"Invalid JSON\",\"code\":400}"
    {:reply, {:text, got}, _, _} = Router.Server.websocket_handle({:text, request}, %{}, %{})
    assert expected == got
  end

  test "invalid topic" do
    request = "{\"topic\":\"404\",\"args\":[]}"
    expected = "{\"data\":\"Route not found\",\"code\":404}"
    {:reply, {:text, got}, _, _} = Router.Server.websocket_handle({:text, request}, %{}, %{})
    assert expected == got
  end
end
