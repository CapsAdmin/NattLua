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

        luajit_tarantool = pkgs.stdenv.mkDerivation {
          name = "luajit-tarantool";
          src = pkgs.fetchgit {
            url = "https://github.com/tarantool/luajit.git";
            rev = "577aa3211de01b1e0a7fcacb4f4efaa078f343cb";
            sha256 = "sha256-Q9ChYstOw/YbkaI7DnxsIVKarlKj8J1l+qAIxtpqOlQ=";
          };

          nativeBuildInputs = with pkgs; [
            cmake
            git
            pkg-config
          ];

          # Patch CMakeLists.txt to remove test directory
          preConfigure = ''
            # Remove the test directory include from CMakeLists.txt
            sed -i '/add_subdirectory(test)/d' CMakeLists.txt
            # Also remove LUAJIT_USE_TEST code block
            sed -i '/if(LUAJIT_USE_TEST)/,/endif()/d' CMakeLists.txt
          '';

          cmakeFlags = [
            "-DCMAKE_BUILD_TYPE=Release"
            "-DBUILDMODE=mixed"
            "-DLUAJIT_NUMMODE="
            ""
            "-DLUAJIT_DISABLE_FFI=OFF"
            "-DLUAJIT_ENABLE_LUA52COMPAT=ON" # default OFF
            "-DLUAJIT_DISABLE_JIT=OFF"
            "-DLUAJIT_ENABLE_GC64=ON" # default oFF
            "-DLUAJIT_ENABLE_CHECKHOOK=OFF"
            "-DLUAJIT_DISABLE_UNWIND_JIT=OFF"
            "-DLUAJIT_NO_UNWIND=OFF"
            "-DLUAJIT_DISABLE_MEMPROF=OFF"
            "-DLUAJIT_DISABLE_SYSPROF=OFF"
            "-DLUAJIT_SMART_STRINGS=ON"
            "-DLUAJIT_USE_SYSMALLOC=OFF"
            "-DLUAJIT_USE_VALGRIND=OFF"
            "-DLUAJIT_USE_GDBJIT=OFF"
            "-DLUA_USE_APICHECK=OFF"
            "-DLUA_USE_ASSERT=OFF"
            "-DLUAJIT_USE_ASAN=OFF"
            "-DLUAJIT_USE_UBSAN=OFF"
            "-DLUAJIT_ENABLE_COVERAGE=OFF"
            "-DLUAJIT_ENABLE_TABLE_BUMP=OFF"
            #"-DLUAJIT_USE_TEST=OFF" # default OFF, have to patch out tests, see above
          ];

          # Create the luajit_tarantool binary
          postInstall = ''
            mv $out/bin/luajit $out/bin/luajit_tarantool
          '';

          meta = with pkgs.lib; {
            description = "Tarantool fork of LuaJIT";
            homepage = "https://github.com/tarantool/luajit";
            license = licenses.mit;
            platforms = platforms.unix;
          };
        };
      in {
        packages = {
          inherit luajit luajit_tarantool;
        };

        devShells.default = pkgs.mkShell {
          buildInputs = [luajit luajit_tarantool];
        };
      }
    );
}
