defmodule CarCache.MixProject do
  use Mix.Project

  @name "CarCache"
  @version "0.1.0"
  @repo_url "https://github.com/jeffutter/car_cache"

  def project do
    [
      app: :car_cache,
      name: @name,
      version: @version,
      source_url: @repo_url,
      description: "Clock with Adaptive Replacement cache",
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      docs: docs()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:nimble_options, "~> 0.3.0"},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false},
      {:propcheck, "~> 1.3", github: "alfert/propcheck", only: [:dev, :test]},
      {:ex_doc, "~> 0.20", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      files: ["lib", "mix.exs", "README*"],
      licenses: ["MIT"],
      links: %{"Github" => @repo_url}
    ]
  end

  defp docs do
    [
      main: @name,
      name: @name,
      canonical: "http://hexdocs.pm/car_cache",
      source_url: @repo_url
    ]
  end
end
