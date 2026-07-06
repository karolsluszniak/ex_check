defmodule ExCheck.Reporter.GithubTest do
  # async: false — mutates the shared GITHUB_STEP_SUMMARY environment variable.
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias ExCheck.Reporter.Github

  defp results do
    [
      {:ok, {:compiler, ["mix", "compile"], []}, {0, "", 2}},
      {:error, {:formatter, ["mix", "format", "--check-formatted"], []},
       {1, "\e[31m** (Mix) not formatted\e[0m\nlib/foo.ex\n", 1}},
      {:skipped, :credo, {:package, "credo"}}
    ]
  end

  setup do
    System.delete_env("GITHUB_STEP_SUMMARY")
    :ok
  end

  test "renders ok/skipped one-liners and a paired error group" do
    out = IO.iodata_to_binary(Github.log(results(), "TOKEN"))

    assert out =~ "✓ compiler success in 0:02\n"
    assert out =~ "⏭ credo skipped (missing package credo)\n"
    assert out =~ "::group::✕ formatter — mix format --check-formatted (exit 1)\n"
    assert out =~ "::endgroup::\n"
    assert out =~ "::error::mix check failed: formatter\n"
  end

  test "keeps ANSI in failure output (GitHub renders it)" do
    out = IO.iodata_to_binary(Github.log(results(), "TOKEN"))
    assert out =~ "\e[31m** (Mix) not formatted"
  end

  test "wraps failure output in a ::stop-commands:: guard so it can't inject commands" do
    poison = [
      {:error, {:sobelow, ["mix", "sobelow"], []}, {1, "::set-output name=x::pwned\n", 3}}
    ]

    out = IO.iodata_to_binary(Github.log(poison, "TOK"))

    assert out =~ "::stop-commands::TOK\n::set-output name=x::pwned\n::TOK::\n::endgroup::\n"
  end

  test "no error trailer on a clean run" do
    out = IO.iodata_to_binary(Github.log([{:ok, {:compiler, ["mix"], []}, {0, "", 1}}], "T"))
    refute out =~ "::error::"
  end

  test "escape_data escapes %, CR and LF (percent first)" do
    assert Github.escape_data("a%b\r\nc") == "a%25b%0D%0Ac"
  end

  test "escape_property additionally escapes : and ," do
    assert Github.escape_property("a:b,c") == "a%3Ab%2Cc"
    assert Github.escape_property("100%:x") == "100%25%3Ax"
  end

  test "write_step_summary appends a markdown table when the env var is set" do
    path = Path.join(System.tmp_dir!(), "ex_check_gh_#{System.unique_integer([:positive])}.md")
    on_exit(fn -> File.rm(path) end)
    System.put_env("GITHUB_STEP_SUMMARY", path)

    assert Github.write_step_summary(results(), 15) == :ok

    md = File.read!(path)
    assert md =~ "## mix check"
    assert md =~ "| Check | Status | Duration |"
    assert md =~ "| compiler | ✅ | 0:02 |"
    assert md =~ "| formatter | ❌ | 0:01 |"
    assert md =~ "| credo | ⏭ | — |"
    assert md =~ "Total: 0:15"
  end

  test "write_step_summary is a silent no-op when the env var is unset" do
    assert Github.write_step_summary(results(), 15) == :ok
  end

  test "report/3 writes the workflow log to stdout" do
    out = capture_io(fn -> Github.report(results(), 15, []) end)

    assert out =~ "::group::✕ formatter"
    assert out =~ "::stop-commands::"
    assert out =~ "::error::mix check failed: formatter"
  end
end
