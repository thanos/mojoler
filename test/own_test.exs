defmodule Mojoler.OwnTest do
  use ExUnit.Case, async: false

  test "counter add, double close, and one destructor" do
    abandon_counter()
    :erlang.garbage_collect()
    assert_receive :counter_destroyed, 1_000
    refute_receive :counter_destroyed, 50
  end

  test "freeze rejects an outstanding borrow and the resource binary survives close" do
    blob = Mojoler.Own.open_blob(<<1, 2, 3>>)
    assert Mojoler.Own.blob_borrow(blob) == {:ok, 3}
    assert Mojoler.Own.blob_freeze(blob) == {:error, :borrowed}
    assert Mojoler.Own.blob_release(blob) == :ok
    assert {:ok, bin} = Mojoler.Own.blob_freeze(blob)
    assert bin == <<1, 2, 3>>
    assert Mojoler.Own.blob_freeze(blob) == {:error, :frozen}
    assert Mojoler.Own.blob_close(blob) == :ok
    assert bin == <<1, 2, 3>>
  end

  test "a retained binary is readable after its source process exits" do
    parent = self()

    child =
      spawn(fn ->
        handle = Mojoler.Own.retain_binary(<<9, 8, 7>>)
        send(parent, {:handle, handle})
      end)

    assert_receive {:handle, handle}, 1_000
    ref = Process.monitor(child)
    assert_receive {:DOWN, ^ref, :process, ^child, _}, 1_000
    assert Mojoler.Own.read_retained(handle) == <<9, 8, 7>>
  end

  test "a native buffer keeps its token and its bytes across in-place writes" do
    blob = Mojoler.Own.open_blob(<<1, 2, 3, 4>>)
    assert {:ok, token} = Mojoler.Own.blob_token(blob)
    assert Mojoler.Own.blob_poke(blob, 1, 9) == :ok
    assert Mojoler.Own.blob_poke(blob, 1, 8) == :ok
    assert Mojoler.Own.blob_token(blob) == {:ok, token}
    assert {:ok, bin} = Mojoler.Own.blob_freeze(blob)
    assert bin == <<1, 8, 3, 4>>
    assert Mojoler.Own.blob_poke(blob, 0, 1) == {:error, :not_mutable}
  end

  test "a pin keeps the blob alive after the handle is dropped" do
    before = Mojoler.Own.blob_dtors()
    parent = self()

    holder =
      spawn(fn ->
        pin = stage_pin()
        send(parent, :held)

        receive do
          :drop -> pin
        end
      end)

    assert_receive :held, 1_000
    :erlang.garbage_collect(holder)
    Process.sleep(30)
    assert Mojoler.Own.blob_dtors() == before
    send(holder, :drop)
    ref = Process.monitor(holder)
    assert_receive {:DOWN, ^ref, :process, ^holder, _}, 1_000
    assert wait_dtors(before + 1, 50)
  end

  test "concurrent adds agree" do
    counter = Mojoler.Own.open_counter()

    tasks =
      for _ <- 1..20 do
        Task.async(fn -> Mojoler.Own.counter_add(counter, 1) end)
      end

    assert Enum.all?(Task.await_many(tasks), &match?({:ok, _}, &1))
    assert Mojoler.Own.counter_add(counter, 0) == {:ok, 20}
  end

  test "a foreign term is a bad argument" do
    assert_raise ArgumentError, fn -> Mojoler.Own.counter_add(:nope, 1) end
  end

  defp stage_pin do
    blob = Mojoler.Own.open_blob(<<1>>)
    Mojoler.Own.blob_pin(blob)
  end

  defp wait_dtors(target, tries) do
    cond do
      Mojoler.Own.blob_dtors() >= target ->
        true

      tries <= 0 ->
        false

      true ->
        :erlang.garbage_collect()
        Process.sleep(20)
        wait_dtors(target, tries - 1)
    end
  end

  defp abandon_counter do
    counter = Mojoler.Own.open_counter()
    assert Mojoler.Own.counter_add(counter, 20) == {:ok, 20}
    assert Mojoler.Own.counter_add(counter, 22) == {:ok, 42}
    assert Mojoler.Own.counter_close(counter) == :ok
    assert Mojoler.Own.counter_add(counter, 1) == {:error, :closed}
    assert Mojoler.Own.counter_close(counter) == :ok
    :ok
  end
end
