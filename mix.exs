defmodule Mojoler.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/thanos/mojoler"

  def project do
    [
      app: :mojoler,
      version: @version,
      elixir: "~> 1.20",
      start_permanent: Mix.env() == :prod,
      compilers: Mix.compilers() ++ [:mojoler],
      description: description(),
      package: package(),
      source_url: @source_url,
      homepage_url: @source_url,
      docs: docs(),
      test_coverage: [tool: ExCoveralls],
      deps: deps()
    ]
  end

  def cli do
    [
      preferred_envs: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.html": :test,
        "coveralls.json": :test,
        "coveralls.post": :test,
        "coveralls.github": :test
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test},
      {:ex_doc, "~> 0.40", only: :dev, runtime: false}
    ]
  end

  defp description do
    "Mojo NIFs for OTP 28. Generated ABI, checked terms, resources, dirty schedulers, and a Mix compiler. Mojo 1.1.0 is required at build time and is not vendored."
  end

  defp package do
    [
      name: "mojoler",
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => @source_url,
        "Changelog" => "#{@source_url}/blob/v#{@version}/CHANGELOG.md"
      },
      files: ~w(
        lib
        native
        priv
        scripts
        tools
        docs
        examples
        requirements.txt
        requirements-gpu.txt
        mix.exs
        README.md
        LICENSE
        CHANGELOG.md
      ),
      exclude_patterns: [
        ~r"/_build/",
        ~r"/deps/",
        ~r"/doc/",
        ~r"priv/native/.*\.so$",
        ~r"priv/native/staging/",
        ~r"priv/native/FINGERPRINT$",
        ~r"priv/native/link-inputs\.txt$",
        ~r"native/mojoler/abi/manifest\.json$"
      ]
    ]
  end

  defp docs do
    stage0 = Path.wildcard("docs/0*.md") |> Enum.sort()
    units = Path.wildcard("docs/tutorial/*.md") |> Enum.sort()
    stages = Path.wildcard("docs/stages/*.md") |> Enum.sort()

    guides =
      ~w(docs/quickstart.md docs/ownership.md docs/API.md docs/runtime.md docs/compatibility.md docs/TUTORIAL.md)

    [
      main: "readme",
      source_ref: "v#{@version}",
      extras: [
        "README.md"
        | guides ++
            stage0 ++
            units ++
            stages ++
            ~w(docs/GLOSSARY.md docs/DECISIONS.md docs/evidence-ledger.md docs/direct_mojo_proof.md)
      ],
      groups_for_extras: [
        Guides: guides,
        "Stage 0": stage0,
        Curriculum: units,
        Stages: stages
      ]
    ]
  end
end
