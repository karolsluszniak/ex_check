defmodule ExCheck.MixProject do
  use Mix.Project

  @github_url "https://github.com/karolsluszniak/ex_check"
  @version "0.16.0"

  def project do
    [
      app: :ex_check,
      version: @version,
      elixir: "~> 1.12",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      package: package(),
      xref: [exclude: [:crypto]],
      preferred_cli_env: [
        check: :test,
        credo: :test,
        dialyxir: :test,
        doctor: :test,
        sobelow: :test,
        "deps.audit": :test
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
      {:sobelow, ">= 0.0.0", only: [:test], runtime: false},
      {:mix_audit, ">= 0.0.0", only: [:test], runtime: false}
    ]
  end

  defp docs do
    [
      extras: [
        "CHANGELOG.md": [title: "Changelog"],
        "LICENSE.md": [title: "License"],
        "README.md": [title: "Overview"]
      ],
      main: "readme",
      assets: "assets",
      logo: "assets/logo.svg",
      source_url: @github_url,
      source_ref: "v#{@version}",
      api_reference: false,
      formatters: ["html"]
    ]
  end

  defp package do
    [
      description:
        "One task to efficiently run all code analysis & testing tools in an Elixir project",
      maintainers: ["Karol Słuszniak"],
      licenses: ["MIT"],
      links: %{
        "Changelog" => "https://hexdocs.pm/ex_check/changelog.html",
        "GitHub repository" => @github_url
      }
    ]
  end
end
