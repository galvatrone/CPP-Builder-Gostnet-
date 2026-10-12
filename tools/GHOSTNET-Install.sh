#!/bin/bash
# Runs on macOS system Bash 3.2 before modern Bash is installed.
set -euo pipefail
VERSION=v1.2.0
REPOSITORY=https://github.com/galvatrone/CPP-Builder-Gostnet-
prefix="${HOME}/.local"
yes=0; launch=1; remote=0
usage() {
    printf '%s\n' 'GHOSTNET installer: Linux / macOS' \
        'Usage: bash GHOSTNET-Install.sh [--yes] [--no-launch] [--prefix PATH] [--version vX.Y.Z]' \
        'An extracted ZIP or repository installs its local payload; a downloaded single file downloads a verified release.'
}
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
while [[ $# -gt 0 ]]; do
    case "$1" in
        --yes) yes=1; shift ;;
        --no-launch) launch=0; shift ;;
        --prefix|--version)
            [[ $# -ge 2 && -n "$2" ]] || fail "Missing value for $1"
            if [[ "$1" == --prefix ]]; then prefix="$2"; else VERSION="$2"; remote=1; fi
            shift 2 ;;
        --help|-h) usage; exit 0 ;;
        *) fail "Unknown option: $1" ;;
    esac
done
[[ "$VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail 'Use a stable version tag: vX.Y.Z'
[[ "$prefix" == /* && "$prefix" != / && "$prefix" != *$'\n'* ]] || fail 'Prefix must be an absolute directory path (other than /).'
case "$(uname -s)" in
    Linux) platform=linux ;;
    Darwin) platform=macos ;;
    *) fail 'Use GHOSTNET-Install.cmd in Windows PowerShell/CMD; this installer supports Linux and macOS.' ;;
esac
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
payload="$root"; helper="$root/install.sh"
if [[ ! -f "$payload/ban.sh" && -f "$root/../ban.sh" ]]; then payload="$root/.."; fi
if [[ ! -f "$payload/ban.sh" || ! -f "$helper" ]]; then remote=1; fi
printf 'GHOSTNET installer — %s (%s)\n' "$platform" "$VERSION"
printf 'Install command into: %s/bin\n' "$prefix"
if [[ "$yes" -eq 0 ]]; then
    [[ -t 0 ]] || fail 'Interactive confirmation required. Use --yes for unattended installation.'
    printf 'Install GHOSTNET, missing build tools and user shell PATH settings? [y/N] '
    read -r answer
    case "$answer" in y|Y|yes|YES) ;; *) printf 'Cancelled.\n'; exit 0 ;; esac
fi
admin() {
    if [[ "$(id -u)" == 0 ]]; then "$@"; else
        command -v sudo >/dev/null 2>&1 || fail 'sudo is required to install missing system packages.'
        sudo "$@"
    fi
}
modern_bash() { "$1" -c '(( BASH_VERSINFO[0] > 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] >= 4) ))' >/dev/null 2>&1; }
if [[ "$platform" == linux ]]; then
    packages=()
    if command -v apt-get >/dev/null 2>&1; then manager=apt
    elif command -v dnf >/dev/null 2>&1; then manager=dnf
    elif command -v pacman >/dev/null 2>&1; then manager=pacman
    else manager=none; fi
    for tool in bash curl g++ python3 rustc cargo cmake ninja make; do
        missing=0
        command -v "$tool" >/dev/null 2>&1 || missing=1
        if [[ "$tool" == bash && "$missing" -eq 0 ]]; then modern_bash "$(command -v bash)" || missing=1; fi
        [[ "$missing" -eq 1 ]] || continue
        package="$tool"
        case "$manager:$tool" in
            apt:rustc) package=rustc ;; apt:ninja) package=ninja-build ;;
            dnf:g++) package=gcc-c++ ;; dnf:rustc) package=rust ;; dnf:ninja) package=ninja-build ;;
            pacman:g++) package=gcc ;; pacman:python3) package=python ;;
            pacman:rustc|pacman:cargo) package=rust ;;
        esac
        packages+=("$package")
    done
    if [[ "${#packages[@]}" -gt 0 ]]; then
        printf 'Installing missing dependencies: %s\n' "${packages[*]}"
        case "$manager" in
            apt) admin apt-get update; admin apt-get install -y "${packages[@]}" ;;
            dnf) admin dnf install -y "${packages[@]}" ;;
            pacman) admin pacman -Syu --needed --noconfirm "${packages[@]}" ;;
            *) fail 'Supported automatic package managers: apt, dnf, pacman. Install the listed tools manually and rerun.' ;;
        esac
    fi
else
    brew_bin="$(command -v brew || true)"
    for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew; do
        [[ -n "$brew_bin" ]] || { [[ ! -x "$candidate" ]] || brew_bin="$candidate"; }
    done
    if [[ -z "$brew_bin" ]]; then
        command -v curl >/dev/null 2>&1 || fail 'curl is required to bootstrap Homebrew.'
        brew_installer=$(mktemp "${TMPDIR:-/tmp}/ghostnet-homebrew.XXXXXX")
        # Homebrew owns its bootstrap and handles Apple's command line tools.
        if ! curl --fail --show-error --location --proto '=https' --tlsv1.2 \
            https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o "$brew_installer"; then
            rm -f -- "$brew_installer"; fail 'Homebrew download failed.'
        fi
        if [[ "$yes" -eq 1 ]]; then export NONINTERACTIVE=1; fi
        if ! /bin/bash "$brew_installer"; then
            rm -f -- "$brew_installer"; fail 'Homebrew installation failed; complete its instructions and rerun.'
        fi
        rm -f -- "$brew_installer"
        for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew; do
            [[ ! -x "$candidate" ]] || brew_bin="$candidate"
        done
        [[ -n "$brew_bin" ]] || fail 'Homebrew was not found after installation.'
    fi
    export PATH="$("$brew_bin" --prefix)/bin:$PATH"
    if ! xcode-select -p >/dev/null 2>&1; then
        xcode-select --install || true
        fail 'Finish the Apple command line tools installation dialog, then rerun this installer.'
    fi
    packages=()
    for tool in bash python3 rustc cargo cmake ninja make; do
        missing=0
        command -v "$tool" >/dev/null 2>&1 || missing=1
        if [[ "$tool" == bash && "$missing" -eq 0 ]]; then modern_bash "$(command -v bash)" || missing=1; fi
        [[ "$missing" -eq 1 ]] || continue
        case "$tool" in python3) packages+=(python) ;; rustc|cargo) packages+=(rust) ;; *) packages+=("$tool") ;; esac
    done
    [[ "${#packages[@]}" -eq 0 ]] || "$brew_bin" install "${packages[@]}"
    export PATH="$("$brew_bin" --prefix bash 2>/dev/null || "$brew_bin" --prefix)/bin:$PATH"
fi
for tool in bash curl g++ python3 rustc cargo cmake ninja make; do
    command -v "$tool" >/dev/null 2>&1 || fail "Dependency unavailable after installation: $tool"
done
selected_bash=$(command -v bash)
modern_bash "$selected_bash" || fail 'GHOSTNET needs Bash 4.4 or newer.'
stage=''
cleanup() { [[ -z "$stage" ]] || rm -rf -- "$stage"; }
trap cleanup EXIT
if [[ "$remote" -eq 1 ]]; then
    stage=$(mktemp -d "${TMPDIR:-/tmp}/ghostnet-release.XXXXXX")
    archive="ghostnet-$platform.zip"
    base="$REPOSITORY/releases/download/$VERSION"
    for file in "$archive" SHA256SUMS; do
        curl --fail --show-error --location --proto '=https' --tlsv1.2 "$base/$file" -o "$stage/$file"
    done
    python3 - "$stage" "$archive" <<'PY'
import hashlib, pathlib, re, stat, sys, zipfile
stage=pathlib.Path(sys.argv[1]); name=sys.argv[2]
lines=(stage/'SHA256SUMS').read_text().splitlines()
matches=[re.fullmatch(r'([a-fA-F0-9]{64})\s+\*?'+re.escape(name),line) for line in lines]
expected=[m.group(1).lower() for m in matches if m]
if len(expected)!=1 or hashlib.sha256((stage/name).read_bytes()).hexdigest()!=expected[0]:
    raise SystemExit('Release SHA-256 verification failed; existing installation was not changed.')
with zipfile.ZipFile(stage/name) as z:
    names=z.namelist()
    if len(set(names))!=len(names): raise SystemExit('Duplicate archive entry.')
    for info in z.infolist():
        parts=info.filename.split('/')
        if parts[0]!='GHOSTNET' or any(p in ('.','..') for p in parts) or '\\' in info.filename or ':' in info.filename or stat.S_ISLNK(info.external_attr>>16):
            raise SystemExit('Unsafe archive entry.')
    required={'GHOSTNET/'+n for n in ('ban.sh','ban-ru.sh','ghostnet','ghostnet-ru','install.sh')}
    if not required.issubset(names): raise SystemExit('Incomplete release payload.')
    z.extractall(stage)
PY
    payload="$stage/GHOSTNET"; helper="$payload/install.sh"
fi
"$selected_bash" "$helper" --prefix "$prefix"
# Store shell-quoted paths, including spaces and apostrophes; preserve existing shell settings.
python3 - "$HOME" "$prefix" "$(dirname -- "$selected_bash")" "${brew_bin:-}" <<'PY'
import pathlib, shlex, sys
home=pathlib.Path(sys.argv[1]); prefix=pathlib.Path(sys.argv[2])
env=home/'.config/ghostnet/env.sh'; env.parent.mkdir(parents=True,exist_ok=True)
bins=[str(prefix/'bin'),sys.argv[3]]
if sys.argv[4]: bins.append(str(pathlib.Path(sys.argv[4]).parent))
env.write_text('export PATH='+shlex.quote(':'.join(dict.fromkeys(bins)))+':"$PATH"\n')
line='# GHOSTNET PATH\n[ ! -f '+shlex.quote(str(env))+' ] || . '+shlex.quote(str(env))+'\n'
files=['.profile','.bashrc','.zshrc','.zprofile']
for name in ('.bash_profile','.bash_login'):
    if (home/name).exists(): files.append(name)
for name in files:
    path=home/name
    old=path.read_text() if path.exists() else ''
    if '# GHOSTNET PATH' not in old:
        with path.open('a') as f: f.write(('\n' if old and not old.endswith('\n') else '')+line)
PY
export PATH="$prefix/bin:$PATH"
printf 'Installed. Open a new terminal and run ghostnet or ghostnet-ru.\n'
if [[ "$launch" -eq 1 ]]; then "$prefix/bin/ghostnet"; fi
