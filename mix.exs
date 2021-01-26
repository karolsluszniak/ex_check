defmodule ExCheck.MixProject do
  use Mix.Project

  @github_url "https://github.com/karolsluszniak/ex_check"
  @description "One task to efficiently run all code analysis & testing tools in an Elixir project"

  def project do
    [
      app: :ex_check,
      version: "0.14.0",
      elixir: "~> 1.7",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      description: @description,
      deps: deps(),
      docs: docs(),
      package: package(),
      preferred_cli_env: [
        check: :test,
        credo: :test,
        dialyxir: :test,
        doctor: :test,
        sobelow: :test
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["test/support", "lib"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [
      extra_applications: []
    ]
  end

  defp deps do
    [
      {:credo, ">= 0.0.0", only: [:test], runtime: false},
      {:doctor, ">= 0.0.0", only: [:test], runtime: false},
      {:ex_doc, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:sobelow, ">= 0.0.0", only: [:test], runtime: false}
    ]
  end

  defp docs do
    [
      main: "readme",
      logo: "logo.svg",
      source_url: @github_url,
      extras: ["README.md"]
    ]
  end

  defp package do
    [
      maintainers: ["Karol Słuszniak"],
      licenses: ["MIT"],
      links: %{
        "GitHub repository" => @github_url,
        "Changelog" => @github_url <> "/blob/master/CHANGELOG.md"
      }
    ]
  end
end
