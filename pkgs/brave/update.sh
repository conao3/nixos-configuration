#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

latest=$(gh api 'repos/brave/brave-browser/releases?per_page=100' \
  --jq '[.[] | select(.draft == false and .prerelease == false and (.name | test("^Release ")))][0].tag_name')
latest=${latest#v}
current=$(sed -n 's/^  version = "\(.*\)";$/\1/p' default.nix)

if [ -z "$latest" ] || [ -z "$current" ]; then
  echo "error: version not found (latest='$latest' current='$current')" >&2
  exit 1
fi

if [ "$latest" = "$current" ]; then
  echo "brave: up to date ($current)"
  exit 0
fi

if [ "$(printf '%s\n%s\n' "$current" "$latest" | sort -V | tail -1)" != "$latest" ]; then
  echo "error: latest release $latest is older than $current" >&2
  exit 1
fi

url="https://github.com/brave/brave-browser/releases/download/v${latest}/brave-browser_${latest}_amd64.deb"
hash=$(nix store prefetch-file --json "$url" | jq -r .hash)

sed -i \
  -e "s|^  version = \"$current\";$|  version = \"$latest\";|" \
  -e "s|^        hash = \"sha256-.*\";$|        hash = \"$hash\";|" \
  default.nix

echo "brave: $current -> $latest"
