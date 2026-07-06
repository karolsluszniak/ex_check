defmodule ExCheck.Reporter.Junit do
  @moduledoc false

  # JUnit XML report: each tool becomes a `<testcase>` inside a single `<testsuite>`.
  # Consumed by GitLab CI, Jenkins and other systems that render a JUnit test report.
  # Pairs naturally with `--output report.xml`. Failed checks carry their (ANSI-stripped,
  # XML-escaped) output; skipped ones carry their reason.

  @behaviour ExCheck.Reporter

  alias ExCheck.Reporter
  alias ExCheck.XML

  @impl true
  def report(results, total_duration, opts) do
    Reporter.emit(build(results, total_duration), opts)
  end

  @doc false
  def build(results, total_duration) do
    tests = length(results)
    failures = Enum.count(results, &match?({:error, _, _}, &1))
    skipped = Enum.count(results, &match?({:skipped, _, _}, &1))
    cases = results |> Enum.sort_by(&Reporter.summary_order/1) |> Enum.map(&testcase/1)

    [
      ~s(<?xml version="1.0" encoding="UTF-8"?>\n),
      ~s(<testsuites>\n),
      ~s(  <testsuite name="mix check" tests="#{tests}" failures="#{failures}"),
      ~s( skipped="#{skipped}" time="#{total_duration}">\n),
      cases,
      ~s(  </testsuite>\n),
      ~s(</testsuites>\n)
    ]
  end

  defp testcase({:ok, {name, _, _}, {_, _, duration}}) do
    [
      ~s(    <testcase classname="#{classname(name)}" name="#{tc_name(name)}" time="#{duration}"/>\n)
    ]
  end

  defp testcase({:error, {name, _, _}, {code, output, duration}}) do
    body = output |> Reporter.strip_ansi() |> XML.escape()

    [
      ~s(    <testcase classname="#{classname(name)}" name="#{tc_name(name)}" time="#{duration}">\n),
      ~s(      <failure message="exit code #{code}">),
      body,
      ~s(</failure>\n),
      ~s(    </testcase>\n)
    ]
  end

  defp testcase({:skipped, name, reason}) do
    message = reason |> Reporter.skip_reason_string() |> XML.escape()

    [
      ~s(    <testcase classname="#{classname(name)}" name="#{tc_name(name)}" time="0">\n),
      ~s(      <skipped message="#{message}"/>\n),
      ~s(    </testcase>\n)
    ]
  end

  defp classname(name) do
    case Reporter.split_name(name) do
      {_, nil} -> "check"
      {_, app} -> "check.#{XML.escape(app)}"
    end
  end

  defp tc_name(name) do
    {tc_name, _app} = Reporter.split_name(name)
    XML.escape(tc_name)
  end
end
