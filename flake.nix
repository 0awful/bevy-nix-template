{
  description = "A Nix flake for Bevy game development";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, rust-overlay, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs {
          inherit system overlays;
        };

        # Rust toolchain with stable channel and extra targets if needed
        rustToolchain = pkgs.rust-bin.stable.latest.default.override {
          extensions = [ "rust-src" "rust-analyzer" ];
        };

        # Bevy dependencies
        bevyDeps = with pkgs; [
          # Graphics dependencies
          libGL
          vulkan-loader
          vulkan-headers
          vulkan-tools
          vulkan-validation-layers

          # CPU fallback for vulkan
          mesa
          
          # X11 dependencies
          xorg.libX11
          xorg.libXcursor
          xorg.libXrandr
          xorg.libXi
          
          # Wayland dependencies (for Linux Wayland support)
          wayland
          
          # Audio dependencies
          alsa-lib
          pkg-config
          
          # Other dependencies
          udev
          libudev0-shim
          
          # Development tools
          cmake
          clang
          lld # Fast linker
          
          # For optional features
          libxkbcommon
          
          # Debug tools
          gdb
        ];

        # This is the development shell environment
        devShell = pkgs.mkShell {
          buildInputs = [
            rustToolchain
          ] ++ bevyDeps;

         shellHook = ''
  export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:${pkgs.lib.makeLibraryPath bevyDeps}"
  export RUSTFLAGS="-C link-arg=-fuse-ld=lld"
  export RUST_BACKTRACE=1

  echo "Bevy development environment loaded!"
'';
        };

        # This creates a derivation to build your game
        bevyGame = pkgs.rustPlatform.buildRustPackage {
          pname = "bevy-game";
          version = "0.1.0";
          src = ./.;
          
          nativeBuildInputs = with pkgs; [
            pkg-config
            rustToolchain
            cmake
          ];
          
          buildInputs = bevyDeps;
          
          # Add any environment variables needed for building
          env = {
            LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath bevyDeps;
          };
          
          # Allow dependencies to be fetched during build
          cargoLock = {
            lockFile = ./Cargo.lock;
            allowBuiltinFetchGit = true;
          };
        };

      in
      {
        # Development shell
        devShells.default = devShell;

        # Packages
        packages = {
          default = bevyGame;
        };
      }
    );
}
