defmodule ExCheck.JSONTest do
  use ExUnit.Case, async: true

  alias ExCheck.JSON

  defp encode(term), do: term |> JSON.encode() |> IO.iodata_to_binary()

  test "encodes primitives" do
    assert encode(nil) == "null"
    assert encode(true) == "true"
    assert encode(false) == "false"
    assert encode(42) == "42"
    assert encode(-7) == "-7"
  end

  test "encodes strings with escaping" do
    assert encode("plain") == ~s("plain")
    assert encode("a\"b") == ~s("a\\"b")
    assert encode("a\\b") == ~s("a\\\\b")
    assert encode("line1\nline2") == ~s("line1\\nline2")
    assert encode("tab\there") == ~s("tab\\there")
  end

  test "encodes control characters as \\u escapes" do
    assert encode(<<0x01>>) == ~s("\\u0001")
  end

  test "encodes atoms as strings" do
    assert encode(:ok) == ~s("ok")
  end

  test "encodes lists and maps and round-trips via Jason" do
    term = %{
      status: "error",
      passed: 4,
      failed_checks: ["formatter", "ex_unit"],
      checks: [%{name: "compiler", app: nil, output: "boom\n** (Mix) bad"}]
    }

    json = encode(term)

    assert Jason.decode!(json) == %{
             "status" => "error",
             "passed" => 4,
             "failed_checks" => ["formatter", "ex_unit"],
             "checks" => [%{"name" => "compiler", "app" => nil, "output" => "boom\n** (Mix) bad"}]
           }
  end
end
