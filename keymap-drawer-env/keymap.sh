#!/bin/sh
SCRIPTDIR=$(dirname "$(realpath "$0")")

uv run keymap parse -z "$(realpath "$SCRIPTDIR/../boards/shields/yk_do52pro/yk_do52pro.keymap")" >keymap.yaml

uv run keymap draw \
  --dts-layout "$(realpath "$SCRIPTDIR/../boards/shields/yk_do52pro/yk_do52pro-layouts.dtsi")" \
  keymap.yaml >keymap.svg
