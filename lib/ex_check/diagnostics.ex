defmodule ExCheck.Diagnostics do
  @moduledoc false

  # Best-effort extraction of structured `{file, line, message}` findings from the raw
  # (ANSI-containing) output of failed tools. Result tuples stay untouched — the Manifest
  # and Pipeline pattern-match them — so parsing happens on demand in the reporters that
  # want it (json, agent, github). The pretty reporter never calls this and pays nothing.

  alias ExCheck.Reporter

  defmodule Diagnostic do
    @moduledoc false
    defstruct [:file, :line, :column, :message, severity: :error]

    @type t :: %__MODULE__{
            file: String.t() | nil,
            line: pos_integer | nil,
            column: pos_integer | nil,
            message: String.t(),
            severity: :error | :warning
          }
  end

  @callback parse(String.t()) :: [Diagnostic.t()]

  # Keyed by base tool atom; umbrella instances `{name, app}` collapse to `name`.
  @parsers %{
    compiler: ExCheck.Diagnostics.Compiler,
    credo: ExCheck.Diagnostics.Credo,
    ex_unit: ExCheck.Diagnostics.ExUnit
  }

  @doc """
  Structured diagnostics for a single result tuple. Only `:error` results are parsed
  (the default compiler command runs with `--warnings-as-errors`, so warnings already
  surface as failures — extend the guard here to parse `:ok` results too if needed).
  Anything without a registered parser, or that fails to parse, yields `[]`.
  """
  @spec extract(tuple) :: [Diagnostic.t()]
  def extract({:error, {name, _cmd, _opts}, {_code, output, _duration}}) do
    case Map.get(@parsers, base_name(name)) do
      nil -> []
      parser -> output |> Reporter.strip_ansi() |> parser.parse()
    end
  rescue
    _ -> []
  end

  def extract(_), do: []

  @doc """
  Turns a `[match, file, line]` or `[match, file, line, column]` regex result into
  `{file, line, column}`. `Regex.run/2` drops a trailing unmatched column group.
  """
  def parse_location([_, file, line]), do: {file, String.to_integer(line), nil}

  def parse_location([_, file, line, column]),
    do: {file, String.to_integer(line), String.to_integer(column)}

  defp base_name({name, _app}), do: name
  defp base_name(name), do: name
end
