defmodule ExCheck.XML do
  @moduledoc false

  # Minimal XML text escaper for the fully-controlled output of the JUnit reporter.
  # Kept dependency-free on purpose, mirroring ExCheck.JSON: ex_check must not pull a
  # runtime dep just to emit a report. Escapes the five predefined entities and drops
  # characters that are invalid in XML 1.0 (control chars below 0x20 other than tab,
  # newline and carriage return), which would otherwise make the document unparseable.

  @spec escape(binary) :: iodata
  def escape(str) when is_binary(str), do: escape(str, "")

  defp escape(<<>>, acc), do: acc
  defp escape(<<?&, rest::binary>>, acc), do: escape(rest, acc <> "&amp;")
  defp escape(<<?<, rest::binary>>, acc), do: escape(rest, acc <> "&lt;")
  defp escape(<<?>, rest::binary>>, acc), do: escape(rest, acc <> "&gt;")
  defp escape(<<?", rest::binary>>, acc), do: escape(rest, acc <> "&quot;")
  defp escape(<<?', rest::binary>>, acc), do: escape(rest, acc <> "&apos;")

  defp escape(<<char::utf8, rest::binary>>, acc)
       when char < 0x20 and char not in [?\t, ?\n, ?\r] do
    escape(rest, acc)
  end

  defp escape(<<char::utf8, rest::binary>>, acc) do
    escape(rest, acc <> <<char::utf8>>)
  end
end
