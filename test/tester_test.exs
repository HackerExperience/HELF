defmodule HELF.TesterTest do
  use ExUnit.Case

  require Logger

  alias HELF.{Tester, TesterTest}

  setup do
    {:ok, []}  = Application.ensure_all_started(:helf)
    {:ok, pid} = Tester.start_link(:tester_tests)

    on_exit fn ->
      # TODO: fix HeBroker stop
      try do
        Application.stop(:logger)
      rescue
        RuntimeError -> "Error!"
      end
    end

    {:ok, pid: pid}
  end

  test "the truth" do
    assert 1 + 1 == 2
  end

  test "example case", %{pid: pid} do
    # TODO: use events instead
  end
end
