defmodule ExCheck.Diagnostics.CompilerTest do
  use ExUnit.Case, async: true

  alias ExCheck.Diagnostics.Compiler

  test "parses modern warning/error blocks with file:line:col" do
    text = """
        warning: variable "x" is unused
        │
      5 │   def bar(x) do
        │           ~
        │
        └─ lib/foo.ex:5:11: Foo.bar/1

        error: undefined function baz/0
        │
      9 │   baz()
        │
        └─ lib/foo.ex:9: Foo.qux/0
    """

    assert [warn, err] = Compiler.parse(text)

    assert warn.severity == :warning
    assert warn.file == "lib/foo.ex"
    assert warn.line == 5
    assert warn.column == 11
    assert warn.message == "variable \"x\" is unused"

    assert err.severity == :error
    assert err.line == 9
    assert err.column == nil
    assert err.message == "undefined function baz/0"
  end

  test "falls back to the legacy indented location line" do
    text = "warning: something\n    lib/legacy.ex:42\n"
    assert [%{file: "lib/legacy.ex", line: 42}] = Compiler.parse(text)
  end

  test "garbage yields no diagnostics" do
    assert Compiler.parse("nothing to see here\njust logs\n") == []
  end
end
