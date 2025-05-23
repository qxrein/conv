{
  description = "Native MD to PDF converter in D";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        packages.default = pkgs.stdenv.mkDerivation {
          name = "conv";
          src = ./.;

          nativeBuildInputs = [ pkgs.ldc ];

          buildPhase = ''
            ldc2 -O -release -of=conv src/conv.d
          '';

          installPhase = ''
            mkdir -p $out/bin
            cp conv $out/bin/
          '';
        };

        devShells.default = pkgs.mkShell {
          buildInputs = [ pkgs.ldc ];
        };
      });
}
