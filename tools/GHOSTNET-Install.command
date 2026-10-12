#!/bin/bash
set -e
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
exec /bin/bash "$root/GHOSTNET-Install.sh" "$@"
