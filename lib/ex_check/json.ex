defmodule ExCheck.JSON do
  @moduledoc false

  # Minimal JSON encoder for the fully-controlled output of the JSON/agent reporters.
  # Kept dependency-free on purpose: ex_check targets Elixir ~> 1.17 (the built-in
  # JSON module only arrived in 1.18) and must not pull a runtime dep like Jason.

  @spec encode(term) :: iodata
  def encode(nil), do: "null"
  def encode(true), do: "true"
  def encode(false), do: "false"
  def encode(int) when is_integer(int), do: Integer.to_string(int)
  def encode(float) when is_float(float), do: Float.to_string(float)
  def encode(atom) when is_atom(atom), do: encode_string(Atom.to_string(atom))
  def encode(str) when is_binary(str), do: encode_string(str)

  def encode(list) when is_list(list) do
    inner = list |> Enum.map(&encode/1) |> Enum.intersperse(",")
    ["[", inner, "]"]
  end

  # Keys are always atoms or strings in our reports, so they reuse the value clauses.
  def encode(map) when is_map(map) do
    inner =
      map
      |> Enum.map(fn {key, value} -> [encode(key), ":", encode(value)] end)
      |> Enum.intersperse(",")

    ["{", inner, "}"]
  end

  defp encode_string(str) do
    [?", escape(str, ""), ?"]
  end

  defp escape(<<>>, acc), do: acc
  defp escape(<<?", rest::binary>>, acc), do: escape(rest, acc <> "\\\"")
  defp escape(<<?\\, rest::binary>>, acc), do: escape(rest, acc <> "\\\\")
  defp escape(<<?\n, rest::binary>>, acc), do: escape(rest, acc <> "\\n")
  defp escape(<<?\r, rest::binary>>, acc), do: escape(rest, acc <> "\\r")
  defp escape(<<?\t, rest::binary>>, acc), do: escape(rest, acc <> "\\t")
  defp escape(<<?\f, rest::binary>>, acc), do: escape(rest, acc <> "\\f")
  defp escape(<<?\b, rest::binary>>, acc), do: escape(rest, acc <> "\\b")

  defp escape(<<char::utf8, rest::binary>>, acc) when char < 0x20 do
    escaped = "\\u" <> (char |> Integer.to_string(16) |> String.pad_leading(4, "0"))
    escape(rest, acc <> escaped)
  end

  defp escape(<<char::utf8, rest::binary>>, acc) do
    escape(rest, acc <> <<char::utf8>>)
  end
end
