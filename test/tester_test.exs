defmodule HELF.TesterTest do
  use ExUnit.Case

  require Logger

  alias HELF.Tester

  setup do
    {:ok, _} = Application.ensure_all_started(:helf)
    :ok
  end

  test "broker cast" do
    service = :test01
    {:ok, pid} = Tester.start_link(service, self())

    Tester.listen(pid, :cast, "account:create")

    Tester.notify(pid, :cast, "account:create", %{username: "foo"})
    assert_receive {:cast, service, "account:create"}
    assert {:ok, %{username: "foo"}} = Tester.assert(pid, :cast, "account:create")
  end

  test "sequential broker casts" do
    service = :test02
    {:ok, pid} = Tester.start_link(service, self())

    Tester.listen(pid, :cast, "account:create")

    Tester.notify(pid, :cast, "account:create", %{username: "foo"})
    assert_receive {:cast, service, "account:create"}
    assert {:ok, %{username: "foo"}} = Tester.assert(pid, :cast, "account:create")

    Tester.notify(pid, :cast, "account:create", %{username: "bar"})
    assert_receive {:cast, service, "account:create"}
    assert {:ok, %{username: "bar"}} = Tester.assert(pid, :cast, "account:create")
  end

  test "broker call" do
    service = :test02
    {:ok, pid} = Tester.start_link(service, self())

    Tester.listen(pid, :call, "account:create")

    Tester.notify(pid, :call, "account:create", %{username: "bar"})

    assert_receive {:call, service, "account:create"}
    assert {:ok, %{username: "bar"}} = Tester.assert(pid, :call, "account:create")
  end

  test "sequential broker calls" do
    service = :test03
    {:ok, pid} = Tester.start_link(service, self())

    Tester.listen(pid, :call, "account:create")

    Tester.notify(pid, :call, "account:create", %{username: "foo"})
    assert_receive {:call, service, "account:create"}
    assert {:ok, %{username: "foo"}} = Tester.assert(pid, :call, "account:create")

    Tester.notify(pid, :call, "account:create", %{username: "bar"})
    assert_receive {:call, service, "account:create"}
    assert {:ok, %{username: "bar"}} = Tester.assert(pid, :call, "account:create")
  end


  test "mixed broker calls and casts" do
    service = :test03
    {:ok, pid} = Tester.start_link(service, self())

    Tester.listen(pid, :call, "account:create")
    Tester.listen(pid, :cast, "account:created")
    Tester.notify(pid, :call, "account:create", %{username: "foo"})
    Tester.notify(pid, :cast, "account:created", %{username: "bar"})

    assert_receive {:call, service, "account:create"}
    assert {:ok, %{username: "foo"}} = Tester.assert(pid, :call, "account:create")

    assert_receive {:cast, service, "account:created"}
    assert {:ok, %{username: "bar"}} = Tester.assert(pid, :cast, "account:created")

    Tester.notify(pid, :call, "account:create", %{username: "b4z"})
    Tester.notify(pid, :cast, "account:created", %{username: "baz"})

    assert_receive {:cast, service, "account:created"}
    assert {:ok, %{username: "baz"}} = Tester.assert(pid, :cast, "account:created")

    assert_receive {:call, service, "account:create"}
    assert {:ok, %{username: "b4z"}} = Tester.assert(pid, :call, "account:create")
  end
end
