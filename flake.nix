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
      url = "github:nix-community/zephyr-nix";
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
        {
          system,
          pkgs,
          inputs',
          ...
        }:
        let
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
          _module.args.pkgs = import inputs.nixpkgs {
            inherit system;
            config = {
              allowUnfreePredicate =
                pkg:
                builtins.elem (inputs.nixpkgs.lib.getName pkg) [
                  "nrf-command-line-tools"
                  "segger-jlink"
                ];
              segger-jlink.acceptLicense = true;
              permittedInsecurePackages = [
                "segger-jlink-qt4-874"
              ];
            };
          };

          devShells.default = pkgs.mkShell {
            packages = [
              (zephyr.sdk-0_16.override {
                targets = [
                  "arm-zephyr-eabi"
                ];
              })
              (zephyr.pythonEnv.override {
                extraPackages = ps: [
                  ps.setuptools
                  ps.protobuf
                  ps.grpcio-tools
                ];
              })
              # Use zephyr.hosttools-nix to use nixpkgs built tooling instead of official Zephyr binaries
              zephyr.hosttools-nix
              pkgs.protobuf
              pkgs.nanopb
              pkgs.cmake
              pkgs.ninja
              pkgs.uv
              pkgs.gcc-arm-embedded
              pkgs.nrf-command-line-tools
              venv
            ];
            CMAKE_EXPORT_COMPILE_COMMANDS = "ON";
            CMAKE_GENERATOR = "Ninja";
          };
        };
    };
}
