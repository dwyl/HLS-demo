defmodule HlsDemo.MixProject do
  use Mix.Project

  def project do
    [
      app: :hls_demo,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {HlsDemo, []},
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:plug, "~> 1.6"},
      {:plug_crypto, "~> 1.2"},
      {:bandit, "~> 1.5"},
      {:websock_adapter, "~> 0.5"},
      {:ex_cmd, "~> 0.12"},
      {:evision, "~> 0.2"},
      {:file_system, "~> 1.0"},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.5", only: [:dev, :test], runtime: false}
    ]
  end
end
