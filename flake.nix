{
  description = "MOFA hybrid Rust + Python project as a Nix flake with uv";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay.url = "github:oxalica/rust-overlay";
  };

  outputs = { self, nixpkgs, flake-utils, rust-overlay }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlays = [ rust-overlay.overlays.default ];
        pkgs = import nixpkgs { inherit system overlays; };

        rustToolchain = pkgs.rust-bin.stable.latest.default;

        pythonEnv = pkgs.python312.withPackages (ps: [
          ps.uv # uv 替代 pip
        ]);

        rustEnv = pkgs.symlinkJoin {
          name = "rust-env-with-dora";
          paths = [ rustToolchain pkgs.cargo ];
          buildInputs = [ pkgs.stdenv.cc.cc.lib pkgs.makeWrapper ];
          postBuild = ''
            mkdir -p $out/bin
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
            pkgs.lolcat
            pkgs.stdenv.cc.cc # for libstdc++.so.6
          ];

          shellHook = ''
            export PATH="$HOME/.cargo/bin:$PATH"
            export COWSAY="$(which cowsay)"
            export COWFILE=$(ls ${pkgs.cowsay}/share/cowsay/cows | shuf -n1)
            cowsay -f "$COWFILE" "Rust + Python hybrid dev environment with uv activated!" | lolcat

            echo "[uv] Installing python requirements..."
            uv pip install --no-cache -r ${toString ./python}/requirements.txt

            if ! command -v dora >/dev/null 2>&1; then
              cargo install dora-cli
            fi

            echo "[✔] Environment ready!"
            rustc --version
            cargo --version
            dora --version
            python --version
            uv --version
          '';
        };

        packages.default = pkgs.writeShellApplication {
          name = "mofa";
          runtimeInputs = [ pythonEnv rustEnv ];
          text = ''
            echo "Usage: nix run .#mofa -- <rust|python> [args...]"
            if [ "$1" = "rust" ]; then
              shift
              cargo run --manifest-path=./rust/Cargo.toml -- "$@"
            elif [ "$1" = "python" ]; then
              shift
              python ./python/main.py "$@"
            else
              echo "Unknown target: $1 (use 'rust' or 'python')"
              exit 1
            fi
          '';
        };
      }
    );
}

