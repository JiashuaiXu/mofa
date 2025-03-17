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

        pythonEnv = pkgs.python311.withPackages (ps: with ps; [
          torch
          scipy
          imageio
          opencv4
          matplotlib
          numpy
          tqdm
          transformers
          # 这里根据你的 python/requirements.txt 增减
        ]);
      in
      {
        devShell = pkgs.mkShell {
          buildInputs = [
            rustToolchain
            pkgs.cargo
            pythonEnv
            pkgs.maturin  # Rust 和 Python 混合项目常用的构建工具
          ];

          shellHook = ''
            echo "Rust + Python hybrid dev environment activated!"
          '';
        };

        # 可以定义 nix run 来跑 Rust 或 Python 项目
        packages.default = pkgs.writeShellApplication {
          name = "mofa";
          runtimeInputs = [ pythonEnv rustToolchain ];
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

