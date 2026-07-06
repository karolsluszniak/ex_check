defmodule ExCheck.Diagnostics.ExUnitTest do
  use ExUnit.Case, async: true

  alias ExCheck.Diagnostics.ExUnit, as: ExUnitParser

  test "parses failure headers with their file:line" do
    text = """
    Failures:

      1) test it adds (MathTest)
         test/math_test.exs:8
         Assertion with == failed

      2) test it subtracts (MathTest)
         test/math_test.exs:14
         Assertion with == failed
    """

    assert [first, second] = ExUnitParser.parse(text)

    assert first.severity == :error
    assert first.file == "test/math_test.exs"
    assert first.line == 8
    assert first.message == "test it adds (MathTest)"

    assert second.line == 14
  end

  test "garbage yields no diagnostics" do
    assert ExUnitParser.parse("all tests passed\n") == []
  end
end
