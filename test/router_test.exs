defmodule HELF.RouterTest do
  use ExUnit.Case

  doctest HELF.Router

  test "the truth" do
    assert 1 + 1 == 2
  end

  test "websocket init flags" do
    {:upgrade, :protocol, :cowboy_websocket} = HELF.Router.init(%{}, %{}, %{})
  end

  test "websocket initialization" do
    {:ok, %{}, %{}, :infinity} = HELF.Router.websocket_init(%{}, %{}, %{})
  end

  # websocket_handle callback tests

  test "raw ping request" do
    expected = {:reply, {:text, "pong"}, %{}, %{}}
    got = HELF.Router.websocket_handle({:text, "ping"}, %{}, %{})
    assert expected == got
  end

  test "json ping request" do
    request = "{\"topic\":\"ping\",\"args\":[]}"
    expected = "{\"data\":\"pong\",\"code\":200}"
    {:reply, {:text, got}, _, _} = HELF.Router.websocket_handle({:text, request}, %{}, %{})
    assert expected == got
  end

  test "invalid request" do
    request = "invalid"
    expected = "{\"data\":\"SyntaxError\",\"code\":400}"
    {:reply, {:text, got}, _, _} = HELF.Router.websocket_handle({:text, request}, %{}, %{})
    assert expected == got
  end

  test "invalid topic" do
    request = "{\"topic\":\"404\",\"args\":[]}"
    expected = "{\"data\":\"Route `404` not found.\",\"code\":404}"
    {:reply, {:text, got}, _, _} = HELF.Router.websocket_handle({:text, request}, %{}, %{})
    assert expected == got
  end

  # TODO: add real websocket tests
  # ...

  # should just reply with a tuple
  test "websocket_info consistency" do
    {:reply, {:text, "msg"}, _, _} = HELF.Router.websocket_info("msg", %{}, %{})
  end

  # should just return ok
  test "websocket_terminate should return :ok" do
    :ok = HELF.Router.websocket_terminate(:ok, %{}, %{})
  end
end
