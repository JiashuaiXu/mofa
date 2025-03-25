{
  description = "NixOS 24.11 with Python uv and Rust nightly with cowsay banner";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay.url = "github:oxalica/rust-overlay";
  };

  outputs = { self, nixpkgs, flake-utils, rust-overlay }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ rust-overlay.overlays.default ];
        };

        rustNightly = pkgs.rust-bin.nightly.latest.default;
        pythonWithUv = pkgs.python3.withPackages (ps: with ps; [ uv ]);

      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = [
            pythonWithUv
            rustNightly
            pkgs.pkg-config
            pkgs.openssl
            pkgs.cowsay
            pkgs.lolcat
          ];

          shellHook = ''
            # 获取版本信息
            PY_VERSION=$(python --version 2>&1)
            UV_VERSION=$(uv --version 2>&1)
            RUST_VERSION=$(rustc --version 2>&1)

            # 组合输出内容
            MESSAGE="🐍 $PY_VERSION\n🔧 $UV_VERSION\n🦀 $RUST_VERSION"

            echo -e "$MESSAGE" | cowsay -f dragon | lolcat
          '';
        };
      });
}

