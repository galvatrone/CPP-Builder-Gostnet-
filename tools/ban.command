#!/bin/bash
# Works next to the release scripts or inside the repository tools directory.
launcher_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd) || exit 1
script="$launcher_dir/ban.sh"
[[ -f "$script" ]] || script="$launcher_dir/../ban.sh"
selected_bash=""
for candidate in /opt/homebrew/bin/bash /usr/local/bin/bash "$(command -v bash)"; do
    [[ -x "$candidate" ]] || continue
    if "$candidate" -c '(( BASH_VERSINFO[0] > 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] >= 4) ))' 2>/dev/null; then
        selected_bash="$candidate"
        break
    fi
done
if [[ -z "$selected_bash" ]]; then
    printf '%s\n' 'Bash 4.4 or newer is required. Install it with: brew install bash' >&2
    status=1
else
    # Use the same Bash for any nested shell invocations.
    export PATH="$(dirname -- "$selected_bash"):$PATH"
    "$selected_bash" "$script" "$@"
    status=$?
fi
if [[ "$status" -ne 0 && -t 0 ]]; then
    printf '\nPress any key to close... '
    read -r -n 1 _
    printf '\n'
fi
exit "$status"
