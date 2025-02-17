{
  # Initially from https://github.com/adisbladis/zephyr-nix
  description = "Zephyr flake for building the keyboard";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

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
    {
      nixpkgs,
      zephyr-nix,
      ...
    }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      zephyr = zephyr-nix.packages.x86_64-linux;
    in
    {
      devShells.x86_64-linux.default = pkgs.mkShell {
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
        ];
      };
    };
}
