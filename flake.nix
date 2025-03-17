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

        # ---- new: use requirements.txt directly ----
        pythonEnv = pkgs.python312.withPackages (ps: [ ps.pip ]);

        # Install requirements.txt using mach-nix or pip (via shellHook)

        # ---- old: use poetry.lock ----
        # pythonEnv = poetry2nixLib.mkPoetryEnv {
        #   projectDir = ./python;
        #   python = pkgs.python312;
        #   extras = [ "all" ];
        #   preferWheels = true;
        # };

        rustEnv = pkgs.symlinkJoin {
          name = "rust-env-with-dora";
          paths = [ rustToolchain pkgs.cargo ];
          buildInputs = [ pkgs.makeWrapper ];
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
          ];

          shellHook = ''
            export COWSAY="$(which cowsay)"
            export COWTHINK="$(which cowthink)"
            export COWFILE=$(ls ${pkgs.cowsay}/share/cowsay/cows | shuf -n1)
            export COW_OPTS="-f $COWFILE"

            cowsay -f "$COWFILE" "[1;36mRust + Python hybrid dev environment activated![0m" | lolcat
            echo "Installing python requirements..."
            pip install --no-cache-dir -r ${toString ./python}/requirements.txt

            echo "Installing dora-cli via cargo..."
            if ! command -v dora >/dev/null 2>&1; then
              cargo install dora-cli
            fi

            echo "Checking python packages..."
pip check

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

