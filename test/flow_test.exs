defmodule HELF.FlowTest do

  use ExUnit.Case, async: true

  import HELF.Flow

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

  test "executes callbacks in the order they where defined" do
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