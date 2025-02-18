{
  # Initially from https://github.com/adisbladis/zephyr-nix
  description = "Zephyr flake for building the keyboard";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-parts.url = "github:hercules-ci/flake-parts";

    # Customize the version of Zephyr used by the flake here
    zephyr = {
      url = "github:zmkfirmware/zephyr/v3.5.0+zmk-fixes";
      flake = false;
    };

    zephyr-nix = {
      url = "github:adisbladis/zephyr-nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.zephyr.follows = "zephyr";
    };
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      perSystem =
        { inputs', ... }:
        let
          pkgs = inputs'.nixpkgs.legacyPackages;
          zephyr = inputs'.zephyr-nix.packages;
        in
        {
          devShells.default = pkgs.mkShell {
            packages = [
              (zephyr.sdk.override {
                targets = [
                  "arm-zephyr-eabi"
                ];
              })
              zephyr.pythonEnv
              # Use zephyr.hosttools-nix to use nixpkgs built tooling instead of official Zephyr binaries
              zephyr.hosttools-nix
              pkgs.cmake
              pkgs.ninja
              pkgs.uv
              pkgs.gcc-arm-embedded
            ];
            CMAKE_EXPORT_COMPILE_COMMANDS = "ON";
            CMAKE_GENERATOR = "Ninja";
          };
        };
    };
}
