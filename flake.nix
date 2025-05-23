{
  description = "MD to PDF converter in D (WASM)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        ldc = pkgs.ldc.overrideAttrs (old: {
          cmakeFlags = (old.cmakeFlags or []) ++ ["-DLDC_EXPERIMENTAL_WASM=ON"];
        });
      in
      {
        packages.default = pkgs.stdenv.mkDerivation {
          name = "conv";
          src = ./source;

          nativeBuildInputs = [
            ldc
            pkgs.dub
            pkgs.binaryen
          ];

          buildPhase = ''
            dub build --compiler=ldc2 --build=release --arch=wasm32-unknown-unknown-wasm
          '';

          installPhase = ''
            mkdir -p $out/bin
            cp conv.wasm $out/bin/conv.wasm
            echo '#!/bin/sh' > $out/bin/conv
            echo '${pkgs.wasmtime}/bin/wasmtime run $out/bin/conv.wasm "$@"' >> $out/bin/conv
            chmod +x $out/bin/conv
          '';
        };

        devShells.default = pkgs.mkShell {
          buildInputs = [
            ldc
            pkgs.dub
            pkgs.binaryen
            pkgs.wasmtime
          ];
        };
      });
}
