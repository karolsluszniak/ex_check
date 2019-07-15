defmodule ExCheck.MixProject do
  use Mix.Project

  @github_url "https://github.com/karolsluszniak/ex_check"

  def project do
    [
      app: :ex_check,
      version: "0.1.0",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      description: "Runs all checks configured in an Elixir project",
      deps: deps(),
      dialyzer: dialyzer(),
      docs: docs(),
      package: package()
    ]
  end

  def application do
    [
      extra_applications: []
    ]
  end

  defp deps do
    [
      {:credo, ">= 0.0.0", only: :dev, runtime: false},
      {:dialyxir, ">= 0.0.0", only: :dev, runtime: false},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp dialyzer do
    [
      plt_add_apps: [:mix]
    ]
  end

  defp docs do
    [
      main: "Mix.Tasks.Check",
      source_url: @github_url
    ]
  end

  defp package do
    [
      maintainers: ["Karol Słuszniak"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => @github_url
      }
    ]
  end
end
