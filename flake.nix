{
  description = "MOFA hybrid Rust + Python project as a Nix flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay.url = "github:oxalica/rust-overlay";
  };

  outputs = { self, nixpkgs, flake-utils, rust-overlay }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlays = [ rust-overlay.overlays.default ];
        pkgs = import nixpkgs { inherit system overlays; };

        rustToolchain = pkgs.rust-bin.stable.latest.default;

        pythonEnv = pkgs.python312.withPackages (ps: with ps; [
          # --------- base-tool --------- #
          sphinx
          sphinx-rtd-theme
          pytest
          pytest-cov
          pyrootutils
          pre-commit
          twine
          wheel
          coverage
          furo
          myst-parser
          pytest-mock
          pendulum
          python-dotenv
          cookiecutter
          setuptools

          # --------- date --------- #
          openpyxl
          attrs

          # --------- path --------- #
          pathlib

          # --------- web --------- #
          streamlit

          # --------- cli --------- #
          # No entries

          # --------- log --------- #
          loguru
          prettytable

          # --------- ai-tools --------- #
          langchain-openai
          langchain-community
          langchain-cohere
          langchain-postgres
          openai
          duckduckgo-search
          whisper
          arxiv

          # --------- server --------- #
          fastapi
          uvicorn

          # --------- db --------- #
          psycopg
          psycopg-binary
          langchain-chroma
          chromadb

          # --------- deploy --------- #
          # ansible is commented out

          # --------- data --------- #
          pydantic
          numpy
          pandas
          pypdf
          pyarrow
          unstructured
          python-docx
          python-magic
          python-pptx
          docx2txt
          markdown

          # --------- graph database --------- #
          neo4j

          # --------- yaml --------- #
          pyyaml

          # --------- agent --------- #
          crewai
          crewai-tools
          dspy-ai

          # --------- distributed --------- #
          dora-rs

          # --------- stock --------- #
          yfinance

          # --------- embedding --------- #
          sentence-transformers
          transformers

          # --------- ultralytics --------- #
          ultralytics

          # --------- web sider --------- #
          scrapegraphai
        ]);

        rustEnv = pkgs.symlinkJoin {
          name = "rust-env-with-dora";
          paths = [ rustToolchain pkgs.cargo ];
          buildInputs = [ pkgs.makeWrapper ];
          postBuild = ''
            mkdir -p $out/bin
            export PATH=${rustToolchain}/bin:$PATH
            cargo install dora-cli --root=$out --bins
          '';
        };

      in
      {
        devShell = pkgs.mkShell {
          buildInputs = [
            rustEnv
            pythonEnv
            pkgs.maturin
            pkgs.cowsay
          ];

          shellHook = ''
            cowsay "Rust + Python hybrid dev environment activated!"
            echo "Verifying installation..."
            rustc --version
            cargo --version
            dora --version
          '';
        };

        packages.default = pkgs.writeShellApplication {
          name = "mofa";
          runtimeInputs = [ pythonEnv rustEnv ];
          text = ''
            echo "Usage: nix run .#mofa -- <rust|python> [args...]"
            if [ "$1" = "rust" ]; then
              shift
              cargo run --manifest-path=../rust/Cargo.toml -- "$@"
            elif [ "$1" = "python" ]; then
              shift
              python ../python/main.py "$@"
            else
              echo "Unknown target: $1 (use 'rust' or 'python')"
              exit 1
            fi
          '';
        };
      }
    );
}

