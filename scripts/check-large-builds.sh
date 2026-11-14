#!/usr/bin/env bash
set -euo pipefail

# Read Nix's raw dry-run output. Substitution paths have no .drv suffix.
blocked=()
while IFS= read -r line; do
  if [[ "$line" =~ ^[[:space:]]*/nix/store/[a-z0-9]+-(zed-editor|telegram-desktop|llvm|clang|webkitgtk|chromium|firefox|llama-cpp)(-[^[:space:]]*)?\.drv$ ]]; then
    blocked+=("$line")
  fi
done
if (( ${#blocked[@]} )); then
  printf 'Refusing large source builds; use cached packages instead:\n' >&2
  printf '%s\n' "${blocked[@]}" >&2
  exit 1
fi
