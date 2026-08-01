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
            rev = "4886b676a698acc4bbdf54adfabb3e33a8c020e8";
            sha256 = "sha256-02MMi/k1B6Ot0wgMn64jASGPjloytpxEH7h73+Ll90s=";
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
