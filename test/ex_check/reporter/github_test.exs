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
    # formatter has no diagnostics parser → file-less fallback annotation
    assert out =~ "::error::formatter failed (exit 1)\n"
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
    assert out =~ "::error::formatter failed (exit 1)"
  end

  describe "inline annotations (Story 3)" do
    defp compiler_output do
      """
          warning: variable "x" is unused (if the variable is not meant to be used, prefix it with an underscore)
          │
        5 │   def bar(x) do
          │           ~
          │
          └─ lib/foo.ex:5:11: Foo.bar/1
      """
    end

    defp credo_error_output do
      """
      ┃ [F] ↘ There is a complexity problem.
      ┃       lib/foo.ex:9:3 #(Foo.bar)
      """
    end

    test "emits a file/line annotation per compiler diagnostic, after the group" do
      results = [{:error, {:compiler, ["mix", "compile"], []}, {1, compiler_output(), 2}}]
      out = IO.iodata_to_binary(Github.log(results, "T"))

      assert out =~
               "::warning file=lib/foo.ex,line=5,col=11,title=compiler::variable \"x\" is unused"

      # annotation comes after the group's endgroup
      assert :binary.match(out, "::endgroup::") < :binary.match(out, "::warning file=")
    end

    test "error-severity diagnostic uses the ::error command" do
      results = [{:error, {:credo, ["mix", "credo"], []}, {1, credo_error_output(), 1}}]
      out = IO.iodata_to_binary(Github.log(results, "T"))

      assert out =~
               "::error file=lib/foo.ex,line=9,col=3,title=credo::There is a complexity problem."
    end

    test "prefixes the file with the tool's :cd (umbrella child app)" do
      results = [
        {:error, {{:compiler, :child}, ["mix", "compile"], [cd: "apps/child"]},
         {1, compiler_output(), 2}}
      ]

      out = IO.iodata_to_binary(Github.log(results, "T"))
      assert out =~ "::warning file=apps/child/lib/foo.ex,line=5,col=11,title=compiler in child::"
    end

    test "escapes % and CR in the annotation message via escape_data" do
      output = "    warning: bad 50% off\rthing\n    │\n    └─ lib/foo.ex:5: Foo.bar/0\n"

      results = [{:error, {:compiler, ["mix", "compile"], []}, {1, output, 1}}]
      out = IO.iodata_to_binary(Github.log(results, "T"))

      assert out =~ "::warning file=lib/foo.ex,line=5,title=compiler::bad 50%25 off%0Dthing"
    end

    test "caps annotations at 10 per check" do
      lines =
        for n <- 1..15 do
          "    warning: issue #{n}\n    │\n    └─ lib/foo.ex:#{n}: Foo.bar/0\n"
        end

      results = [{:error, {:compiler, ["mix", "compile"], []}, {1, Enum.join(lines), 1}}]
      out = IO.iodata_to_binary(Github.log(results, "T"))

      count = out |> String.split("::warning ") |> length() |> Kernel.-(1)
      assert count == 10
    end

    test "falls back to a file-less annotation when a check has no diagnostics" do
      results = [{:error, {:sobelow, ["mix", "sobelow"], []}, {1, "boom\n", 1}}]
      out = IO.iodata_to_binary(Github.log(results, "T"))

      assert out =~ "::error::sobelow failed (exit 1)\n"
      refute out =~ "::error file="
    end
  end
end
