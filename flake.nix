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
            rev = "2460b3ff93a1c955de3d62cfc825de7d68dc272e";
            sha256 = "sha256-nAj0HL7gBsfy0IKKilhgoczu9Vl36i1xp3LvzXAyr4c=";
          };

          buildInputs = [pkgs.makeWrapper];

          makeFlags = ["PREFIX=$(out)" "XCFLAGS=-DLUAJIT_ENABLE_LUA52COMPAT" "BUILDMODE=static"];

          buildPhase = ''
            make amalg PREFIX=$out XCFLAGS="-DLUAJIT_ENABLE_LUA52COMPAT" BUILDMODE=static
          '';

          installPhase = ''
            make install PREFIX=$out
            ln -sf $out/bin/luajit-2.1.ROLLING $out/bin/luajit
          '';
        };

      in {
        packages = {
          inherit luajit;
        };

        devShells.default = pkgs.mkShell {
          buildInputs = [luajit];
        };
      }
    );
}
