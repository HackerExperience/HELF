defmodule HELF.TesterTest do
  use ExUnit.Case

  require Logger

  alias HELF.Tester

  setup do
    {:ok, _} = Application.ensure_all_started(:helf)
    {:ok, pid} = Tester.start_link(self())
    {:ok, pid: pid, service: :tester_tests}
  end

  test "broker cast", %{pid: pid, service: service} do
    Tester.listen(pid, :cast, service, "account:create")

    Tester.notify(pid, :cast, "account:create", %{username: "foo"})
    assert_receive {:cast, "account:create"}
    assert {:ok, %{username: "foo"}} = Tester.assert(pid, :cast, "account:create")
  end

  test "sequential broker casts", %{pid: pid, service: service} do
    Tester.listen(pid, :cast, service, "account:create")

    Tester.notify(pid, :cast, "account:create", %{username: "foo"})
    assert_receive {:cast, "account:create"}
    assert {:ok, %{username: "foo"}} = Tester.assert(pid, :cast, "account:create")

    Tester.notify(pid, :cast, "account:create", %{username: "bar"})
    assert_receive {:cast, "account:create"}
    assert {:ok, %{username: "bar"}} = Tester.assert(pid, :cast, "account:create")
  end

  test "broker call", %{pid: pid, service: service} do
    Tester.listen(pid, :call, service, "account:create")

    Tester.notify(pid, :call, "account:create", %{username: "bar"})
    assert_receive {:call, "account:create"}
    assert {:ok, %{username: "bar"}} = Tester.assert(pid, :call, "account:create")
  end

  test "sequential broker calls", %{pid: pid, service: service} do
    Tester.listen(pid, :call, service, "account:create")

    Tester.notify(pid, :call, "account:create", %{username: "foo"})
    assert_receive {:call, "account:create"}
    assert {:ok, %{username: "foo"}} = Tester.assert(pid, :call, "account:create")

    Tester.notify(pid, :call, "account:create", %{username: "bar"})
    assert_receive {:call, "account:create"}
    assert {:ok, %{username: "bar"}} = Tester.assert(pid, :call, "account:create")
  end


  test "mixed broker calls and casts", %{pid: pid, service: service} do
    Tester.listen(pid, :call, service, "account:create")
    Tester.listen(pid, :cast, service, "account:created")
    Tester.notify(pid, :call, "account:create", %{username: "foo"})
    Tester.notify(pid, :cast, "account:created", %{username: "bar"})

    assert_receive {:call, "account:create"}
    assert {:ok, %{username: "foo"}} = Tester.assert(pid, :call, "account:create")

    assert_receive {:cast, "account:created"}
    assert {:ok, %{username: "bar"}} = Tester.assert(pid, :cast, "account:created")

    Tester.notify(pid, :call, "account:create", %{username: "b4z"})
    Tester.notify(pid, :cast, "account:created", %{username: "baz"})

    assert_receive {:cast, "account:created"}
    assert {:ok, %{username: "baz"}} = Tester.assert(pid, :cast, "account:created")

    assert_receive {:call, "account:create"}
    assert {:ok, %{username: "b4z"}} = Tester.assert(pid, :call, "account:create")
  end
end
