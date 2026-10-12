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
# No system changes, downloads or package-manager bootstrap.
mkdir -p -- "$prefix/bin" "$prefix/share/ghostnet"
for script in ban.sh ban-ru.sh; do
    install -m 755 "$payload_root/$script" "$prefix/share/ghostnet/$script"
done
for command in ghostnet ghostnet-ru; do
    install -m 755 "$root/$command" "$prefix/bin/$command"
done
printf 'Installed GHOSTNET into %s\n' "$prefix"
printf 'Add %s/bin to PATH, then run: ghostnet\n' "$prefix"
