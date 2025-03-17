{
  description = "MOFA hybrid Rust + Python project as a Nix flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay.url = "github:oxalica/rust-overlay";
    poetry2nix.url = "github:nix-community/poetry2nix";
  };

  outputs = { self, nixpkgs, flake-utils, rust-overlay, poetry2nix }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlays = [ rust-overlay.overlays.default ];
        pkgs = import nixpkgs { inherit system overlays; };
        poetry2nixLib = poetry2nix.lib.mkPoetry2Nix { inherit pkgs; };

        rustToolchain = pkgs.rust-bin.stable.latest.default;

        pythonEnv = poetry2nixLib.mkPoetryEnv {
          projectDir = ./python;
          python = pkgs.python312;
          extras = [ "all" ];
          preferWheels = true;
        };

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

