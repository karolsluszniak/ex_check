defmodule ExCheck.Diagnostics.CredoTest do
  use ExUnit.Case, async: true

  alias ExCheck.Diagnostics.Credo

  test "parses issue/location line pairs and maps categories to severity" do
    text = """
    ┃ Code Readability
    ┃
    ┃ [R] ↘ There should be no trailing white-space at the end of a line.
    ┃       lib/foo.ex:3:1 #(Foo)
    ┃ [W] ↗ Function is too complex.
    ┃       lib/bar.ex:10 #(Bar.baz)
    """

    assert [readability, warning] = Credo.parse(text)

    assert readability.severity == :error
    assert readability.file == "lib/foo.ex"
    assert readability.line == 3
    assert readability.column == 1
    assert readability.message == "There should be no trailing white-space at the end of a line."

    assert warning.severity == :warning
    assert warning.file == "lib/bar.ex"
    assert warning.line == 10
    assert warning.column == nil
  end

  test "a custom (non-default) format yields no diagnostics" do
    assert Credo.parse("lib/foo.ex:3:1: R: trailing whitespace\n") == []
  end
end
