let
  nixpkgs = import <nixpkgs> {};

  luajitSrc = nixpkgs.fetchgit {
    url = "https://github.com/LuaJIT/LuaJIT.git";
    sha256 = "sha256-oMq/Ep1a4NolTrMXriitDNSjwQmwxXfKX0YrmaCQdVc=";
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
