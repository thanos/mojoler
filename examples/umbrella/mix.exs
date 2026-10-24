defmodule Umbrella.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      elixir: "~> 1.20",
      start_permanent: Mix.env() == :prod,
      deps: []
    ]
  end
end