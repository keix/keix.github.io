{
  description = "keix.github.io — built by moonquakes";

  inputs = {
    # The Lua runtime that builds the site, pinned by flake.lock.
    moonquakes = {
      url = "github:keix/moonquakes";
      flake = true;
    };
    # Use exactly the nixpkgs and Zig that moonquakes itself is developed with.
    nixpkgs.follows = "moonquakes/nixpkgs";
    zigpkgs.follows = "moonquakes/zigpkgs";
  };

  outputs = { self, nixpkgs, zigpkgs, moonquakes }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];
      forAll = f: nixpkgs.lib.genAttrs systems (system: f (import nixpkgs {
        inherit system;
        overlays = [ zigpkgs.overlays.default ];
      }));
    in {
      packages = forAll (pkgs: rec {
        moonquakes-bin = pkgs.stdenv.mkDerivation {
          pname = "moonquakes";
          version = "0.4.0-${moonquakes.shortRev or "dirty"}";
          src = moonquakes;
          nativeBuildInputs = [ pkgs.zigpkgs."0.15.2" ]
            ++ pkgs.lib.optional pkgs.stdenv.isLinux pkgs.autoPatchelfHook;
          dontConfigure = true;
          dontInstall = true;
          # In the sandbox Zig cannot detect the host libc and falls back to musl's
          # loader path. Target glibc explicitly and let autoPatchelf point the
          # binary at nixpkgs' loader; staying dynamic keeps package.loadlib usable.
          zigTarget = pkgs.lib.optionalString pkgs.stdenv.isLinux
            "-Dtarget=${pkgs.stdenv.hostPlatform.parsed.cpu.name}-linux-gnu";
          buildPhase = ''
            export ZIG_GLOBAL_CACHE_DIR=$TMPDIR/zig-global-cache
            export ZIG_LOCAL_CACHE_DIR=$TMPDIR/zig-local-cache
            zig build -Doptimize=ReleaseSafe $zigTarget --prefix $out
          '';
          buildInputs = pkgs.lib.optional pkgs.stdenv.isLinux pkgs.stdenv.cc.libc;
        };

        site = pkgs.stdenv.mkDerivation {
          name = "keix-github-io";
          src = pkgs.lib.cleanSource ./.;
          nativeBuildInputs = [ moonquakes-bin ];
          dontConfigure = true;
          MOONQUAKES_VERSION = moonquakes-bin.version;
          buildPhase = "moonquakes build.lua _site";
          installPhase = "cp -R _site $out";
        };

        default = site;
      });

      devShells = forAll (pkgs: {
        default = pkgs.mkShell {
          packages = [
            self.packages.${pkgs.stdenv.hostPlatform.system}.moonquakes-bin
            pkgs.lua5_4 # reference implementation for `make check`
            pkgs.python3 # `make serve`
            pkgs.gnumake
          ];
          MOONQUAKES_VERSION = self.packages.${pkgs.stdenv.hostPlatform.system}.moonquakes-bin.version;
        };
      });
    };
}
