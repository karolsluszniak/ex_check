defmodule ExCheck.DiagnosticsTest do
  use ExUnit.Case, async: true

  alias ExCheck.Diagnostics

  test "strips ANSI before dispatching to the parser" do
    output = "\e[33m    warning: unused\e[0m\n    │\n    └─ lib/foo.ex:5:1: Foo.bar/0\n"
    result = {:error, {:compiler, ["mix", "compile"], []}, {1, output, 1}}

    assert [%Diagnostics.Diagnostic{file: "lib/foo.ex", line: 5, severity: :warning}] =
             Diagnostics.extract(result)
  end

  test "dispatches umbrella {name, app} on the base tool atom" do
    output = "    warning: unused\n    └─ lib/foo.ex:5: Foo.bar/0\n"
    result = {:error, {{:compiler, :child}, ["mix", "compile"], []}, {1, output, 1}}

    assert [%Diagnostics.Diagnostic{line: 5}] = Diagnostics.extract(result)
  end

  test "no registered parser yields []" do
    result = {:error, {:sobelow, ["mix", "sobelow"], []}, {1, "boom\n", 1}}
    assert Diagnostics.extract(result) == []
  end

  test "non-error results yield []" do
    assert Diagnostics.extract({:ok, {:compiler, ["mix"], []}, {0, "", 1}}) == []
    assert Diagnostics.extract({:skipped, :credo, {:package, "credo"}}) == []
  end
end
