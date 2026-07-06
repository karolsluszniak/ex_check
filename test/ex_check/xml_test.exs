defmodule ExCheck.XMLTest do
  use ExUnit.Case, async: true

  alias ExCheck.XML

  defp escape(str), do: IO.iodata_to_binary(XML.escape(str))

  test "escapes the five predefined entities" do
    assert escape(~s(a & b < c > d " e ' f)) ==
             "a &amp; b &lt; c &gt; d &quot; e &apos; f"
  end

  test "drops XML-1.0-invalid control characters but keeps tab/newline/cr" do
    assert escape("a\x00b\x08c") == "abc"
    assert escape("a\tb\nc\rd") == "a\tb\nc\rd"
  end

  test "neutralizes a CDATA-close sequence via entity escaping" do
    assert escape("]]>") == "]]&gt;"
  end

  test "passes multibyte characters through unchanged" do
    assert escape("café — ✓") == "café — ✓"
  end
end
