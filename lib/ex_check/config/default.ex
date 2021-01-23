defmodule ExCheck.Config.Default do
  @moduledoc false

  # Default tool order tries to put short-running tools first in order for sequential output
  # streaming to display as many outputs as possible as soon as possible.
  @curated_tools [
    {:compiler, "mix compile --warnings-as-errors --force"},
    {:unused_deps, "mix deps.unlock --check-unused",
     detect: [{:elixir, ">= 1.10.0"}], fix: "mix deps.unlock --unused"},
    {:formatter, "mix format --check-formatted",
     detect: [{:file, ".formatter.exs"}], fix: "mix format"},
    {:credo, "mix credo", detect: [{:package, :credo}]},
    {:doctor, "mix doctor", detect: [{:package, :doctor}, {:elixir, ">= 1.8.0"}]},
    {:sobelow, "mix sobelow --exit", umbrella: [recursive: true], detect: [{:package, :sobelow}]},
    {:ex_doc, "mix docs", detect: [{:package, :ex_doc}]},
    {:ex_unit, "mix test", detect: [{:file, "test"}], retry: "mix test --failed"},
    {:dialyzer, "mix dialyzer", detect: [{:package, :dialyxir}]},
    {:npm_test, "npm test", cd: "assets", detect: [{:file, "package.json", else: :disable}]}
  ]

  @default_config [
    parallel: true,
    skipped: true,
    tools: @curated_tools
  ]

  def get do
    @default_config
  end

  def tool_order(tool) do
    Enum.find_index(@curated_tools, &(elem(&1, 0) == tool))
  end
end
