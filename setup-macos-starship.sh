#!/usr/bin/env bash

set -u

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
STARSHIP_SOURCE="$SCRIPT_DIR/starship-powerlevel10k.toml"
TARGET_STARSHIP_CONFIG="$HOME/.config/starship.toml"
DRY_RUN=${DRY_RUN:-0}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  PROMPT_VARIANT=starship bash "$SCRIPT_DIR/setup-macos.sh" "$@"
  exit 0
fi

PROMPT_VARIANT=starship bash "$SCRIPT_DIR/setup-macos.sh" "$@"
setup_status=$?

if [ "$setup_status" -ne 0 ]; then
  exit "$setup_status"
fi

if [ "$DRY_RUN" = "1" ]; then
  printf '[dry-run] install Starship config to %s\n' "$TARGET_STARSHIP_CONFIG"
  printf '[dry-run] ensure STARSHIP_CONFIG is set in %s\n' "$HOME/.zshrc"
  exit 0
fi

mkdir -p "$HOME/.config"

if [ -f "$TARGET_STARSHIP_CONFIG" ]; then
  cp "$TARGET_STARSHIP_CONFIG" "$TARGET_STARSHIP_CONFIG.bak.$(date +%Y%m%d%H%M%S)"
fi

cp "$STARSHIP_SOURCE" "$TARGET_STARSHIP_CONFIG"

if ! grep -Fqx 'export STARSHIP_CONFIG="$HOME/.config/starship.toml"' "$HOME/.zshrc" 2>/dev/null; then
  printf '\n%s\n' 'export STARSHIP_CONFIG="$HOME/.config/starship.toml"' >>"$HOME/.zshrc"
fi

printf 'Installed Starship config to %s\n' "$TARGET_STARSHIP_CONFIG"
