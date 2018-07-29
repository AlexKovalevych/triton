defmodule Triton.Mixfile do
  use Mix.Project

  @version "0.3.0"
  @url "https://github.com/blitzstudios/triton"
  @maintainers ["Weixi Yen", "Alex Kovalevych"]

  def project do
    [
      name: "Triton",
      app: :triton,
      version: @version,
      source_url: @url,
      elixir: "~> 1.6",
      description: "Pure Elixir Cassandra ORM built on top of Xandra.",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      package: package(),
      homepage_url: @url,
      deps: deps()
    ]
  end

  def application do
    [extra_applications: [:logger], mod: {Triton, []}]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:xandra, "~> 0.9"},
      {:poolboy, "~> 1.5"},
      {:vex, "~> 0.6"},
      {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end

  defp package do
    [
      maintainers: @maintainers,
      licenses: ["MIT"],
      links: %{github: @url},
      files: ~w(lib) ++ ~w(CHANGELOG.md LICENSE mix.exs README.md)
    ]
  end
end
