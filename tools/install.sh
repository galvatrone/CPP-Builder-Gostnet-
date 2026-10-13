#!/usr/bin/env bash
set -euo pipefail
prefix="${HOME}/.local"
case "${1:-}" in
    --prefix) [[ $# -eq 2 && -n "$2" ]] || { printf 'Usage: bash install.sh [--prefix PATH]\n' >&2; exit 2; }; prefix="$2" ;;
    '') ;;
    *) printf 'Usage: bash install.sh [--prefix PATH]\n' >&2; exit 2 ;;
esac
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
payload_root="$root"
[[ -f "$payload_root/ban.sh" ]] || payload_root="$root/.."
# Stage complete payloads and switch metadata atomically; no downloads or tasks here.
python3 "$root/ghostnet-update.py" --root "$prefix" install --source "$payload_root" --helpers "$root"
printf 'Add %s/bin to PATH, then run: ghostnet\n' "$prefix"
