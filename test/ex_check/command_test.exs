defmodule ExCheck.CommandTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  alias ExCheck.Command

  # The first byte of "✓" (E2 9C 93), a pause, then the rest: the port delivers
  # two chunks, and the first ends inside the character.
  @split ["sh", "-c", ~S"printf '\342'; sleep 0.3; printf '\234\223 split\n'"]

  test "streams a character split across port chunks without raising" do
    captured =
      capture_io(fn ->
        assert {"✓ split\n", 0, _duration} = Command.run(@split, stream: true)
      end)

    assert captured == "✓ split\n"
  end

  test "streams a character split across chunks when the output is unsilenced mid-character" do
    captured =
      capture_io(fn ->
        task = Command.async(@split, stream: true, silenced: true)
        Process.sleep(150)
        assert {"✓ split\n", 0, _duration} = task |> Command.unsilence() |> Command.await()
      end)

    assert captured == "✓ split\n"
  end
end
