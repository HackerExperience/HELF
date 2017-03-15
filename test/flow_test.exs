defmodule HELF.FlowTest do

  use ExUnit.Case, async: true

  import HELF.Flow
  import ExUnit.CaptureLog

  describe "on_success" do
    test "is executed when a flow succeeds to the `do` clause" do
      me = self()

      return = flowing do
        with \
          on_success(fn -> send me, :success end),
          {:ok, _} <- {:ok, :success}
        do
          :yep
        end
      end

      assert :yep == return
      assert_receive :success
    end

    test "is not executed when a flow fails to the `else` clause" do
      me = self()

      return = flowing do
        with \
          on_success(fn -> send me, :success end),
          {:ok, _} <- {:error, :failed}
        do
          :yep
        end
      end

      assert {:error, :failed} == return
      refute_receive :success
    end
  end

  describe "on_fail" do
    test "is executed when a flow fails to the `else` clause" do
      me = self()

      return = flowing do
        with \
          on_fail(fn -> send me, :fail end),
          {:ok, _} <- {:error, :failed}
        do
          :yep
        end
      end

      assert {:error, :failed} == return
      assert_receive :fail
    end

    test "is not executed when a flow succeeds to the `do` clause" do
      me = self()

      return = flowing do
        with \
          on_fail(fn -> send me, :fail end),
          {:ok, _} <- {:ok, :success}
        do
          :yep
        end
      end

      assert :yep == return
      refute_receive :fail
    end
  end

  describe "on_done" do
    test "is executed when a flow succeeds to the `do` clause" do
      me = self()

      return = flowing do
        with \
          on_done(fn -> send me, :done end),
          {:ok, _} <- {:ok, :success}
        do
          :yep
        end
      end

      assert :yep == return
      assert_receive :done
    end

    test "is executed when a flow fails to the `else` clause" do
      me = self()

      return = flowing do
        with \
          on_done(fn -> send me, :done end),
          {:ok, _} <- {:error, :failed}
        do
          :yep
        end
      end

      assert {:error, :failed} == return
      assert_receive :done
    end
  end

  describe "combining" do
    test "will execute only success and done when a flow succeeds to the `do` clause" do
      me = self()

      return = flowing do
        with \
          on_success(fn -> send me, :success end),
          on_done(fn -> send me, :done end),
          on_fail(fn -> send me, :fail end),
          {:ok, _} <- {:ok, :success}
        do
          :yep
        end
      end

      assert :yep == return
      assert_receive :success
      assert_receive :done
      refute_receive :fail
    end

    test "will execute only success and done when a flow fails to the `else` clause" do
      me = self()

      return = flowing do
        with \
          on_success(fn -> send me, :success end),
          on_done(fn -> send me, :done end),
          on_fail(fn -> send me, :fail end),
          {:ok, _} <- {:error, :failed}
        do
          :yep
        end
      end

      assert {:error, :failed} == return
      assert_receive :done
      assert_receive :fail
      refute_receive :success
    end
  end

  test "executes callbacks in the order they where defined when flow succeeds" do
    me = self()

    return = flowing do
      with \
        on_success(fn -> :timer.sleep(50); send me, {:success, 1} end),
        on_done(fn -> :timer.sleep(50); send me, {:done, 1} end),
        on_fail(fn -> :timer.sleep(50); send me, {:fail, 1} end),
        {:ok, _} <- {:ok, :success},
        on_fail(fn -> :timer.sleep(50); send me, {:fail, 2} end),
        on_done(fn -> :timer.sleep(50); send me, {:done, 2} end),
        on_success(fn -> :timer.sleep(50); send me, {:success, 2} end)
      do
        :yep
      end
    end

    expected = [success: 1, done: 1, done: 2, success: 2]

    mailbox = fetch_all_mail()

    assert :yep == return
    assert expected == mailbox
  end

  # Note that this happens because when an operation fails, there is a certain
  # order things should be done to revert it's side-effects. Example:
  # Suppose the operation is x = 100 |> div(2) |> sub(20)
  # To undo that we have to execute the operations in reverse order:
  #   x |> sum(20) |> mul(2)
  test "executes callbacks IN REVERSE ORDER when flow fails" do
    me = self()

    return = flowing do
      with \
        on_success(fn -> :timer.sleep(50); send me, {:success, 1} end),
        on_done(fn -> :timer.sleep(50); send me, {:done, 1} end),
        on_fail(fn -> :timer.sleep(50); send me, {:fail, 1} end),
        {:ok, _} <- {:ok, :success},
        on_fail(fn -> :timer.sleep(50); send me, {:fail, 2} end),
        on_done(fn -> :timer.sleep(50); send me, {:done, 2} end),
        on_success(fn -> :timer.sleep(50); send me, {:success, 2} end),
        {:ok, _} <- {:error, :failed}
      do
        :yep
      end
    end

    expected = [done: 2, fail: 2, fail: 1, done: 1]

    mailbox = fetch_all_mail()

    assert {:error, :failed} == return
    assert expected == mailbox
  end

  test "when a callback raises, the error will be logged and the rest of callbacks will still run" do
    me = self()

    log = capture_log(fn ->
      flowing do
        with \
          on_success(fn -> send me, {:success, 1} end),
          on_done(fn -> send me, {:done, 1} end),
          on_fail(fn -> send me, {:fail, 1} end),
          {:ok, _} <- {:ok, :success},
          on_done(fn -> raise "FOO BAR" end),
          on_fail(fn -> send me, {:fail, 2} end),
          on_done(fn -> send me, {:done, 2} end),
          on_success(fn -> send me, {:success, 2} end)
        do
          :yep
        end
      end

      # Here we are giving the spawned flow handler enough time to execute the
      # callbacks so ExUnit's capture_log can... well... capture the logs...
      :timer.sleep(100)
    end)

    expected = [success: 1, done: 1, done: 2, success: 2]

    mailbox = fetch_all_mail()

    # All callbacks shall be executed even if one of them raises
    assert expected == mailbox
    assert log =~ "FOO BAR"
  end

  describe "callbacks" do
    test "can't be set when outside flow" do
      assert_raise RuntimeError, "cannot set callback outside of flow", fn ->
        on_success(fn -> :foo end)
      end

      assert_raise RuntimeError, "cannot set callback outside of flow", fn ->
        on_fail(fn -> :foo end)
      end

      assert_raise RuntimeError, "cannot set callback outside of flow", fn ->
        on_done(fn -> :foo end)
      end
    end

    test "can be set inside a function if called inside a flow" do
      function = fn ->
        me = self()

        on_done(fn -> send me, :done end)
      end

      flowing do
        with \
          function.(),
          {:ok, _} <- {:ok, :dokey}
        do
          :this_is_an_atom
        end
      end

      assert_receive :done
    end

    test "can't be set on a different process than the one that is flowing" do
      function = fn ->
        me = self()

        spawn fn ->
          on_done(fn -> send me, :done end)
        end
      end

      # The error will be raised inside the spawned process (without affecting
      # the current flow) so we'll have to capture the log to ensure this
      # happened. "If a tree falls in a forest and no one is around to hear it,
      # does it make a sound?"
      log = capture_log(fn ->
        flowing do
          with \
            function.(),
            {:ok, _} <- {:ok, :dokey}
          do
            :this_is_an_atom
          end
        end

        :timer.sleep(100)
      end)

      assert log =~ "cannot set callback outside of flow"
    end
  end

  defp fetch_all_mail,
    do: fetch_all_mail([])
  defp fetch_all_mail(collection) do
    receive do
      msg ->
        fetch_all_mail([msg| collection])
    after
      100 ->
        :lists.reverse(collection)
    end
  end
end