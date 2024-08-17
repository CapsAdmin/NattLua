let
  nixpkgs = import <nixpkgs> {};

  luajitSrc = nixpkgs.fetchgit {
    url = "https://github.com/LuaJIT/LuaJIT.git";
    sha256 = "sha256-QACbFPR3VH7NkUYXhG+g2T2+Uw4C8X1N6D2CBK7c9rA=";
  };

  luajit = nixpkgs.stdenv.mkDerivation {
    name = "luajit";
    src = luajitSrc;

    buildInputs = [ nixpkgs.makeWrapper ];

    makeFlags = [ "PREFIX=$(out)" ];

    installPhase = ''
      make install PREFIX=$out
      ln -sf $out/bin/luajit-2.1.0-beta3 $out/bin/luajit
    '';
  };
  
in
nixpkgs.mkShell {
  buildInputs = [ luajit ];
}
