{
  description = "LuaJIT development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = import nixpkgs {inherit system;};

        luajit = pkgs.stdenv.mkDerivation {
          name = "luajit";
          src = pkgs.fetchgit {
            url = "https://github.com/LuaJIT/LuaJIT.git";
            sha256 = "sha256-NfxPe0MlE7X7YzVeN7jeHeOJ0j9NOUbQv7y3rcyc1Nk=";
          };

          buildInputs = [pkgs.makeWrapper];

          makeFlags = ["PREFIX=$(out)"];

          installPhase = ''
            make install PREFIX=$out
            ln -sf $out/bin/luajit-2.1.ROLLING $out/bin/luajit
          '';
        };
      in {
        devShells.default = pkgs.mkShell {
          buildInputs = [luajit];
        };
      }
    );
}
