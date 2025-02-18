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
      inputs = {
        nixpkgs.follows = "nixpkgs";
        zephyr.follows = "zephyr";
        pyproject-nix.follows = "pyproject-nix";
      };
    };

    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs = {
        pyproject-nix.follows = "pyproject-nix";
        nixpkgs.follows = "nixpkgs";
      };
    };

    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs = {
        pyproject-nix.follows = "pyproject-nix";
        uv2nix.follows = "uv2nix";
        nixpkgs.follows = "nixpkgs";
      };
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

          # adafruit-nrfutil-env
          # https://github.com/FerranAD/simple-uv2nix/blob/main/flake.nix
          workspaceRoot = ./adafruit-nrfutil-env;
          python = pkgs.python313;
          workspace = inputs.uv2nix.lib.workspace.loadWorkspace {
            inherit workspaceRoot;
          };
          overlay = workspace.mkPyprojectOverlay {
            sourcePreference = "wheel";
          };
          baseSet = pkgs.callPackage inputs.pyproject-nix.build.packages {
            inherit python;
          };
          # Add overrides to base set, due to Python lock files not including
          # build system, see https://github.com/astral-sh/uv/issues/5190
          pythonSet = baseSet.overrideScope (
            pkgs.lib.composeManyExtensions [
              # A set of pre-made overrides
              inputs.pyproject-build-systems.overlays.default
              # uv2nix overlay
              overlay
              (final: prev: {
                adafruit-nrfutil = prev.adafruit-nrfutil.overrideAttrs (old: {
                  nativeBuildInputs = old.nativeBuildInputs ++ [
                    (final.resolveBuildSystem {
                      setuptools = [ ];
                    })
                  ];
                });
              })
            ]
          );
          venv = pythonSet.mkVirtualEnv "venv" workspace.deps.default;
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
              venv
            ];
            CMAKE_EXPORT_COMPILE_COMMANDS = "ON";
            CMAKE_GENERATOR = "Ninja";
          };
        };
    };
}
