defmodule Consumer.MixProject do
  use Mix.Project

  def project do
    [
      app: :consumer,
      version: "0.1.0",
      elixir: "~> 1.20",
      start_permanent: Mix.env() == :prod,
      deps: [{:mojoler, path: "../.."}],
      releases: [
        consumer: [
          include_executables_for: [:unix],
          applications: [consumer: :permanent, mojoler: :permanent]
        ]
      ]
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end
end