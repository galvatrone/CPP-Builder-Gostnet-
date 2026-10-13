#!/usr/bin/env bash

set -u
shopt -s nullglob

HOST_SYSTEM=$(uname -s)
case "$HOST_SYSTEM" in
    Linux) HOST_KIND="linux"; HOST_LABEL="Linux" ;;
    Darwin) HOST_KIND="macos"; HOST_LABEL="macOS" ;;
    MINGW*|MSYS*) HOST_KIND="windows"; HOST_LABEL="Windows" ;;
    *) printf '[ERROR] Unsupported system: %s\n' "$HOST_SYSTEM" >&2; exit 1 ;;
esac
if [[ "${BASH_VERSINFO[0]}" -lt 4 || ( "${BASH_VERSINFO[0]}" -eq 4 && "${BASH_VERSINFO[1]}" -lt 4 ) ]]; then
    printf '[ERROR] Bash 4.4 or newer is required. On macOS: brew install bash.\n' >&2
    exit 1
fi

ACTION="${BAN_ACTION:-}"
BUILD_TARGET="${BAN_BUILD_TARGET:-}"
WIN_METHOD="${BAN_WIN_METHOD:-}"
RUN_AFTER="${BAN_RUN_AFTER:-0}"
RUN_CHOICE_SET="${BAN_RUN_AFTER+x}"
RUN_FILE="${BAN_RUN_FILE:-}"
SOURCE_FILE="${BAN_SOURCE_FILE:-}"
TARGET_DIR_PRESET="${BAN_TARGET_DIR:-}"
TARGET_DIR=""
ASSUME_YES=0
BUILD_MODE="${BAN_BUILD_MODE:-auto}"
INTERFACE_LANG=en
INIT_TYPE=""

usage() {
    cat <<'HELP'
Commands: ghostnet build|run|test|doctor|setup|watch|clean|completion|check|inspect|languages|init|recent [options] [folder]

GHOSTNET — build helper for Linux, Windows and macOS

Run without arguments for the arrow-key menu (↑/↓, ←/→ and Enter).

  --type TYPE        Template for ghostnet init
  --check            Check required tools
  --install-deps     Install missing tools
  --auto             Check tools and build automatically
  --target TARGET    native, linux, macos, windows or both
  --mode MODE        auto, files, project, cmake, make, cargo, python, go, node, dotnet, maven, gradle, swift, zig
  --run-file PATH    Project entry point (relative to project folder)
  --run              Run the program after a successful build
  --yes              Allow package installation without another confirmation
  --no-animation     Disable animations
  --version          GHOSTNET 1.4.0
  --help             Show help

Example: bash ban.sh --auto --target linux --run ./project
Without --yes, package installation requires confirmation in a terminal.
Examples:
  ghostnet doctor .                  Diagnose tools and project dependencies
  ghostnet setup .                   Prepare project dependencies explicitly
  ghostnet run --run-file app.py .    Use the project .venv when available
  ghostnet watch .                   Restart after source changes; Ctrl+C stops
  ghostnet clean .                   Remove unchanged recorded outputs
  ghostnet completion bash           Print shell completion definitions
  ghostnet update                    Update an installed release
  ghostnet auto-update status        Show automatic update settings
HELP
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        completion) ACTION="completion" ;;
        doctor|setup|watch|clean) ACTION="$1"; TARGET_DIR_PRESET="${TARGET_DIR_PRESET:-.}" ;;
        recent) ACTION="recent" ;;
        init) ACTION="init" ;;
        --type) [[ $# -ge 2 ]] || { printf '[ERROR] --type requires a value.\n' >&2; exit 2; }; INIT_TYPE="$2"; shift ;;
        inspect) ACTION="inspect"; TARGET_DIR_PRESET="${TARGET_DIR_PRESET:-.}" ;;
        languages) ACTION="languages" ;;
        build) ACTION="build" ;;
        run) ACTION="auto"; RUN_AFTER=1; RUN_CHOICE_SET=1 ;;
        test) ACTION="test" ;;
        check) ACTION="check"; TARGET_DIR_PRESET="${TARGET_DIR_PRESET:-.}" ;;
        --check) ACTION="check" ;;
        --install-deps) ACTION="install" ;;
        --auto) ACTION="auto" ;;
        --target)
            if [[ $# -lt 2 ]]; then
                printf '[ERROR] --target requires a platform.\n' >&2
                exit 2
            fi
            BUILD_TARGET="$2"
            shift
            ;;
        --mode|--run-file)
            [[ $# -ge 2 ]] || { printf '[ERROR] %s requires a value.\n' "$1" >&2; exit 2; }
            if [[ "$1" == "--mode" ]]; then BUILD_MODE="$2"; else RUN_FILE="$2"; fi
            shift ;;
        --run) RUN_AFTER=1; RUN_CHOICE_SET=1 ;;
        --yes) ASSUME_YES=1 ;;
        --no-animation) BAN_NO_ANIMATION=1 ;;
        --version) printf 'GHOSTNET 1.4.0\n'; exit 0 ;;
        --help|-h) usage; exit 0 ;;
        --)
            shift
            if [[ $# -eq 1 && -z "$TARGET_DIR" ]]; then
                TARGET_DIR="$1"
                shift
                break
            fi
            printf '[ERROR] Specify exactly one project folder.\n' >&2
            exit 2
            ;;
        -*) printf '[ERROR] Unknown option: %s\n' "$1" >&2; exit 2 ;;
        *)
            if [[ -n "$TARGET_DIR" ]]; then
                printf '[ERROR] Specify exactly one project folder.\n' >&2
                exit 2
            fi
            TARGET_DIR="$1"
            ;;
    esac
    shift
done

case "$BUILD_MODE" in auto|files|project|cmake|make|cargo|python|go|node|dotnet|maven|gradle|swift|zig) ;; *) printf '[ERROR] Invalid build mode: %s\n' "$BUILD_MODE" >&2; exit 2 ;; esac

if [[ "$ACTION" == completion ]]; then
    case "${TARGET_DIR:-bash}" in bash) completion_file=ghostnet.bash ;; zsh) completion_file=ghostnet.zsh ;; powershell) completion_file=ghostnet.ps1 ;; *) printf '[ERROR] completion: bash, zsh, powershell\n' >&2; exit 2 ;; esac
    completion_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
    [[ -f "$completion_root/$completion_file" ]] || completion_root+="/tools"
    [[ -f "$completion_root/$completion_file" ]] || { printf '[ERROR] Download the release ZIP to use shell completion.\n' >&2; exit 1; }
    cat -- "$completion_root/$completion_file"; exit $?
fi

ANIMATION_ENABLED=0
if [[ "${BAN_NO_ANIMATION:-0}" != "1" && -t 1 && -n "${TERM:-}" && "${TERM:-}" != "dumb" ]]; then
    ANIMATION_ENABLED=1
    clear
fi

text="
 ██████╗ ██╗  ██╗ ██████╗ ███████╗████████╗███╗   ██╗███████╗████████╗
██╔════╝ ██║  ██║██╔═══██╗██╔════╝╚══██╔══╝████╗  ██║██╔════╝╚══██╔══╝
██║  ███╗███████║██║   ██║███████╗   ██║   ██╔██╗ ██║█████╗     ██║   
██║   ██║██╔══██║██║   ██║╚════██║   ██║   ██║╚██╗██║██╔══╝     ██║   
╚██████╔╝██║  ██║╚██████╔╝███████║   ██║   ██║ ╚████║███████╗   ██║   
 ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝   ╚═╝   ╚═╝  ╚═══╝╚══════╝   ╚═╝   
"

BLUE="\033[38;2;0;180;255m"
GREEN="\033[38;2;0;255;65m"
PURPLE="\033[38;2;190;60;255m"
YELLOW="\033[38;2;255;255;0m"
RED="\033[38;2;255;60;60m"
WHITE="\033[38;2;255;255;255m"
RESET="\033[0m"

if [[ "$ANIMATION_ENABLED" -eq 0 ]]; then
    BLUE="" GREEN="" PURPLE="" YELLOW="" RED="" WHITE="" RESET=""
fi

lines=(
"$BLUE  ███████████████████████████████████████████████████████████████████████$RESET"
"$GREEN █           SYSTEM BOOTING          INITIALIZING CORE                █$RESET"
"${PURPLE}█           GHOST PROTOCOL        ctOS TERMINAL  v2.7.4              █$RESET"
"$RED   ███████████████████████████████████████████████████████████████████████$RESET"
)

if [[ "$ANIMATION_ENABLED" -eq 1 ]]; then
    # Loading effect
    for i in {0..20}; do
        printf "\r${GREEN}Loading: [%-20s] %d%%${RESET}" "$(printf "#%.0s" $(seq 1 "$i"))" $((i * 5))
        sleep 0.05
    done
    sleep 0.25
    clear

    # Flicker effect
    for i in {1..5}; do
        echo -e "${RED}SYSTEM INITIALIZING...${RESET}"
        clear
        echo -e "${RED}$text${RESET}"
        sleep 0.02
        clear
        sleep 0.01
    done

    # Static glitch effect
    for i in {1..12}; do
        clear
        echo -e "${RED}SYSTEM INITIALIZING...${RESET}"
        r=$((RANDOM % 4))
        echo -e "${lines[$r]}"
        echo
        echo -e "${GREEN}$text${RESET}"
        echo
        echo -e "${lines[$r]}"
        sleep 0.045
    done

    clear
    echo -e "${GREEN}SYSTEM ONLINE${RESET}"
    echo -e "${WHITE}███████████████████████████████████████████████████████████████████████${RESET}"
    echo
    echo -e "${WHITE}${text}${RESET}"
    echo
    echo -e "${WHITE}███████████████████████████████████████████████████████████████████████${RESET}"
    echo

else
    printf 'GHOSTNET\n\n'
fi

LINUX_CXX="g++"
WIN_CXX="x86_64-w64-mingw32-g++"
WIN_CC="x86_64-w64-mingw32-gcc"
PYTHON_BIN="python3"
if [[ "$HOST_KIND" == "windows" ]]; then
    WIN_CXX="g++"
    WIN_CC="gcc"
fi
select_python() {
    if [[ "$HOST_KIND" == "windows" ]] && ! command -v python3 >/dev/null 2>&1 && command -v python >/dev/null 2>&1; then
        PYTHON_BIN="python"
    fi
}
select_python
CPP_FLAGS=(-O2 -std=c++17)
WIN_FLAGS_METHOD1=(-static -static-libgcc -static-libstdc++ -s)
# Fallback: more aggressive static link mode.
WIN_FLAGS_METHOD2=(-static -static-libgcc -static-libstdc++ -Wl,-Bstatic -lstdc++ -lgcc -lwinpthread -Wl,-Bdynamic -lws2_32 -s)

BUILD_PID=""
BUILD_LOG=""

cleanup_terminal() {
    [[ -z "${CLEAN_BASE:-}" ]] || rm -f -- "$CLEAN_BASE"
    if [[ -n "$BUILD_PID" ]]; then
        kill "$BUILD_PID" 2>/dev/null || true
        wait "$BUILD_PID" 2>/dev/null || true
    fi
    if [[ -n "$BUILD_LOG" ]]; then
        rm -f -- "$BUILD_LOG"
    fi
    if [[ -t 1 ]]; then
        tput cnorm 2>/dev/null || true
    fi
}
trap cleanup_terminal EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# Bash 5 offers microsecond timestamps; older Bash falls back to whole seconds.
build_time_ms() {
    local stamp="${EPOCHREALTIME:-$SECONDS.000000}"
    local fraction="${stamp#*.}"
    printf '%s' "$(( ${stamp%.*} * 1000 + 10#${fraction:0:3} ))"
}


diagnostic_tip() {
    local label="$1" log="$2" line tip=''
    [[ -f "$log" ]] || return 0
    while IFS= read -r line; do
        case "$line" in
            *multiple\ definition*main*|*duplicate\ symbol*main*) tip="$(ui 'Several main() functions: these may be separate programs. Try --mode files.' 'Несколько функций main(): возможно, это отдельные программы. Попробуйте --mode files.')" ;;
            *fatal\ error:*No\ such\ file*|*fatal\ error:*file\ not\ found*) tip="$(ui 'Check the header path and installed library. Describe external dependencies in CMake or Make.' 'Проверьте путь к заголовку и установленную библиотеку. Опишите внешние зависимости в CMake или Make.')" ;;
            *IndentationError*|*TabError*) tip="$(ui 'Check Python indentation; use consistent spaces instead of mixing tabs and spaces.' 'Проверьте отступы Python; не смешивайте табуляцию и пробелы.')" ;;
            *SyntaxError*) tip="$(ui 'Check the syntax at the reported file and line.' 'Проверьте синтаксис в указанном файле и строке.')" ;;
            *Cannot\ find\ module*|*TS2307*) tip="$(ui 'Install the project dependencies with its package manager (npm install / npm ci for Node).' 'Установите зависимости средствами проекта (npm install / npm ci для Node).')" ;;
            *ModuleNotFoundError*) tip="$(ui 'Activate the project virtual environment and install the required Python package there.' 'Активируйте виртуальное окружение проекта и установите нужный пакет Python в нём.')" ;;
            *tsc:*not\ found*|*tsc:*is\ not\ recognized*) tip="$(ui 'Install TypeScript in this project: npm install --save-dev typescript.' 'Установите TypeScript в проект: npm install --save-dev typescript.')" ;;
        esac
    done < "$log"
    [[ -z "$tip" ]] || printf '%b[HINT]%b %s\n' "$YELLOW" "$RESET" "$tip"
    return 0
}

save_error_report() {
    local label="$1" log="$2" status="$3" folder report tool
    shift 3
    folder="$(state_folder)/reports"
    [[ ! -L "$(state_folder)" && ! -L "$folder" ]] || return 0
    (umask 077; mkdir -p -- "$folder") 2>/dev/null || return 0
    report=$(umask 077; mktemp "$folder/error.XXXXXX") || return 0
    {
        printf 'GHOSTNET 1.4.0\nHost: %s\nProject: %s\nOperation: %s\nExit: %s\nCommand: ' "$HOST_SYSTEM" "$TARGET_DIR" "$label" "$status"
        printf '%q ' "$@"; printf '\n\nTools:\n'
        for tool in "${required_compilers[@]}"; do
            command -v "$tool" || continue
            case "${tool##*/}" in java|javac) "$tool" -version 2>&1 | head -n 1 ;; *) "$tool" --version 2>&1 | head -n 1 ;; esac
        done
        printf '\nLog:\n'; cat -- "$log"
    } > "$report" 2>&1
    printf '[REPORT] %s\n' "$report"
    return 0
}

run_build() {
    local label="$1"
    shift
    local started elapsed status frame=0
    local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    started=$(build_time_ms)

    if [[ "$ANIMATION_ENABLED" -eq 1 ]]; then
        BUILD_LOG=$(mktemp "${TMPDIR:-/tmp}/ban-build.XXXXXX") || return 1
        tput civis 2>/dev/null || true
        "$@" >"$BUILD_LOG" 2>&1 &
        BUILD_PID=$!
        while kill -0 "$BUILD_PID" 2>/dev/null; do
            elapsed=$(( $(build_time_ms) - started ))
            printf '\r\033[2K%b[%s] %s  BUILDING  %d.%ds%b' \
                "$BLUE" "${frames[$frame]}" "$label" "$((elapsed / 1000))" "$((elapsed % 1000 / 100))" "$RESET"
            frame=$(( (frame + 1) % ${#frames[@]} ))
            sleep 0.1
        done
        status=0
        wait "$BUILD_PID" || status=$?
        BUILD_PID=""
        printf '\r\033[2K'
        tput cnorm 2>/dev/null || true
    else
        status=0
        BUILD_LOG=$(mktemp "${TMPDIR:-/tmp}/ban-errors.XXXXXX" 2>/dev/null) || BUILD_LOG=""
        if [[ -n "$BUILD_LOG" ]]; then
            "$@" 2>"$BUILD_LOG" || status=$?
            cat -- "$BUILD_LOG" >&2
        else
            "$@" || status=$?
        fi
    fi

    elapsed=$(( $(build_time_ms) - started ))
    if [[ "$status" -eq 0 ]]; then
        printf '%b[✓] %s  COMPLETE  %d.%ds%b\n' "$GREEN" "$label" "$((elapsed / 1000))" "$((elapsed % 1000 / 100))" "$RESET"
    else
        printf '%b[✗] %s  FAILED  %d.%ds%b\n' "$RED" "$label" "$((elapsed / 1000))" "$((elapsed % 1000 / 100))" "$RESET"
    fi
    if [[ -n "$BUILD_LOG" ]]; then
        [[ "$ANIMATION_ENABLED" -eq 0 ]] || cat -- "$BUILD_LOG"
        [[ "$status" -eq 0 ]] || { diagnostic_tip "$label" "$BUILD_LOG"; save_error_report "$label" "$BUILD_LOG" "$status" "$@"; }
        rm -f -- "$BUILD_LOG"
        BUILD_LOG=""
    fi
    return "$status"
}

choose_menu() {
    local title="$1"
    local default_index="$2"
    shift 2
    local options=("$@")
    local selected="$default_index"
    local count="${#options[@]}"
    local i key extra

    if [[ "$count" -eq 0 ]]; then
        MENU_SELECTED=0
        return
    fi

    # Fallback for non-interactive mode (no arrows available).
    if [[ ! -t 0 || ! -t 1 ]]; then
        MENU_SELECTED="$selected"
        return
    fi

    tput civis 2>/dev/null || true
    printf "%s\n" "$title"

    while true; do
        for ((i = 0; i < count; i++)); do
            if [[ "$i" -eq "$selected" ]]; then
                printf "  ${GREEN}> %s${RESET}\n" "${options[$i]}"
            else
                printf "    %s\n" "${options[$i]}"
            fi
        done

        IFS= read -rsn1 key || exit 1
        if [[ "$key" == $'\x1b' ]]; then
            IFS= read -rsn2 -t 0.2 extra || true
            key+="$extra"
        fi

        case "$key" in
            $'\x1b[A') selected=$(( (selected - 1 + count) % count )) ;;
            $'\x1b[B') selected=$(( (selected + 1) % count )) ;;
            "") break ;;
        esac

        printf "\033[%dA\r" "$count"
    done

    MENU_SELECTED="$selected"
    tput cnorm 2>/dev/null || true
    printf "\n"
}


# Preserve action indices while grouping the main dashboard into two columns.
choose_dashboard() {
    local title="$1" selected="$2" key extra row left right pad width columns
    shift 2
    local options=("$@")
    columns=${COLUMNS:-80}
    if [[ "$columns" -lt 72 ]]; then choose_menu "$title" "$selected" "${options[@]}"; return; fi
    width=$(( (columns-6)/2 )); [[ "$width" -le 48 ]] || width=48
    tput civis 2>/dev/null || true
    printf '%s\n' "$title"
    left="$(ui 'BUILD & TOOLS' 'СБОРКА И ИНСТРУМЕНТЫ')"
    pad=$((width-${#left})); [[ "$pad" -ge 0 ]] || pad=0
    printf '%b  %s%*s  %b%s%b\n' "$PURPLE" "$left" "$pad" '' "$BLUE" "$(ui 'PROJECTS & UPDATES' 'ПРОЕКТЫ И ОБНОВЛЕНИЯ')" "$RESET"
    while true; do
        for ((row=0;row<5;row++)); do
            left="  ${options[$row]}"; right="  ${options[$((row+5))]}"
            [[ "$selected" != "$row" ]] || left="> ${options[$row]}"
            [[ "$selected" != "$((row+5))" ]] || right="> ${options[$((row+5))]}"
            pad=$((width-${#left})); [[ "$pad" -ge 0 ]] || pad=0
            if [[ "$selected" == "$row" ]]; then printf '  %b%s%b' "$GREEN" "$left" "$RESET"; else printf '  %s' "$left"; fi
            printf '%*s  ' "$pad" ''
            if [[ "$selected" == "$((row+5))" ]]; then printf '%b%s%b\n' "$GREEN" "$right" "$RESET"; else printf '%s\n' "$right"; fi
        done
        IFS= read -rsn1 key || exit 1
        if [[ "$key" == $'\x1b' ]]; then IFS= read -rsn2 -t 0.2 extra || true; key+="$extra"; fi
        case "$key" in
            $'\x1b[A') selected=$((selected/5*5+(selected%5+4)%5)) ;;
            $'\x1b[B') selected=$((selected/5*5+(selected%5+1)%5)) ;;
            $'\x1b[C'|$'\x1b[D') selected=$(( (selected+5)%10 )) ;;
            '') break ;;
        esac
        printf '\033[5A\r'
    done
    MENU_SELECTED="$selected";tput cnorm 2>/dev/null || true;printf '\n'
}
update_menu() {
    if [[ -z "${GHOSTNET_ROOT:-}" || ! -f "${GHOSTNET_UPDATE_HELPER:-}" ]]; then
        printf '[UPDATE] %s\n' "$(ui 'Install the ghostnet command first to manage updates.' 'Сначала установите команду ghostnet для управления обновлениями.')"
        return
    fi
    choose_menu "$(ui 'Updates:' 'Обновления:')" 0 \
        "$(ui 'Update now' 'Обновить сейчас')" "$(ui 'Automatic update status' 'Состояние автообновления')" \
        "$(ui 'Enable startup and daily updates' 'Включить при запуске и ежедневно')" \
        "$(ui 'Disable automatic updates' 'Отключить автообновление')" "$(ui 'Back' 'Назад')"
    case "$MENU_SELECTED" in
        0) "$PYTHON_BIN" "$GHOSTNET_UPDATE_HELPER" --root "$GHOSTNET_ROOT" update ;;
        1) "$PYTHON_BIN" "$GHOSTNET_UPDATE_HELPER" --root "$GHOSTNET_ROOT" auto-update status ;;
        2) "$PYTHON_BIN" "$GHOSTNET_UPDATE_HELPER" --root "$GHOSTNET_ROOT" auto-update enable ;;
        3) "$PYTHON_BIN" "$GHOSTNET_UPDATE_HELPER" --root "$GHOSTNET_ROOT" auto-update disable ;;
    esac
}

# Native language adapters: build/validate first, execute only on request.
go_command() {
    local operation="$1" flags
    shift
    flags=$(go env GOFLAGS) || return $?
    if [[ "$flags" != *-buildvcs=* ]] && ! git rev-parse --show-toplevel >/dev/null 2>&1; then
        go "$operation" -buildvcs=false "$@"
    else
        go "$operation" "$@"
    fi
}
source_go_command() { (cd -- "$1" && go_command build -o "$2" "$3"); }
extra_tools() {
    case "$1" in
        *.c) printf '%s\n' gcc ;; *.go) printf '%s\n' go ;;
        *.java) printf '%s\n' javac java ;; *.js|*.mjs|*.cjs) printf '%s\n' node ;;
        *.ts|*.mts|*.cts) printf '%s\n' "$TSC_BIN" node ;;
        *.cs) printf '%s\n' dotnet ;; *.sh) printf '%s\n' bash ;; *.rb) printf '%s\n' ruby ;;
        *.php) printf '%s\n' php ;; *.lua) printf '%s\n' lua luac ;;
        *.swift) printf '%s\n' swiftc ;; *.kt) printf '%s\n' kotlinc java ;;
        *.dart) printf '%s\n' dart ;; *.zig) printf '%s\n' zig ;;
    esac
}
generated_directory() {
    local component path
    path=$(cd -- "$TARGET_DIR" && pwd)/.ghostnet-build
    [[ ! -L "$path" ]] || { printf '[ERROR] .ghostnet-build must not be a symlink.\n' >&2; return 1; }
    for component in "$HOST_KIND" "$1" "$2"; do
        path+="/$component"
        [[ ! -L "$path" ]] || { printf '[ERROR] Generated directory must not be a symlink: %s\n' "$path" >&2; return 1; }
    done
    if [[ -d "$path" ]] && IFS= read -r -d '' component < <(find "$path" \( -type l -o -type f -links +1 \) -print0 -quit); then
        printf '[ERROR] %s: %s\n' "$(ui 'Symlink or hardlink in generated output' 'Символическая или жёсткая ссылка в выходной папке')" "$component" >&2
        return 1
    fi
    mkdir -p -- "$path" || return 1
    printf '%s' "$path"
}
record_extra() { built_files+=("$1"); built_kinds+=("$2"); }
run_language_entry() {
    local entry="$1" kind="$2"
    shift 2
    case "$kind" in
        node) node "$entry" "$@" ;; java) java "$entry" "$@" ;;
        csharp) dotnet "$entry" "$@" ;; kotlin) java -jar "$entry" "$@" ;;
        bash) bash "$entry" "$@" ;; ruby) ruby "$entry" "$@" ;;
        php) php "$entry" "$@" ;; lua) lua "$entry" "$@" ;;
    esac
}
build_extra_source() {
    local src="$1" base="$2" index="$3" directory name compiled framework sdk temporary absolute_src absolute_base
    absolute_src=$(cd -- "$(dirname -- "$src")" && pwd)/"${src##*/}" || return 1
    absolute_base=$(cd -- "$(dirname -- "$base")" && pwd)/"${base##*/}" || return 1
    case "$src" in
        *.c)
            if [[ "$BUILD_TARGET" == linux || "$BUILD_TARGET" == both ]]; then
                run_build "$HOST_LABEL: $src" gcc -O2 -std=c17 "$src" -o "$base" || return 1
                record_extra "$base" native
            fi
            if [[ "$BUILD_TARGET" == windows || "$BUILD_TARGET" == both ]]; then
                run_build "Windows: $src" "$WIN_CC" -O2 -std=c17 "$src" -o "$base.exe" -static -s || return 1
                [[ "$BUILD_TARGET" != windows ]] || record_extra "$base.exe" windows
            fi ;;
        *.go)
            run_build "Go: $src" source_go_command "$(dirname -- "$absolute_src")" "$absolute_base" "${src##*/}" || return 1
            record_extra "$base" native ;;
        *.java)
            directory=$(generated_directory java "$index") || return 1
            run_build "Java: $src" javac -d "$directory" "$src" || return 1
            record_extra "$src" java ;;
        *.js|*.mjs|*.cjs)
            run_build "JavaScript: $src" node --check "$src" || return 1
            record_extra "$src" node ;;
        *.ts|*.mts|*.cts)
            directory=$(generated_directory typescript "$index") || return 1
            run_build "TypeScript: $src" "$TSC_BIN" --target ES2020 --module NodeNext --moduleResolution NodeNext --rootDir "$(dirname -- "$absolute_src")" --outDir "$directory" "$absolute_src" || return 1
            name="${src##*/}"; name="${name%.*}"
            case "$src" in *.mts) compiled="$directory/$name.mjs" ;; *.cts) compiled="$directory/$name.cjs" ;; *) compiled="$directory/$name.js" ;; esac
            [[ -f "$compiled" ]] || return 1
            record_extra "$compiled" node ;;
        *.cs)
            directory=$(generated_directory csharp "$index") || return 1
            for compiled in "$directory/Program.cs" "$directory/GhostnetFile.csproj" "$directory/out" "$directory/obj"; do [[ ! -L "$compiled" ]] || return 1; done
            sdk=$(dotnet --version) || return 1; sdk="${sdk%%.*}"
            [[ "$sdk" =~ ^[0-9]+$ && "$sdk" -ge 6 ]] || { printf '[ERROR] .NET SDK 6+ required.\n' >&2; return 1; }
            framework="net$sdk.0"
            temporary=$(mktemp "$directory/input.XXXXXX") || return 1
            cp -- "$src" "$temporary" && mv -f -- "$temporary" "$directory/Program.cs" || return 1
            temporary=$(mktemp "$directory/project.XXXXXX") || return 1
            printf '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><OutputType>Exe</OutputType><TargetFramework>%s</TargetFramework></PropertyGroup></Project>\n' "$framework" > "$temporary"
            mv -f -- "$temporary" "$directory/GhostnetFile.csproj" || return 1
            run_build "C#: $src" dotnet build "$directory/GhostnetFile.csproj" --nologo --output "$directory/out" || return 1
            record_extra "$directory/out/GhostnetFile.dll" csharp ;;
        *.sh) run_build "Bash: $src" bash -n "$src" || return 1; record_extra "$src" bash ;;
        *.rb) run_build "Ruby: $src" ruby -c "$src" || return 1; record_extra "$src" ruby ;;
        *.php) run_build "PHP: $src" php -l "$src" || return 1; record_extra "$src" php ;;
        *.lua) run_build "Lua: $src" luac -p "$src" || return 1; record_extra "$src" lua ;;
        *.swift) run_build "Swift: $src" swiftc "$src" -o "$base" || return 1; record_extra "$base" native ;;
        *.kt)
            directory=$(generated_directory kotlin "$index") || return 1
            [[ ! -L "$directory/app.jar" ]] || return 1
            run_build "Kotlin: $src" kotlinc "$src" -include-runtime -d "$directory/app.jar" || return 1
            record_extra "$directory/app.jar" kotlin ;;
        *.dart) run_build "Dart: $src" dart compile exe "$src" -o "$base" || return 1; record_extra "$base" native ;;
        *.zig)
            directory=$(generated_directory zig "$index") || return 1
            [[ ! -L "$directory/program" && ! -L "$directory/program.exe" && ! -L "$directory/program.o" ]] || return 1
            compiled="$directory/program"; [[ "$HOST_KIND" != windows ]] || compiled+=.exe
            run_build "Zig: $src" zig build-exe "$src" -O ReleaseSafe "-femit-bin=$compiled" || return 1
            record_extra "$compiled" native ;;
    esac
}
node_script() { project_command node -e 'const p=JSON.parse(require("fs").readFileSync("package.json","utf8")); process.exit(p.scripts && typeof p.scripts[process.argv[1]]==="string" ? 0 : 3)' "$1"; }
project_manager() {
    case "$PROJECT_BUILDER" in
        maven) if [[ -f "$TARGET_DIR/mvnw" ]]; then project_command bash ./mvnw "$@"; else project_command mvn "$@"; fi ;;
        gradle) if [[ -f "$TARGET_DIR/gradlew" ]]; then project_command bash ./gradlew "$@"; else project_command gradle "$@"; fi ;;
    esac
}
mixed_c_project() {
    local platform="$1" binary="$2" source object index=0 cc=gcc cxx="$LINUX_CXX" has_cxx=0
    local objects=() flags=()
    [[ "$platform" != windows ]] || { cc="$WIN_CC"; cxx="$WIN_CXX"; flags=("${WIN_FLAGS_METHOD1[@]}"); [[ "$WIN_METHOD" != 2 ]] || flags=("${WIN_FLAGS_METHOD2[@]}"); }
    for source in "${PROJECT_SOURCES[@]}"; do
        object="${binary}.source-$index.o"; index=$((index+1))
        [[ ! -L "$object" ]] || { printf '[ERROR] Symlink object: %s\n' "$object" >&2; return 1; }
        case "$source" in
            *.c) "$cc" -std=c17 -O2 "${include_flags[@]}" -c "$source" -o "$object" || return $? ;;
            *) has_cxx=1; "$cxx" "${CPP_FLAGS[@]}" "${include_flags[@]}" -c "$source" -o "$object" || return $? ;;
        esac
        objects+=("$object")
    done
    [[ "$has_cxx" -eq 1 ]] || cxx="$cc"
    if ! "$cxx" "${objects[@]}" -o "$binary" "${flags[@]}"; then
        [[ "$platform" == windows && "$WIN_METHOD" == auto ]] || return 1
        "$cxx" "${objects[@]}" -o "$binary" "${WIN_FLAGS_METHOD2[@]}" || return $?
    fi
}

build_external_project() {
    local path
    case "$PROJECT_BUILDER" in
        go) run_build 'Go build' project_command go_command build ./... ;;
        node)
            run_build 'Node manifest' project_command node -e 'JSON.parse(require("fs").readFileSync("package.json","utf8"))' || return 1
            if node_script build; then run_build 'npm build' project_command npm run build
            else
                local checked=0
                while IFS= read -r -d '' path; do
                    case "$path" in
                        *.ts|*.mts|*.cts) feature_error "$(ui 'TypeScript projects need scripts.build in package.json (for example: tsc).' 'Для проекта TypeScript добавьте scripts.build в package.json (например: tsc).')" ;;
                        *) run_build "$path" node --check "$path" || return 1; checked=$((checked+1)) ;;
                    esac
                done < <(find "$TARGET_DIR" -type d \( -name .git -o -name node_modules -o -name .ghostnet-build \) -prune -o -type f \( -name '*.js' -o -name '*.mjs' -o -name '*.cjs' -o -name '*.ts' -o -name '*.mts' -o -name '*.cts' \) -print0)
                [[ "$checked" -gt 0 ]] || feature_error "$(ui 'No JavaScript sources found: define scripts.build in package.json.' 'Исходники JavaScript не найдены: добавьте scripts.build в package.json.')"
            fi ;;
        dotnet)
            for path in "${DOTNET_PROJECTS[@]}"; do run_build '.NET build' project_command dotnet build "$path" --nologo || return 1; done ;;
        maven) run_build 'Maven build' project_manager -B package -DskipTests ;;
        gradle) run_build 'Gradle build' project_manager build -x test ;;
        swift) run_build 'SwiftPM build' project_command swift build ;;
        zig) run_build 'Zig build' project_command zig build ;;
    esac
}
test_external_project() {
    case "$PROJECT_BUILDER" in
        go) run_build 'Go tests' project_command go_command test ./... ;;
        node) node_script test || feature_error "$(ui 'Define a test script in package.json.' 'Добавьте test в scripts файла package.json.')"; run_build 'npm tests' project_command npm test ;;
        dotnet) for path in "${DOTNET_PROJECTS[@]}"; do run_build '.NET tests' project_command dotnet test "$path" --nologo || return 1; done ;;
        maven) run_build 'Maven tests' project_manager -B test ;;
        gradle) run_build 'Gradle tests' project_manager test ;;
        swift) run_build 'SwiftPM tests' project_command swift test ;;
        zig) run_build 'Zig tests' project_command zig build test ;;
    esac
}
run_external_project() {
    local path entry="${RUN_FILE:-$PROJECT_RUN}"
    case "$PROJECT_BUILDER" in
        go)
            [[ -z "$entry" ]] || relative_project_path "$entry" || feature_error "$(ui 'Invalid Go package path.' 'Некорректный путь пакета Go.')"
            project_command go_command run "./${entry:-.}" "${PROJECT_ARGS[@]}" ;;
        node)
            if [[ -n "$entry" ]]; then
                relative_project_path "$entry" && [[ -f "$TARGET_DIR/$entry" ]] || feature_error "$(ui 'Invalid Node entry.' 'Некорректная точка входа Node.')"
                project_command node "$entry" "${PROJECT_ARGS[@]}"
            elif node_script start; then project_command npm run start -- "${PROJECT_ARGS[@]}"
            else feature_error "$(ui 'Define scripts.start or --run-file in the Node project.' 'Укажите scripts.start или --run-file для проекта Node.')"; fi ;;
        dotnet)
            if [[ -n "$entry" ]]; then
                relative_project_path "$entry" && [[ "$entry" == *.csproj && -f "$TARGET_DIR/$entry" ]] || feature_error "$(ui 'Use --run-file PATH.csproj.' 'Используйте --run-file PATH.csproj.')"
            elif [[ ${#DOTNET_PROJECTS[@]} -eq 1 ]]; then entry="${DOTNET_PROJECTS[0]}"
            elif [[ -t 0 && -t 1 ]]; then choose_menu "$(ui 'Select .NET project:' 'Выберите проект .NET:')" 0 "${DOTNET_PROJECTS[@]}"; entry="${DOTNET_PROJECTS[$MENU_SELECTED]}"
            else feature_error "$(ui 'Multiple .NET projects: use --run-file PATH.csproj.' 'Несколько проектов .NET: укажите --run-file PATH.csproj.')"; fi
            project_command dotnet run --no-build --project "$entry" -- "${PROJECT_ARGS[@]}" ;;
        swift)
            if [[ -n "$entry" ]]; then
                [[ "$entry" =~ ^[a-zA-Z0-9_-]+$ ]] || feature_error "$(ui 'Swift entry must be a product name.' 'Для Swift укажите имя продукта.')"
                project_command swift run --skip-build "$entry" "${PROJECT_ARGS[@]}"
            else
                [[ ${#PROJECT_ARGS[@]} -eq 0 ]] || feature_error "$(ui 'Select a Swift product with --run-file before passing arguments.' 'Укажите продукт Swift через --run-file перед передачей аргументов.')"
                project_command swift run --skip-build
            fi ;;
    esac
}

# Additive UI helpers; each language script remains self-contained.
ui() { if [[ "$INTERFACE_LANG" == ru ]]; then printf '%s' "$2"; else printf '%s' "$1"; fi; }
language_name() {
    case "$1" in
        *.cpp|*.cc|*.cxx) printf 'C++' ;; *.c) printf 'C' ;; *.rs) printf 'Rust' ;;
        *.py) printf 'Python' ;; *.go) printf 'Go' ;; *.java) printf 'Java' ;;
        *.js|*.mjs|*.cjs) printf 'JavaScript' ;; *.ts|*.mts|*.cts) printf 'TypeScript' ;;
        *.cs) printf 'C#' ;; *.sh) printf 'Bash' ;; *.rb) printf 'Ruby' ;;
        *.php) printf 'PHP' ;; *.lua) printf 'Lua' ;; *.swift) printf 'Swift' ;;
        *.kt) printf 'Kotlin' ;; *.dart) printf 'Dart' ;; *.zig) printf 'Zig' ;;
    esac
}
languages_list() {
    printf '%b[LANGUAGES]%b %s\n' "$PURPLE" "$RESET" "$(ui 'Native toolchains and project engines' 'Инструменты языков и системы сборки')"
    printf '%s\n' 'C / C++       gcc / g++, CMake, Make' 'Rust          rustc, Cargo' \
        'Python        python3, pyproject.toml' 'Go            go, go.mod' \
        'Java          javac / java, Maven / Gradle' 'JavaScript    node / npm' \
        'TypeScript    tsc / node, npm scripts' 'C#            dotnet' \
        'Bash          bash' 'Ruby          ruby' 'PHP           php' 'Lua           lua / luac' \
        'Swift         swiftc / SwiftPM' 'Kotlin        kotlinc / java, Gradle' \
        'Dart          dart' 'Zig           zig'
}
project_passport() {
    local src language languages='' engine="${PROJECT_BUILDER:-files}" entry="${RUN_FILE:-${PROJECT_RUN:-}}"
    case "$engine" in
        cpp|cmake) languages='C / C++' ;; cargo) languages=Rust ;; python) languages=Python ;;
        go) languages=Go ;; node) languages='JavaScript / TypeScript' ;; dotnet) languages='C#' ;;
        maven|gradle) languages='Java / Kotlin' ;; swift) languages=Swift ;; zig) languages=Zig ;;
    esac
    for src in "${sources[@]}"; do
        language=$(language_name "$src")
        [[ -n "$language" && ", $languages, " != *", $language, "* ]] || continue
        languages="${languages:+$languages, }$language"
    done
    printf '\n%b[SCAN COMPLETE]%b\n' "$BLUE" "$RESET"
    printf '  %-10s › %s\n' "$(ui PROJECT ПРОЕКТ)" "${TARGET_DIR:-.}"
    printf '  %-10s › %s\n' "$(ui LANGUAGES ЯЗЫКИ)" "${languages:-—}"
    printf '  %-10s › %s\n' "$(ui ENGINE СБОРЩИК)" "$engine"
    printf '  %-10s › %s\n' "$(ui TARGET ПЛАТФОРМА)" "$DISPLAY_TARGET"
    printf '  %-10s › %s\n\n' "$(ui ENTRY ЗАПУСК)" "${entry:-$(ui 'select after build' 'выбор после сборки')}"
}



state_folder() { printf '%s/ghostnet' "${XDG_STATE_HOME:-$HOME/.local/state}"; }
record_recent() {
    local path state temporary old count=0 paths=()
    path=$(cd -- "$TARGET_DIR" 2>/dev/null && pwd) || return 0
    [[ "$path" != *$'\n'* && "$path" != *$'\r'* ]] || return 0
    state=$(state_folder)
    [[ ! -L "$state" && ! -L "$state/recent-projects" ]] || return 0
    (umask 077; mkdir -p -- "$state") 2>/dev/null || return 0
    temporary=$(mktemp "$state/recent.XXXXXX" 2>/dev/null) || return 0
    paths=("$path")
    if [[ -f "$state/recent-projects" ]]; then
        while IFS= read -r old; do
            [[ -d "$old" && "$old" != "$path" && -n "$old" ]] || continue
            paths+=("$old")
            [[ ${#paths[@]} -lt 5 ]] || break
        done < "$state/recent-projects"
    fi
    printf '%s\n' "${paths[@]}" > "$temporary" && mv -f -- "$temporary" "$state/recent-projects" 2>/dev/null || rm -f -- "$temporary" 2>/dev/null
    return 0
}
recent_projects() {
    local state path paths=()
    state=$(state_folder)
    if [[ -f "$state/recent-projects" && ! -L "$state/recent-projects" ]]; then
        while IFS= read -r path; do [[ ! -d "$path" ]] || paths+=("$path"); done < "$state/recent-projects"
    fi
    if [[ ${#paths[@]} -eq 0 ]]; then
        printf '[RECENT] %s\n' "$(ui 'No recent projects yet.' 'Недавних проектов пока нет.')"
        exit 0
    fi
    if [[ ! -t 0 || ! -t 1 ]]; then
        printf '[RECENT]\n'; printf '  %s\n' "${paths[@]}"; exit 0
    fi
    choose_menu "$(ui 'Recent projects (↑/↓ + Enter):' 'Недавние проекты (↑/↓ + Enter):')" 0 "${paths[@]}"
    TARGET_DIR="${paths[$MENU_SELECTED]}"; ACTION=build
}
remember_entry() {
    local entry="$1" root="$TARGET_DIR/.ghostnet-build" temporary
    [[ ! -L "$root" && ! -L "$root/run-entry" ]] || return 0
    mkdir -p -- "$root" 2>/dev/null || return 0
    temporary=$(mktemp "$root/entry.XXXXXX" 2>/dev/null) || return 0
    printf '%s\n' "$entry" > "$temporary" && mv -f -- "$temporary" "$root/run-entry" 2>/dev/null || rm -f -- "$temporary" 2>/dev/null
    return 0
}
select_project_entry() {
    local root path relative magic cached='' candidates=() skip=()
    case "$PROJECT_BUILDER" in
        cmake) root="$TARGET_DIR/.ghostnet-build/$project_platform" ;;
        zig) root="$TARGET_DIR/zig-out/bin" ;;
        make) root="$TARGET_DIR"; skip=(-name .ghostnet-build -o) ;;
        *) return 0 ;;
    esac
    [[ -d "$root" ]] || return 0
    while IFS= read -r -d '' path; do
        case "$path" in *.so|*.so.*|*.dylib|*.dll|*.o|*.a|*.class) continue ;; esac
        magic=$(od -An -tx1 -N4 -- "$path" 2>/dev/null); magic="${magic//[[:space:]]/}"
        case "$magic" in 7f454c46|4d5a*|cffaedfe|cefaedfe|feedfacf|feedface|cafebabe|bebafeca) ;; *) continue ;; esac
        relative="${path#"$TARGET_DIR/"}"
        candidates+=("$relative")
    done < <(find "$root" \( "${skip[@]}" -name CMakeFiles -o -name .git -o -name node_modules -o -name .venv -o -name _deps \) -prune -o -type f \( -perm -u+x -o -name '*.exe' \) -print0)
    if [[ -f "$TARGET_DIR/.ghostnet-build/run-entry" && ! -L "$TARGET_DIR/.ghostnet-build/run-entry" ]]; then
        IFS= read -r cached < "$TARGET_DIR/.ghostnet-build/run-entry" || true
        for path in "${candidates[@]}"; do
            [[ "$cached" != "$path" ]] || { entry="$cached"; return 0; }
        done
    fi
    if [[ ${#candidates[@]} -eq 1 ]]; then
        entry="${candidates[0]}"
    elif [[ ${#candidates[@]} -gt 1 ]]; then
        if [[ ! -t 0 || ! -t 1 ]]; then
            printf '[ERROR] %s\n' "$(ui 'Multiple programs: use --run-file PATH or select one interactively.' 'Несколько программ: укажите --run-file PATH или выберите в интерактивном меню.')" >&2
            printf '  %s\n' "${candidates[@]}" >&2; exit 1
        fi
        choose_menu "$(ui 'Which program should run?' 'Какую программу запустить?')" 0 "${candidates[@]}"
        entry="${candidates[$MENU_SELECTED]}"
    fi
}

feature_error() { printf '[ERROR] %s\n' "$*" >&2; exit 1; }
init_project() {
    local destination="${TARGET_DIR:-}" kind="$INIT_TYPE" files=() sdk framework=net8.0
    local kinds=(cpp cmake c rust python go java javascript typescript csharp bash ruby php lua swift kotlin dart zig)
    if [[ -z "$kind" ]]; then
        choose_menu "$(ui 'Create project (↑/↓ + Enter):' 'Создать проект (↑/↓ + Enter):')" 0 \
            "$(ui 'C++ single file' 'C++ — отдельный файл')" 'C++ CMake' "$(ui 'C single file' 'C — отдельный файл')" 'Rust / Cargo' 'Python' 'Go' 'Java' \
            'JavaScript / Node' 'TypeScript / Node' 'C# / .NET' 'Bash' 'Ruby' 'PHP' 'Lua' 'Swift / SwiftPM' 'Kotlin' 'Dart' 'Zig'
        kind="${kinds[$MENU_SELECTED]}"
    fi
    case "$kind" in cpp|cmake|c|rust|python|go|java|javascript|typescript|csharp|bash|ruby|php|lua|swift|kotlin|dart|zig) ;;
        *) feature_error "$(ui 'Unknown project type:' 'Неизвестный тип проекта:') $kind" ;; esac
    if [[ -z "$destination" && -t 0 && -t 1 ]]; then
        read -r -p "$(ui 'New project folder (my-project): ' 'Папка нового проекта (my-project): ')" destination || exit 1
    fi
    destination="${destination:-my-project}"
    [[ ! -L "$destination" ]] || feature_error "$(ui 'Project folder must not be a symlink.' 'Папка проекта не должна быть символической ссылкой.')"
    if [[ -e "$destination" ]]; then
        [[ -d "$destination" ]] || feature_error "$(ui 'Path already exists:' 'Путь уже существует:') $destination"
        while IFS= read -r -d '' item; do files+=("$item"); done < <(find "$destination" -mindepth 1 -maxdepth 1 -print0)
        [[ ${#files[@]} -eq 0 ]] || feature_error "$(ui 'Project folder must be empty; existing files were preserved.' 'Папка проекта должна быть пустой; существующие файлы сохранены.')"
    fi
    mkdir -p -- "$destination" || exit 1
    init_write() { mkdir -p -- "$destination/$(dirname -- "$1")" && printf '%s\n' "$2" > "$destination/$1"; }
    init_write .gitignore $'.ghostnet-build/\n.venv/\n__pycache__/\n*.pyc\nbuild/\ntarget/\nnode_modules/\nbin/\nobj/\n.build/\n.dart_tool/\n.zig-cache/\nzig-out/' || exit 1
    case "$kind" in
        cpp) init_write main.cpp $'#include <iostream>\nint main() { std::cout << "Hello GHOSTNET!\\n"; }' ;;
        cmake)
            init_write CMakeLists.txt $'cmake_minimum_required(VERSION 3.16)\nproject(GhostnetApp LANGUAGES CXX)\nset(CMAKE_CXX_STANDARD 17)\nadd_executable(app src/main.cpp)\nenable_testing()\nadd_test(NAME greeting COMMAND app)\nset_tests_properties(greeting PROPERTIES PASS_REGULAR_EXPRESSION "Hello GHOSTNET")'
            init_write src/main.cpp $'#include <iostream>\nint main() { std::cout << "Hello GHOSTNET!\\n"; }'
            init_write ghostnet.conf $'builder=cmake\nrun=.ghostnet-build/{target}/app{exe}' ;;
        c) init_write main.c $'#include <stdio.h>\nint main(void) { puts("Hello GHOSTNET!"); return 0; }' ;;
        rust)
            init_write Cargo.toml $'[package]\nname = "ghostnet_app"\nversion = "0.1.0"\nedition = "2021"'
            init_write src/main.rs 'fn main() { println!("Hello GHOSTNET!"); }' ;;
        python)
            init_write pyproject.toml $'[project]\nname = "ghostnet-app"\nversion = "0.1.0"'
            init_write app.py $'def greet(name):\n    return f"Hello {name}!"'
            init_write __main__.py $'from app import greet\nprint(greet("GHOSTNET"))'
            init_write tests/test_app.py $'import unittest\nfrom app import greet\nclass GreetingTest(unittest.TestCase):\n    def test_name(self):\n        self.assertEqual(greet("Ada"), "Hello Ada!")' ;;
        go)
            init_write go.mod $'module example.com/ghostnet-app\n\ngo 1.20'
            init_write main.go $'package main\nimport "fmt"\nfunc main() { fmt.Println("Hello GHOSTNET!") }' ;;
        java) init_write Main.java $'public class Main {\n    public static void main(String[] args) { System.out.println("Hello GHOSTNET!"); }\n}' ;;
        javascript)
            init_write package.json '{"name":"ghostnet-app","version":"0.1.0","private":true,"scripts":{"build":"node --check main.js","start":"node main.js","test":"node --test"}}'
            init_write main.js 'console.log("Hello GHOSTNET!");' ;;
        typescript)
            init_write package.json '{"name":"ghostnet-app","version":"0.1.0","private":true,"scripts":{"build":"tsc -p tsconfig.json","start":"node .ghostnet-build/node/main.js","test":"node --test"},"devDependencies":{"typescript":"^5.0.0"}}'
            init_write tsconfig.json '{"compilerOptions":{"target":"ES2020","module":"CommonJS","outDir":".ghostnet-build/node","strict":true},"include":["main.ts"]}'
            init_write main.ts 'const message: string = "Hello GHOSTNET!"; console.log(message);' ;;
        csharp)
            if command -v dotnet >/dev/null 2>&1; then
                sdk=$(dotnet --version 2>/dev/null); sdk="${sdk%%.*}"
                [[ "$sdk" =~ ^[0-9]+$ && "$sdk" -ge 6 ]] && framework="net$sdk.0"
            fi
            init_write GhostnetApp.csproj "<Project Sdk=\"Microsoft.NET.Sdk\"><PropertyGroup><OutputType>Exe</OutputType><TargetFramework>$framework</TargetFramework></PropertyGroup></Project>"
            init_write Program.cs 'System.Console.WriteLine("Hello GHOSTNET!");' ;;
        bash) init_write main.sh $'#!/usr/bin/env bash\nprintf "Hello GHOSTNET!\\n"' ;;
        ruby) init_write main.rb 'puts "Hello GHOSTNET!"' ;;
        php) init_write main.php '<?php echo "Hello GHOSTNET!\n";' ;;
        lua) init_write main.lua 'print("Hello GHOSTNET!")' ;;
        swift)
            init_write Package.swift $'// swift-tools-version: 5.9\nimport PackageDescription\nlet package = Package(name: "GhostnetApp", targets: [.executableTarget(name: "GhostnetApp")])'
            init_write Sources/GhostnetApp/main.swift 'print("Hello GHOSTNET!")' ;;
        kotlin) init_write Main.kt 'fun main() { println("Hello GHOSTNET!") }' ;;
        dart) init_write main.dart 'void main() { print("Hello GHOSTNET!"); }' ;;
        zig) init_write main.zig $'const std = @import("std");\npub fn main() void { std.debug.print("Hello GHOSTNET!\\n", .{}); }' ;;
    esac
    [[ $? -eq 0 ]] || exit 1
    printf '%b[INIT COMPLETE]%b %s (%s)\n' "$GREEN" "$RESET" "$destination" "$kind"
    printf '  ghostnet run --target native %q\n' "$destination"
}

if [[ "$ACTION" == languages ]]; then languages_list; exit 0; fi

if [[ -z "$ACTION" ]]; then
    if [[ -t 0 && -t 1 && -z "$BUILD_TARGET" ]]; then
        while true; do
        choose_dashboard "GHOSTNET — main menu (↑/↓ · ←/→ + Enter):" 2 \
            "Check environment" \
            "Install tools" \
            "Build a program" \
            "Full automatic build" \
            "Exit" \
            "$(ui 'Inspect project' 'Паспорт проекта')" \
            "$(ui 'Supported languages' 'Поддерживаемые языки')" \
            "$(ui 'Create project' 'Создать проект')" \
            "$(ui 'Recent projects' 'Недавние проекты')" \
            "$(ui 'Updates' 'Обновления')"
        case "$MENU_SELECTED" in
            9) update_menu; continue ;;
            0) ACTION="check" ;;
            1) ACTION="install" ;;
            2) ACTION="build" ;;
            3) ACTION="auto" ;;
            4) exit 0 ;;
            5) ACTION="inspect"; TARGET_DIR_PRESET="." ;;
            6) languages_list; exit 0 ;;
            7) ACTION="init" ;;
            8) ACTION="recent" ;;
        esac
        break
        done
    else
        ACTION="build"
    fi
fi

if [[ "$ACTION" == recent ]]; then recent_projects; fi

if [[ "$ACTION" == init ]]; then init_project; exit $?; fi

case "$ACTION" in
    check|install|build|auto|test|inspect|doctor|setup|watch|clean) ;;
    *) printf '[ERROR] Invalid mode: %s\n' "$ACTION" >&2; exit 2 ;;
esac

[[ "$ACTION" != inspect && "$ACTION" != doctor && "$ACTION" != setup && "$ACTION" != watch && "$ACTION" != clean ]] || BUILD_TARGET="${BUILD_TARGET:-native}"

if [[ -z "$BUILD_TARGET" || "$BUILD_TARGET" == "native" ]]; then
    if [[ "$BUILD_TARGET" == "native" ]]; then
        BUILD_TARGET="$HOST_KIND"
    elif [[ "$HOST_KIND" == "windows" ]]; then
        BUILD_TARGET="windows"
    else
        platform_menu=("$HOST_LABEL" "Windows" "$HOST_LABEL and Windows")
        choose_menu "Platform (↑/↓ + Enter):" 0 "${platform_menu[@]}"
        case "$MENU_SELECTED" in
            0) BUILD_TARGET="$HOST_KIND" ;;
            1) BUILD_TARGET="windows" ;;
            *) BUILD_TARGET="both" ;;
        esac
    fi
fi
if [[ "$HOST_KIND" == "windows" && "$BUILD_TARGET" != "windows" ]]; then
    printf '[ERROR] Only Windows builds are available on Windows.\n' >&2
    exit 1
fi
if [[ "$HOST_KIND" != "linux" && "$BUILD_TARGET" == "linux" ]]; then
    printf '[ERROR] Linux builds require Linux. Use --target native.\n' >&2
    exit 1
fi
if [[ "$BUILD_TARGET" == "macos" ]]; then
    if [[ "$HOST_KIND" != "macos" ]]; then
        printf '[ERROR] macOS builds require macOS.\n' >&2
        exit 1
    fi
    BUILD_TARGET="linux" # Internal native branch; labels use the actual host.
fi
if [[ "$BUILD_TARGET" != "linux" && "$BUILD_TARGET" != "windows" && "$BUILD_TARGET" != "both" ]]; then
    printf '[ERROR] Invalid BAN_BUILD_TARGET: %s\n' "$BUILD_TARGET" >&2
    exit 1
fi
DISPLAY_TARGET="$BUILD_TARGET"
[[ "$HOST_KIND" != "macos" || "$BUILD_TARGET" != "linux" ]] || DISPLAY_TARGET="macos"

sources=()
has_cpp=0
has_py=0
has_rs=0
has_c=0
TSC_BIN="tsc"
DOTNET_PROJECTS=()

if [[ "$ACTION" == "build" || "$ACTION" == "auto" || "$ACTION" == "test" || -n "$TARGET_DIR" || -n "$TARGET_DIR_PRESET" || -n "$SOURCE_FILE" ]]; then
    if [[ -z "$TARGET_DIR" ]]; then
        if [[ -n "$TARGET_DIR_PRESET" ]]; then
            TARGET_DIR="$TARGET_DIR_PRESET"
        elif [[ ( "$ACTION" == "build" || "$ACTION" == "auto" || "$ACTION" == "test" ) && -t 0 ]]; then
            read -r -p "Project folder (. by default): " TARGET_DIR || exit 1
        fi
    fi
    TARGET_DIR="${TARGET_DIR:-.}"
    [[ "$TARGET_DIR" == "/" ]] || TARGET_DIR="${TARGET_DIR%/}"
    if [[ ! -d "$TARGET_DIR" ]]; then
        printf '[ERROR] Folder not found: %s\n' "$TARGET_DIR" >&2
        exit 1
    fi
    sources=("$TARGET_DIR"/*.cpp "$TARGET_DIR"/*.cc "$TARGET_DIR"/*.cxx "$TARGET_DIR"/*.py "$TARGET_DIR"/*.rs "$TARGET_DIR"/*.c "$TARGET_DIR"/*.go "$TARGET_DIR"/*.java "$TARGET_DIR"/*.js "$TARGET_DIR"/*.mjs "$TARGET_DIR"/*.cjs "$TARGET_DIR"/*.ts "$TARGET_DIR"/*.mts "$TARGET_DIR"/*.cts "$TARGET_DIR"/*.cs "$TARGET_DIR"/*.sh "$TARGET_DIR"/*.rb "$TARGET_DIR"/*.php "$TARGET_DIR"/*.lua "$TARGET_DIR"/*.swift "$TARGET_DIR"/*.kt "$TARGET_DIR"/*.dart "$TARGET_DIR"/*.zig)
    # A downloaded launcher beside the user's sources is tooling, not a build result.
    launcher_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
    project_sources=()
    for src in "${sources[@]}"; do
        [[ "$src" -ef "$launcher_root/ban.sh" || "$src" -ef "$launcher_root/ban-ru.sh" ]] || project_sources+=("$src")
    done
    sources=("${project_sources[@]}")
    if [[ -n "$SOURCE_FILE" ]]; then
        case "$SOURCE_FILE" in
            *.cpp|*.cc|*.cxx|*.py|*.rs|*.c|*.go|*.java|*.js|*.mjs|*.cjs|*.ts|*.mts|*.cts|*.cs|*.sh|*.rb|*.php|*.lua|*.swift|*.kt|*.dart|*.zig)
                if [[ -f "$SOURCE_FILE" ]]; then
                    sources=("$SOURCE_FILE")
                else
                    printf '[ERROR] File not found: %s\n' "$SOURCE_FILE" >&2
                    exit 1
                fi
                ;;
            *) printf '[ERROR] Unsupported file: %s\n' "$SOURCE_FILE" >&2; exit 1 ;;
        esac
    fi
    for src in "${sources[@]}"; do
        case "$src" in
            *.cpp|*.cc|*.cxx) has_cpp=1 ;;
            *.py) has_py=1 ;;
            *.rs) has_rs=1 ;;
        esac
    done
else
    # Environment actions without a project inspect the full supported toolset.
    has_cpp=1 has_py=1 has_rs=1
fi

[[ ! -f "$TARGET_DIR/requirements.txt" ]] || has_py=1

# Literal project configuration: values are never evaluated as shell code.
project_error() { printf '[ERROR] %s\n' "$*" >&2; exit 1; }
relative_project_path() {
    [[ -n "$1" && "$1" != /* && "$1" != *\\* && "/$1/" != */../* ]]
}
PROJECT_BUILDER=""
PROJECT_OUTPUT="program"
PROJECT_RUN=""
PROJECT_SOURCES=() PROJECT_INCLUDES=() PROJECT_ARGS=()
for path in "$TARGET_DIR"/*.csproj; do DOTNET_PROJECTS+=("${path##*/}"); done
if [[ -x "$TARGET_DIR/node_modules/.bin/tsc" ]]; then TSC_BIN=$(cd -- "$TARGET_DIR" && pwd)/node_modules/.bin/tsc; fi
if [[ "$BUILD_MODE" != "files" ]]; then
    if [[ -f "$TARGET_DIR/ghostnet.conf" ]]; then
        while IFS= read -r config_line || [[ -n "$config_line" ]]; do
            config_line="${config_line%$'\r'}"
            [[ -n "$config_line" && "$config_line" != \#* ]] || continue
            [[ "$config_line" == *=* ]] || project_error "Invalid ghostnet.conf line: $config_line"
            key="${config_line%%=*}" value="${config_line#*=}"
            case "$key" in
                builder) PROJECT_BUILDER="$value" ;;
                source) relative_project_path "$value" || project_error "Invalid source path: $value"; PROJECT_SOURCES+=("$value") ;;
                include) relative_project_path "$value" || project_error "Invalid include path: $value"; PROJECT_INCLUDES+=("$value") ;;
                output) [[ "$value" =~ ^[a-zA-Z0-9_-][a-zA-Z0-9_.-]*$ ]] || project_error "Invalid output name: $value"; PROJECT_OUTPUT="$value" ;;
                run) relative_project_path "$value" || project_error "Invalid run path: $value"; PROJECT_RUN="$value" ;;
                arg) PROJECT_ARGS+=("$value") ;;
                *) project_error "Unknown ghostnet.conf key: $key" ;;
            esac
        done < "$TARGET_DIR/ghostnet.conf"
        PROJECT_BUILDER="${PROJECT_BUILDER:-cpp}"
    elif [[ -f "$TARGET_DIR/CMakeLists.txt" ]]; then
        PROJECT_BUILDER="cmake"
    elif [[ -f "$TARGET_DIR/Cargo.toml" ]]; then
        PROJECT_BUILDER="cargo"
    elif [[ -f "$TARGET_DIR/pyproject.toml" || ( -f "$TARGET_DIR/requirements.txt" && "$RUN_FILE" == *.py ) ]]; then
        PROJECT_BUILDER="python"
    elif [[ -f "$TARGET_DIR/GNUmakefile" || -f "$TARGET_DIR/Makefile" || -f "$TARGET_DIR/makefile" ]]; then
        PROJECT_BUILDER="make"
    elif [[ -f "$TARGET_DIR/go.mod" ]]; then PROJECT_BUILDER=go
    elif [[ -f "$TARGET_DIR/package.json" ]]; then PROJECT_BUILDER=node
    elif [[ ${#DOTNET_PROJECTS[@]} -gt 0 ]]; then PROJECT_BUILDER=dotnet
    elif [[ -f "$TARGET_DIR/pom.xml" ]]; then PROJECT_BUILDER=maven
    elif [[ -f "$TARGET_DIR/build.gradle" || -f "$TARGET_DIR/build.gradle.kts" ]]; then PROJECT_BUILDER=gradle
    elif [[ -f "$TARGET_DIR/Package.swift" ]]; then PROJECT_BUILDER=swift
    elif [[ -f "$TARGET_DIR/build.zig" ]]; then PROJECT_BUILDER=zig
    fi
    case "$BUILD_MODE" in
        cmake|make|cargo|python|go|node|dotnet|maven|gradle|swift|zig) PROJECT_BUILDER="$BUILD_MODE" ;;
        project) PROJECT_BUILDER="${PROJECT_BUILDER:-cpp}" ;;
        auto)
            if [[ -z "$PROJECT_BUILDER" && ( "$ACTION" == "build" || "$ACTION" == "auto" || "$ACTION" == "test" ) && -t 0 && -t 1 ]]; then
                choose_menu "Build mode (↑/↓ + Enter):" 0 "Separate programs" "One project (related C++ files)"
                [[ "$MENU_SELECTED" -eq 0 ]] || PROJECT_BUILDER="cpp"
            fi
            ;;
    esac
fi
if [[ -n "$PROJECT_BUILDER" ]]; then
    case "$PROJECT_BUILDER" in cpp|cmake|make|cargo|python|none|go|node|dotnet|maven|gradle|swift|zig) ;; *) project_error "Invalid project builder: $PROJECT_BUILDER" ;; esac
    case "$PROJECT_BUILDER" in go|node|dotnet|maven|gradle|swift|zig)
        [[ "$BUILD_TARGET" != both && ( "$BUILD_TARGET" != windows || "$HOST_KIND" == windows ) ]] || feature_error "$(ui 'This builder supports --target native only.' 'Этот сборщик поддерживает только --target native.')" ;;
    esac
    [[ -z "$SOURCE_FILE" ]] || project_error "BAN_SOURCE_FILE requires --mode files."
    if [[ "$PROJECT_BUILDER" == "cmake" || "$PROJECT_BUILDER" == "make" || "$PROJECT_BUILDER" == "cargo" || "$PROJECT_BUILDER" == "python" ]]; then
        if [[ "$BUILD_TARGET" == "both" || ( "$BUILD_TARGET" == "windows" && "$HOST_KIND" != "windows" ) ]]; then
            project_error "This project builder supports --target native only."
        fi
    fi
    if [[ "$PROJECT_BUILDER" == "cmake" ]]; then
        [[ -f "$TARGET_DIR/CMakeLists.txt" ]] || project_error "CMakeLists.txt not found."
    elif [[ "$PROJECT_BUILDER" == "make" ]]; then
        [[ -f "$TARGET_DIR/GNUmakefile" || -f "$TARGET_DIR/Makefile" || -f "$TARGET_DIR/makefile" ]] || project_error "Makefile not found."
    elif [[ "$PROJECT_BUILDER" == "cargo" ]]; then
        [[ -f "$TARGET_DIR/Cargo.toml" ]] || project_error "Cargo.toml not found."
    elif [[ "$PROJECT_BUILDER" == "python" ]]; then
        [[ -f "$TARGET_DIR/pyproject.toml" || -f "$TARGET_DIR/requirements.txt" ]] || project_error "pyproject.toml or requirements.txt not found."
        if [[ -z "$PROJECT_RUN" && -f "$TARGET_DIR/__main__.py" ]]; then PROJECT_RUN="__main__.py"; fi
    elif [[ "$PROJECT_BUILDER" == "cpp" ]]; then
        if [[ ${#PROJECT_SOURCES[@]} -eq 0 ]]; then
            for src in "$TARGET_DIR"/*.cpp "$TARGET_DIR"/*.cc "$TARGET_DIR"/*.cxx "$TARGET_DIR"/*.c; do
                PROJECT_SOURCES+=("${src##*/}")
            done
        fi
        [[ ${#PROJECT_SOURCES[@]} -gt 0 ]] || project_error "No C++ sources for the project."
        for src in "${PROJECT_SOURCES[@]}"; do
            case "$src" in *.cpp|*.cc|*.cxx|*.c) ;; *) project_error "Unsupported C++ source: $src" ;; esac
            [[ -f "$TARGET_DIR/$src" ]] || project_error "Source not found: $src"
        done
        for include in "${PROJECT_INCLUDES[@]}"; do
            [[ -d "$TARGET_DIR/$include" ]] || project_error "Include folder not found: $include"
        done
    fi
    case "$PROJECT_BUILDER" in
        go) [[ -f "$TARGET_DIR/go.mod" ]] || feature_error "$(ui 'go.mod not found.' 'Файл go.mod не найден.')" ;;
        node) [[ -f "$TARGET_DIR/package.json" ]] || feature_error "$(ui 'package.json not found.' 'Файл package.json не найден.')" ;;
        dotnet) [[ ${#DOTNET_PROJECTS[@]} -gt 0 ]] || feature_error "$(ui '.csproj not found.' 'Файл .csproj не найден.')" ;;
        maven) [[ -f "$TARGET_DIR/pom.xml" ]] || feature_error "$(ui 'pom.xml not found.' 'Файл pom.xml не найден.')" ;;
        gradle) [[ -f "$TARGET_DIR/build.gradle" || -f "$TARGET_DIR/build.gradle.kts" ]] || feature_error "$(ui 'build.gradle not found.' 'Файл build.gradle не найден.')" ;;
        swift) [[ -f "$TARGET_DIR/Package.swift" ]] || feature_error "$(ui 'Package.swift not found.' 'Файл Package.swift не найден.')" ;;
        zig) [[ -f "$TARGET_DIR/build.zig" ]] || feature_error "$(ui 'build.zig not found.' 'Файл build.zig не найден.')" ;;
    esac
    # The project build tools own source discovery; Python checks remain explicit.
    sources=("$TARGET_DIR"/*.py)
    entry="${RUN_FILE:-$PROJECT_RUN}"
    if [[ "$entry" == *.py && -f "$TARGET_DIR/$entry" ]]; then
        sources+=("$TARGET_DIR/$entry")
    fi
    has_cpp=0 has_rs=0 has_py=0
    case "$PROJECT_BUILDER" in cpp) for src in "${PROJECT_SOURCES[@]}"; do [[ "$src" == *.c ]] || has_cpp=1; done ;; esac
    [[ "$PROJECT_BUILDER" != "python" ]] || has_py=1
    if [[ -x "$TARGET_DIR/.venv/bin/python" ]]; then
        PYTHON_BIN=$(cd -- "$TARGET_DIR" && pwd)/.venv/bin/python
    elif [[ -x "$TARGET_DIR/.venv/Scripts/python.exe" ]]; then
        PYTHON_BIN=$(cd -- "$TARGET_DIR" && pwd)/.venv/Scripts/python.exe
    fi
    [[ ${#sources[@]} -eq 0 ]] || has_py=1
fi

if [[ -z "$PROJECT_BUILDER" ]]; then
    for src in "${sources[@]}"; do
        case "$src" in *.cpp|*.cc|*.cxx|*.c|*.py|*.rs) continue ;; esac
        [[ "$BUILD_TARGET" != both && ( "$BUILD_TARGET" != windows || "$HOST_KIND" == windows ) ]] || feature_error "$(ui 'New language adapters support --target native only.' 'Новые адаптеры языков поддерживают только --target native.')"
    done
fi
# Reuse the project environment for standalone Python as well as project mode.
if [[ -x "$TARGET_DIR/.venv/bin/python" ]]; then
    PYTHON_BIN=$(cd -- "$TARGET_DIR" && pwd)/.venv/bin/python
elif [[ -x "$TARGET_DIR/.venv/Scripts/python.exe" ]]; then
    PYTHON_BIN=$(cd -- "$TARGET_DIR" && pwd)/.venv/Scripts/python.exe
fi
project_passport
[[ "$ACTION" != inspect ]] || exit 0

if [[ -z "$PROJECT_BUILDER" && ( "$ACTION" == "build" || "$ACTION" == "auto" ) ]]; then
    if [[ ${#sources[@]} -eq 0 ]]; then
        printf '[ERROR] No supported source files in folder: %s\n' "$TARGET_DIR" >&2
        exit 1
    fi
fi

if [[ "$has_cpp" -eq 1 && ( "$BUILD_TARGET" == "windows" || "$BUILD_TARGET" == "both" ) ]]; then
    if [[ -z "$WIN_METHOD" ]]; then
        if [[ "$ACTION" == "auto" || "$ACTION" == "check" || "$ACTION" == "install" ]]; then
            WIN_METHOD="auto"
        else
            choose_menu "Windows build method (↑/↓ + Enter):" 0 \
                "Automatic (recommended)" \
                "Static build" \
                "Extended static build"
            case "$MENU_SELECTED" in
                0) WIN_METHOD="auto" ;;
                1) WIN_METHOD="1" ;;
                2) WIN_METHOD="2" ;;
            esac
        fi
    fi
else
    WIN_METHOD="auto"
fi

if [[ "$WIN_METHOD" != "1" && "$WIN_METHOD" != "2" && "$WIN_METHOD" != "auto" ]]; then
    echo -e "${RED}[ERROR]${RESET} Invalid BAN_WIN_METHOD: $WIN_METHOD"
    exit 1
fi

required_compilers=()
if [[ "$has_cpp" -eq 1 ]]; then
    if [[ "$BUILD_TARGET" == "linux" || "$BUILD_TARGET" == "both" ]]; then
        required_compilers+=("$LINUX_CXX")
    fi
fi
if [[ ( "$has_cpp" -eq 1 || "$has_rs" -eq 1 ) && ( "$BUILD_TARGET" == "windows" || "$BUILD_TARGET" == "both" ) ]]; then
    required_compilers+=("$WIN_CXX")
fi
[[ "$has_py" -eq 0 ]] || required_compilers+=("$PYTHON_BIN")
[[ "$has_rs" -eq 0 ]] || required_compilers+=(rustc)

if [[ "$PROJECT_BUILDER" == "cmake" ]]; then required_compilers+=(cmake ninja); fi
if [[ "$PROJECT_BUILDER" == "make" ]]; then required_compilers+=(make); fi
if [[ "$PROJECT_BUILDER" == "cargo" ]]; then required_compilers+=(cargo rustc); fi
if [[ "$ACTION" == "test" && -z "$PROJECT_BUILDER" ]]; then project_error "Testing requires a CMake, Make, Cargo or Python project."; fi

if [[ -z "$PROJECT_BUILDER" ]]; then
    for src in "${sources[@]}"; do
        if [[ "$src" == *.c ]]; then
            [[ "$BUILD_TARGET" != linux && "$BUILD_TARGET" != both ]] || required_compilers+=(gcc)
            [[ "$BUILD_TARGET" != windows && "$BUILD_TARGET" != both ]] || required_compilers+=("$WIN_CC")
        else
            while IFS= read -r tool; do [[ -z "$tool" ]] || required_compilers+=("$tool"); done < <(extra_tools "$src")
        fi
    done
fi
if [[ "$PROJECT_BUILDER" == cpp ]]; then
    for src in "${PROJECT_SOURCES[@]}"; do
        [[ "$src" == *.c ]] || continue
        [[ "$BUILD_TARGET" != linux && "$BUILD_TARGET" != both ]] || required_compilers+=(gcc)
        [[ "$BUILD_TARGET" != windows && "$BUILD_TARGET" != both ]] || required_compilers+=("$WIN_CC")
    done
fi
case "$PROJECT_BUILDER" in
    go) required_compilers+=(go) ;; node) required_compilers+=(node npm) ;; dotnet) required_compilers+=(dotnet) ;;
    maven) required_compilers+=(java javac); [[ -f "$TARGET_DIR/mvnw" ]] || required_compilers+=(mvn) ;;
    gradle) required_compilers+=(java javac); [[ -f "$TARGET_DIR/gradlew" ]] || required_compilers+=(gradle) ;;
    swift) required_compilers+=(swift) ;; zig) required_compilers+=(zig) ;;
esac
# Preserve order while avoiding repeated checks/install arguments.
unique_tools=(); for tool in "${required_compilers[@]}"; do found=0; for known in "${unique_tools[@]}"; do [[ "$known" != "$tool" ]] || found=1; done; [[ "$found" -eq 1 ]] || unique_tools+=("$tool"); done
required_compilers=("${unique_tools[@]}")

tool_help() {
    local link=""
    case "${1##*/}" in
        tsc) link=https://www.typescriptlang.org/download/ ;;
        dotnet) link=https://dotnet.microsoft.com/download ;;
        java|javac) link=https://adoptium.net/ ;;
        go) link=https://go.dev/doc/install ;;
        node|npm) link=https://nodejs.org/ ;;
        swift|swiftc) link=https://www.swift.org/install/ ;;
        kotlinc) link=https://kotlinlang.org/docs/command-line.html ;;
        dart) link=https://dart.dev/get-dart ;;
        zig) link=https://ziglang.org/download/ ;;
    esac
    [[ -z "$link" ]] || printf '[HINT] %s: %s\n' "$(ui 'Install the SDK and reopen your terminal' 'Установите SDK и откройте терминал заново')" "$link" >&2
    if [[ "${1##*/}" == tsc ]]; then
        printf '[HINT] %s\n' "$(ui 'For a project: npm install --save-dev typescript; define scripts.build as tsc.' 'Для проекта: npm install --save-dev typescript; добавьте scripts.build: tsc.')" >&2
    fi
}

check_dependencies() {
    local compiler missing=0
    [[ ! -x "$PYTHON_BIN" ]] && select_python
    for compiler in "${required_compilers[@]}"; do
        [[ "$compiler" != "python3" ]] || compiler="$PYTHON_BIN"
        if command -v "$compiler" >/dev/null 2>&1; then
            printf '%b[✓] %s — found%b\n' "$GREEN" "$compiler" "$RESET"
        else
            printf '%b[✗] %s — not found%b\n' "$RED" "$compiler" "$RESET"
            tool_help "$compiler"
            missing=1
        fi
    done
    return "$missing"
}

install_dependencies() {
    local manager compiler package
    local packages=() command_args=() privilege=()
    if [[ "$HOST_KIND" == "macos" ]]; then
        if ! command -v brew >/dev/null 2>&1; then
            printf '[ERROR] Install Homebrew or the required tools manually.\n' >&2
            return 1
        fi
        manager="brew"
        command_args=(brew install)
    elif [[ "$HOST_KIND" == "windows" ]]; then
        if [[ "${MSYSTEM:-}" != "UCRT64" ]] || ! command -v pacman >/dev/null 2>&1; then
            printf '[ERROR] Run the script in MSYS2 UCRT64.\n' >&2
            return 1
        fi
        manager="msys2"
        command_args=(pacman -S --needed --noconfirm)
    elif command -v pacman >/dev/null 2>&1; then
        manager="pacman"
        command_args=(pacman -S --needed --noconfirm)
    elif command -v apt-get >/dev/null 2>&1; then
        manager="apt-get"
        command_args=(apt-get install -y)
    elif command -v dnf >/dev/null 2>&1; then
        manager="dnf"
        command_args=(dnf install -y)
    else
        printf '[ERROR] Supported package managers: apt-get, dnf and pacman. Install tools manually.\n' >&2
        return 1
    fi

    for compiler in "${required_compilers[@]}"; do
        command -v "$compiler" >/dev/null 2>&1 && continue
        case "$manager:$compiler" in
            apt-get:gcc|dnf:gcc|pacman:gcc|brew:gcc) package="gcc" ;;
            msys2:gcc) package="mingw-w64-ucrt-x86_64-gcc" ;;
            apt-get:x86_64-w64-mingw32-gcc) package="gcc-mingw-w64-x86-64" ;;
            dnf:x86_64-w64-mingw32-gcc) package="mingw64-gcc" ;;
            pacman:x86_64-w64-mingw32-gcc) package="mingw-w64-gcc" ;;
            brew:x86_64-w64-mingw32-gcc) package="mingw-w64" ;;
            apt-get:go) package="golang-go" ;; dnf:go) package="golang" ;; pacman:go|brew:go) package="go" ;;
            apt-get:node|dnf:node|pacman:node|brew:node) package="nodejs"; [[ "$manager" != brew ]] || package=node ;;
            apt-get:npm|dnf:npm|pacman:npm) package="npm" ;; brew:npm) package="node" ;;
            apt-get:java|apt-get:javac) package="default-jdk" ;; dnf:java|dnf:javac) package="java-latest-openjdk-devel" ;;
            pacman:java|pacman:javac) package="jdk-openjdk" ;; brew:java|brew:javac) package="openjdk" ;;
            apt-get:bash|dnf:bash|pacman:bash|brew:bash) package="bash" ;;
            apt-get:ruby|dnf:ruby|pacman:ruby|brew:ruby) package="ruby" ;;
            apt-get:php) package="php-cli" ;; dnf:php|pacman:php|brew:php) package="php" ;;
            apt-get:lua|apt-get:luac) package="lua5.4" ;; dnf:lua|dnf:luac|pacman:lua|pacman:luac|brew:lua|brew:luac) package="lua" ;;
            apt-get:mvn|dnf:mvn|pacman:mvn|brew:mvn) package="maven" ;;
            apt-get:gradle|dnf:gradle|pacman:gradle|brew:gradle) package="gradle" ;;
            pacman:dotnet) package="dotnet-sdk" ;; brew:dotnet) package="dotnet" ;;
            pacman:kotlinc|brew:kotlinc) package="kotlin" ;;
            pacman:zig|brew:zig) package="zig" ;;
            apt-get:g++) package="g++" ;;
            apt-get:x86_64-w64-mingw32-g++) package="g++-mingw-w64-x86-64" ;;
            dnf:g++) package="gcc-c++" ;;
            dnf:x86_64-w64-mingw32-g++) package="mingw64-gcc-c++" ;;
            pacman:g++) package="gcc" ;;
            pacman:x86_64-w64-mingw32-g++) package="mingw-w64-gcc" ;;
            apt-get:python3|dnf:python3) package="python3" ;;
            pacman:python3) package="python" ;;
            apt-get:rustc) package="rustc" ;;
            dnf:rustc) package="rust" ;;
            pacman:rustc) package="rust" ;;
            brew:g++) package="gcc" ;;
            brew:x86_64-w64-mingw32-g++) package="mingw-w64" ;;
            brew:python3|brew:python) package="python" ;;
            brew:rustc) package="rust" ;;
            msys2:g++) package="mingw-w64-ucrt-x86_64-gcc" ;;
            msys2:python3|msys2:python) package="mingw-w64-ucrt-x86_64-python" ;;
            msys2:rustc) package="mingw-w64-ucrt-x86_64-rust" ;;
            apt-get:cmake|dnf:cmake|pacman:cmake|brew:cmake) package="cmake" ;;
            apt-get:ninja|dnf:ninja) package="ninja-build" ;;
            pacman:ninja|brew:ninja) package="ninja" ;;
            apt-get:make|dnf:make|pacman:make|brew:make|msys2:make) package="make" ;;
            msys2:cmake) package="mingw-w64-ucrt-x86_64-cmake" ;;
            msys2:ninja) package="mingw-w64-ucrt-x86_64-ninja" ;;
            apt-get:cargo|dnf:cargo) package="cargo" ;;
            pacman:cargo|brew:cargo) package="rust" ;;
            msys2:cargo) package="mingw-w64-ucrt-x86_64-rust" ;;
            *) printf '[ERROR] No package mapping for tool: %s\n' "$compiler" >&2; tool_help "$compiler"; return 1 ;;
        esac
        packages+=("$package")
    done
    if [[ ${#packages[@]} -eq 0 ]]; then
        printf '[OK] All required tools are already installed.\n'
        return 0
    fi
    if [[ "$HOST_KIND" == "linux" && "$EUID" -ne 0 ]]; then
        if ! command -v sudo >/dev/null 2>&1; then
            printf '[ERROR] Installation requires sudo or root.\n' >&2
            return 1
        fi
        privilege=(sudo)
    fi
    printf 'Missing packages: %s\n' "${packages[*]}"
    printf 'Install command:'
    printf ' %q' "${privilege[@]}" "${command_args[@]}" "${packages[@]}"
    printf '\n'
    if [[ "$ASSUME_YES" -ne 1 ]]; then
        if [[ ! -t 0 || ! -t 1 ]]; then
            printf '[ERROR] Installation requires terminal confirmation or --yes.\n' >&2
            return 1
        fi
        choose_menu "Install these packages?" 0 "Cancel" "Install"
        if [[ "$MENU_SELECTED" -ne 1 ]]; then
            printf 'Installation cancelled.\n'
            return 1
        fi
    fi
    "${privilege[@]}" "${command_args[@]}" "${packages[@]}" || return 1
    hash -r
    check_dependencies
}


# An output inventory lets clean preserve foreign and subsequently edited files.
CLEAN_BASE=""
clean_inventory() {
    local operation="$1"; shift
    "$PYTHON_BIN" - "$operation" "$TARGET_DIR" "$(state_folder)" "$CLEAN_BASE" "$@" <<'PYCLEAN'
import hashlib, json, os, pathlib, stat, sys, tempfile
operation, folder, state_folder, baseline, *outputs = sys.argv[1:]
root = pathlib.Path(folder).resolve()
state = pathlib.Path(state_folder)/'outputs'
if state.is_symlink() or state.parent.is_symlink(): sys.exit(1)
manifest = state/(hashlib.sha256(str(root).encode()).hexdigest()+'.json')
if manifest.is_symlink(): sys.exit(1)
def signature(path):
    try:
        if path.is_symlink() or not path.is_file(): return None
        info = path.stat()
        if info.st_nlink != 1: return None
        return [info.st_size,hashlib.sha256(path.read_bytes()).hexdigest()]
    except OSError: return None
def safe_path(name):
    path = pathlib.Path(name)
    if path.is_absolute() or '..' in path.parts or not path.parts: return None
    if any((root/pathlib.Path(*path.parts[:i])).is_symlink() for i in range(1,len(path.parts)+1)): return None
    return root/path
def generated():
    result = {}
    directory = root/'.ghostnet-build'
    if directory.is_symlink(): return result
    source_suffixes = {'.c','.cc','.cpp','.cxx','.h','.hpp','.py','.rs','.go','.java','.ts','.cs','.sh','.rb','.php','.lua','.swift','.kt','.dart','.zig'}
    for parent, dirs, files in os.walk(directory, followlinks=False):
        dirs[:] = [d for d in dirs if not pathlib.Path(parent,d).is_symlink()]
        for name in files:
            path = pathlib.Path(parent,name)
            if path.suffix in source_suffixes: continue
            value = signature(path)
            if value is not None: result[str(path.relative_to(root))] = value
    return result
if operation == 'begin':
    pathlib.Path(baseline).write_text(json.dumps(generated())); sys.exit(0)
owned = json.loads(manifest.read_text()) if manifest.exists() else {}
if not isinstance(owned,dict): raise ValueError('Invalid output inventory')
if operation == 'record':
    before = json.loads(pathlib.Path(baseline).read_text()) if baseline else {}
    for name, value in generated().items():
        if before.get(name) != value: owned[name] = value
    for output in outputs:
        original = pathlib.Path(output).absolute()
        if original.is_symlink(): continue
        path = original.resolve()
        try: name = str(path.relative_to(root))
        except ValueError: continue
        if safe_path(name) is None: continue
        # Never claim an interpreted source as a generated artifact.
        if path.suffix in {'.py','.js','.mjs','.cjs','.java','.sh','.rb','.php','.lua'}: continue
        value = signature(path)
        if value is not None: owned[name] = value
else:
    removed = 0
    for name,value in list(owned.items()):
        path = safe_path(name)
        if path is None: continue
        if signature(path) == value:
            path.unlink(); removed += 1
            parent = path.parent
            while parent != root and (str(parent).startswith(str(root/'.ghostnet-build')+os.sep) or parent == root/'.ghostnet-build'):
                try: parent.rmdir()
                except OSError: break
                parent = parent.parent
            del owned[name]
        elif not path.exists(): del owned[name]
        else: print('[CLEAN] Preserved modified output:',name)
    print('[CLEAN]',removed,'files')
state.mkdir(parents=True,exist_ok=True)
fd,temporary = tempfile.mkstemp(dir=state,prefix='.outputs-')
try:
    with os.fdopen(fd,'w') as stream: json.dump(owned,stream)
    os.replace(temporary,manifest)
finally:
    if os.path.exists(temporary): os.unlink(temporary)
PYCLEAN
}

project_watch() {
    local launcher
    launcher=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/${BASH_SOURCE[0]##*/}
    "$PYTHON_BIN" - "$launcher" "$TARGET_DIR" "$BUILD_MODE" "$RUN_FILE" "$HOST_KIND" "$INTERFACE_LANG" "$BASH" <<'PYWATCH'
import os, pathlib, signal, subprocess, sys, time
launcher, folder, mode, entry, host, lang, bash_executable = sys.argv[1:]
root = pathlib.Path(folder).resolve()
state = pathlib.Path(os.environ.get('XDG_STATE_HOME',str(pathlib.Path.home()/'.local/state'))).resolve()/'ghostnet'
ignored = {'.git', '.venv', 'venv', 'node_modules', '.ghostnet-build', '__pycache__', 'target', 'bin', 'obj', '.build', '.gradle', '.dart_tool', 'zig-out', '.zig-cache'}
suffixes = {'.c','.cc','.cpp','.cxx','.h','.hpp','.hxx','.py','.rs','.go','.java','.js','.mjs','.cjs','.ts','.mts','.cts','.json','.toml','.txt','.cs','.sh','.rb','.php','.lua','.swift','.kt','.dart','.zig','.xml','.gradle','.kts','.cmake','.yaml','.yml','.lock'}
filenames = {'Makefile','GNUmakefile','makefile','ghostnet.conf'}
def snapshot():
    result = {}
    for directory, dirs, files in os.walk(root, followlinks=False):
        dirs[:] = [d for d in dirs if d not in ignored and not pathlib.Path(directory,d).is_symlink() and pathlib.Path(directory,d).resolve() != state]
        for name in files:
            path = pathlib.Path(directory,name)
            if path.suffix not in suffixes and name not in filenames: continue
            if path.is_symlink(): continue
            try:
                stat = path.stat(); result[str(path.relative_to(root))] = (stat.st_mtime_ns,stat.st_size)
            except OSError: pass
    return result
command = [bash_executable,launcher,'run','--target','native','--no-animation','--mode',mode]
if entry: command += ['--run-file',entry]
command += [str(root)]
env = dict(os.environ, BAN_NO_ANIMATION='1')
child = None
job = None
stopping = False
if host == 'windows':
    # Closing the job also stops descendants after their original parent exits.
    # https://learn.microsoft.com/windows/win32/procthread/job-objects
    import ctypes
    from ctypes import wintypes
    class BasicLimits(ctypes.Structure):
        _fields_ = [('process_time',ctypes.c_int64),('job_time',ctypes.c_int64),('flags',wintypes.DWORD),('min_working',ctypes.c_size_t),('max_working',ctypes.c_size_t),('active',wintypes.DWORD),('affinity',ctypes.c_size_t),('priority',wintypes.DWORD),('scheduling',wintypes.DWORD)]
    class ExtendedLimits(ctypes.Structure):
        _fields_ = [('basic',BasicLimits),('io',ctypes.c_uint64*6),('process_memory',ctypes.c_size_t),('job_memory',ctypes.c_size_t),('peak_process',ctypes.c_size_t),('peak_job',ctypes.c_size_t)]
    kernel = ctypes.WinDLL('kernel32',use_last_error=True)
    kernel.CreateJobObjectW.argtypes = [ctypes.c_void_p,wintypes.LPCWSTR]
    kernel.CreateJobObjectW.restype = wintypes.HANDLE
    kernel.SetInformationJobObject.argtypes = [wintypes.HANDLE,ctypes.c_int,ctypes.c_void_p,wintypes.DWORD]
    kernel.SetInformationJobObject.restype = wintypes.BOOL
    kernel.AssignProcessToJobObject.argtypes = [wintypes.HANDLE,wintypes.HANDLE]
    kernel.AssignProcessToJobObject.restype = wintypes.BOOL
    kernel.CloseHandle.argtypes = [wintypes.HANDLE]
    kernel.CloseHandle.restype = wintypes.BOOL
    def new_job():
        handle = kernel.CreateJobObjectW(None,None)
        if not handle: raise ctypes.WinError(ctypes.get_last_error())
        limits = ExtendedLimits(); limits.basic.flags = 0x2000
        if not kernel.SetInformationJobObject(handle,9,ctypes.byref(limits),ctypes.sizeof(limits)):
            error = ctypes.get_last_error(); kernel.CloseHandle(handle); raise ctypes.WinError(error)
        return handle

def signal_group(signum):
    try:
        os.killpg(child.pid,signum); return True
    except ProcessLookupError: return False
    except PermissionError:
        # Darwin can reject a group signal after the group leader has exited.
        # Signal remaining processes owned by this user individually.
        child.poll()
        processes = subprocess.run(['ps','-axo','pid=,pgid=,uid='],capture_output=True,text=True,check=True,timeout=3)
        members = []
        for line in processes.stdout.splitlines():
            values = line.split()
            if len(values) == 3 and int(values[1]) == child.pid and int(values[2]) == os.getuid(): members.append(int(values[0]))
        for pid in members:
            try: os.kill(pid,signum)
            except ProcessLookupError: pass
        return bool(members)

def stop_child():
    global child, job
    if child is None: return
    if host == 'windows':
        if job:
            kernel.CloseHandle(job); job = None
        elif child.poll() is None:
            subprocess.run(['taskkill.exe','/PID',str(child.pid),'/T','/F'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    else:
        # The process group may still contain children after its leader exits.
        signal_group(signal.SIGTERM)
        deadline = time.monotonic()+2
        while time.monotonic() < deadline:
            child.poll()
            if not signal_group(0): break
            time.sleep(.1)
        signal_group(signal.SIGKILL)
    try: child.wait(timeout=2)
    except subprocess.TimeoutExpired: child.kill(); child.wait()
    child = None

def interrupted(signum, frame):
    global stopping
    stopping = True
signal.signal(signal.SIGINT,interrupted)
signal.signal(signal.SIGTERM,interrupted)
def start():
    global child, job
    print('[WATCH] '+('Сборка и запуск; Ctrl+C для остановки' if lang == 'ru' else 'Build and run; Ctrl+C to stop'),flush=True)
    if host == 'windows': job = new_job()
    child = subprocess.Popen(command,cwd=root,env=env,start_new_session=(host != 'windows'))
    if host == 'windows' and not kernel.AssignProcessToJobObject(job,int(child._handle)):
        error = ctypes.get_last_error(); stop_child(); raise ctypes.WinError(error)
try:
    previous = snapshot(); start()
    while not stopping:
        time.sleep(.25)
        current = snapshot()
        if current == previous: continue
        # Require one stable interval before rebuilding during a burst of writes.
        time.sleep(.25)
        stable = snapshot()
        if stable != current: continue
        previous = stable; stop_child(); start()
finally:
    stop_child()
    if host == 'windows' and job: kernel.CloseHandle(job)
PYWATCH
}

project_doctor() {
    local failed=0 tool resolved
    printf '[DOCTOR] %s\n' "$(ui 'Tools, versions and environment' 'Инструменты, версии и окружение')"
    check_dependencies || failed=1
    for tool in "${required_compilers[@]}"; do
        resolved=$(command -v "$tool") || continue
        printf '[PATH] %s -> %s\n' "$tool" "$resolved"
        case "${tool##*/}" in java|javac) "$tool" -version 2>&1 | head -n 1 ;; *) "$tool" --version 2>&1 | head -n 1 ;; esac
    done
    if [[ "$has_py" -eq 1 ]]; then
        if [[ ! -f "$TARGET_DIR/.venv/pyvenv.cfg" ]]; then
            printf '[DOCTOR] %s\n' "$(ui 'No project .venv; run ghostnet setup .' 'Нет окружения .venv; выполните ghostnet setup .')"
            [[ ! -f "$TARGET_DIR/requirements.txt" ]] || failed=1
        elif [[ ! -x "$TARGET_DIR/.venv/bin/python" && ! -x "$TARGET_DIR/.venv/Scripts/python.exe" ]]; then
            printf '[DOCTOR] .venv: %s\n' "$(ui 'Interpreter missing; repair .venv, then run ghostnet setup .' 'Интерпретатор не найден; восстановите .venv, затем выполните ghostnet setup .')"
            failed=1
        else
            "$PYTHON_BIN" -m pip check || failed=1
            if [[ -f "$TARGET_DIR/requirements.txt" ]]; then
                "$PYTHON_BIN" - "$TARGET_DIR/requirements.txt" <<'PYDEPS' || failed=1
import importlib.metadata, sys
from pip._vendor.packaging.requirements import Requirement, InvalidRequirement
missing = False
for line in open(sys.argv[1], encoding='utf-8'):
    line = line.strip()
    if not line or line.startswith('#'): continue
    try: requirement = Requirement(line.split(' #',1)[0])
    except InvalidRequirement:
        print('[DOCTOR] Review requirement:', line); missing = True; continue
    if requirement.marker and not requirement.marker.evaluate(): continue
    name = requirement.name
    try:
        version = importlib.metadata.version(name)
        print('[PACKAGE]', name, version)
        if requirement.specifier and not requirement.specifier.contains(version, prereleases=True):
            print('[MISMATCH]', line, '-> ghostnet setup .'); missing = True
    except importlib.metadata.PackageNotFoundError:
        print('[MISSING]', name, '-> ghostnet setup .'); missing = True
sys.exit(int(missing))
PYDEPS
            fi
        fi
    fi
    if [[ "$PROJECT_BUILDER" == node && ! -d "$TARGET_DIR/node_modules" ]]; then
        printf '[DOCTOR] %s\n' "$(ui 'No node_modules; run ghostnet setup .' 'Нет node_modules; выполните ghostnet setup .')"; failed=1
    fi
    return "$failed"
}

project_setup() {
    local python_path stage
    printf '[SETUP] %s\n' "$(ui 'Preparing project dependencies' 'Подготовка зависимостей проекта')"
    check_dependencies || return 1
    TARGET_DIR=$(cd -- "$TARGET_DIR" && pwd) || return 1
    project_command() { (cd -- "$TARGET_DIR" && "$@"); }
    if [[ "$has_py" -eq 1 && ( "$PROJECT_BUILDER" == python || -z "$PROJECT_BUILDER" || "$PROJECT_BUILDER" == none ) ]]; then
        [[ ! -L "$TARGET_DIR/.venv" ]] || { printf '[SETUP] .venv: %s\n' "$(ui 'Symlinks are not supported.' 'Символические ссылки не поддерживаются.')" >&2; return 1; }
        if [[ -e "$TARGET_DIR/.venv" && ! -f "$TARGET_DIR/.venv/pyvenv.cfg" ]]; then
            printf '[SETUP] .venv: %s\n' "$(ui 'Existing folder is not a virtual environment.' 'Существующая папка не является виртуальным окружением.')" >&2; return 1
        fi
        if [[ ! -d "$TARGET_DIR/.venv" ]]; then
            "$PYTHON_BIN" -m venv "$TARGET_DIR/.venv" || { printf '[SETUP] %s\n' "$(ui 'Could not create .venv; install Python venv support.' 'Не удалось создать .venv; установите поддержку Python venv.')" >&2; return 1; }
        fi
        python_path="$TARGET_DIR/.venv/bin/python"
        [[ ! -x "$TARGET_DIR/.venv/Scripts/python.exe" ]] || python_path="$TARGET_DIR/.venv/Scripts/python.exe"
        [[ -x "$python_path" ]] || { printf '[SETUP] %s\n' "$(ui 'The .venv interpreter is missing.' 'Интерпретатор .venv не найден.')" >&2; return 1; }
        if [[ -f "$TARGET_DIR/requirements.txt" ]]; then
            run_build "requirements.txt" project_command "$python_path" -m pip install -r requirements.txt || { printf '[SETUP] %s\n' "$(ui 'Failed to install requirements.txt; see pip output above.' 'Не удалось установить requirements.txt; см. вывод pip выше.')" >&2; return 1; }
        elif [[ -f "$TARGET_DIR/pyproject.toml" ]] && "$python_path" -c 'import re,sys;sys.exit(not bool(re.search(r"(?m)^\s*\[build-system\]",open(sys.argv[1]).read())))' "$TARGET_DIR/pyproject.toml"; then
            run_build "Python package" project_command "$python_path" -m pip install . || return 1
        else
            printf '[SETUP] %s\n' "$(ui '.venv ready; no dependency manifest to install.' '.venv готово; файл зависимостей для установки не найден.')"
        fi
        return 0
    fi
    case "$PROJECT_BUILDER" in
        cargo) if [[ -f "$TARGET_DIR/Cargo.lock" ]]; then project_command cargo fetch --locked; else project_command cargo fetch; fi ;;
        node) if [[ -f "$TARGET_DIR/package-lock.json" || -f "$TARGET_DIR/npm-shrinkwrap.json" ]]; then project_command npm ci; else project_command npm install; fi ;;
        go) project_command go mod download ;;
        dotnet) for stage in "${DOTNET_PROJECTS[@]}"; do project_command dotnet restore "$stage" || return 1; done ;;
        maven) project_manager dependency:resolve ;;
        gradle) project_manager dependencies ;;
        swift) project_command swift package resolve ;;
        cmake)
            [[ ! -L "$TARGET_DIR/.ghostnet-build" && ! -L "$TARGET_DIR/.ghostnet-build/$HOST_KIND" ]] || return 1
            project_command cmake -S . -B ".ghostnet-build/$HOST_KIND" -G Ninja -DCMAKE_BUILD_TYPE=Release ;;
        *) printf '[SETUP] %s\n' "$(ui 'No standard dependency installer detected; use the project instructions.' 'Стандартный установщик зависимостей не найден; следуйте инструкции проекта.')" ;;
    esac
}

case "$ACTION" in
    clean) clean_inventory clean; exit $? ;;
    watch)
        [[ "$DISPLAY_TARGET" == "$HOST_KIND" ]] || feature_error "$(ui 'watch supports --target native only.' 'watch поддерживает только --target native.')"
        project_watch; exit $? ;;
    doctor) project_doctor; exit $? ;;
    setup) project_setup; exit $? ;;
    check) check_dependencies; exit $? ;;
    install) install_dependencies; exit $? ;;
    auto)
        if ! check_dependencies; then
            install_dependencies || exit 1
        fi
        ;;
    build|test) check_dependencies || exit 1 ;;
esac

if command -v "$PYTHON_BIN" >/dev/null 2>&1; then
    CLEAN_BASE=$(mktemp "${TMPDIR:-/tmp}/ghostnet-outputs.XXXXXX" 2>/dev/null) || CLEAN_BASE=""
    [[ -z "$CLEAN_BASE" ]] || clean_inventory begin >/dev/null 2>&1 || true
fi

echo -e "${GREEN}[BUILD]${RESET} ${WHITE}Project folder ->${RESET} $TARGET_DIR"
echo -e "${GREEN}[BUILD]${RESET} ${WHITE}Target platform ->${RESET} $DISPLAY_TARGET"

if [[ "$ACTION" != "test" && -t 0 && -t 1 && -z "$RUN_CHOICE_SET" ]]; then
    choose_menu "Run after building?" 0 "Build only" "Build and run"
    RUN_AFTER="$MENU_SELECTED"
fi

# Project builds keep related files together and run from the project directory.
if [[ -n "$PROJECT_BUILDER" ]]; then
    TARGET_DIR=$(cd -- "$TARGET_DIR" && pwd) || exit 1
    printf '[BUILD] Project builder -> %s\n' "$PROJECT_BUILDER"
    project_platform="$DISPLAY_TARGET"
    [[ "$BUILD_TARGET" != "both" ]] || project_platform="$HOST_KIND"
    project_binary=".ghostnet-build/$project_platform/$PROJECT_OUTPUT"
    [[ "$project_platform" != "windows" ]] || project_binary+=".exe"
    project_command() { (cd -- "$TARGET_DIR" && "$@"); }
    # Never traverse a user-provided symlink for generated output.
    [[ ! -L "$TARGET_DIR/.ghostnet-build" ]] || project_error ".ghostnet-build must not be a symlink."
    platforms=("$project_platform")
    [[ "$BUILD_TARGET" != "both" ]] || platforms+=(windows)
    if [[ "$PROJECT_BUILDER" == "cpp" || "$PROJECT_BUILDER" == "cmake" ]]; then
        for platform in "${platforms[@]}"; do
            build_dir=".ghostnet-build/$platform"
            [[ ! -L "$TARGET_DIR/$build_dir" ]] || project_error "Build folder must not be a symlink: $build_dir"
            mkdir -p -- "$TARGET_DIR/$build_dir" || exit 1
            if [[ "$PROJECT_BUILDER" == "cpp" ]]; then
                binary="$build_dir/$PROJECT_OUTPUT"
                compiler="$LINUX_CXX"
                [[ "$platform" != "windows" ]] || { binary+=".exe"; compiler="$WIN_CXX"; }
                [[ ! -L "$TARGET_DIR/$binary" ]] || project_error "Output must not be a symlink: $binary"
                for source_path in "${PROJECT_SOURCES[@]}"; do
                    [[ ! "$TARGET_DIR/$binary" -ef "$TARGET_DIR/$source_path" ]] || project_error "Output would overwrite a source: $source_path"
                done
                include_flags=()
                for include in "${PROJECT_INCLUDES[@]}"; do include_flags+=(-I "$include"); done
                contains_c=0
                for source_path in "${PROJECT_SOURCES[@]}"; do [[ "$source_path" != *.c ]] || contains_c=1; done
                if [[ "$contains_c" -eq 1 ]]; then
                    run_build "$platform project" project_command mixed_c_project "$platform" "$binary" || exit 1
                elif [[ "$platform" == "windows" ]]; then
                    if [[ "$WIN_METHOD" == "2" ]]; then
                        run_build "$platform project" project_command "$compiler" "${CPP_FLAGS[@]}" "${include_flags[@]}" "${PROJECT_SOURCES[@]}" -o "$binary" "${WIN_FLAGS_METHOD2[@]}" || exit 1
                    elif ! run_build "$platform project" project_command "$compiler" "${CPP_FLAGS[@]}" "${include_flags[@]}" "${PROJECT_SOURCES[@]}" -o "$binary" "${WIN_FLAGS_METHOD1[@]}"; then
                        [[ "$WIN_METHOD" == "auto" ]] || exit 1
                        run_build "$platform project (fallback)" project_command "$compiler" "${CPP_FLAGS[@]}" "${include_flags[@]}" "${PROJECT_SOURCES[@]}" -o "$binary" "${WIN_FLAGS_METHOD2[@]}" || exit 1
                    fi
                else
                    run_build "$platform project" project_command "$compiler" "${CPP_FLAGS[@]}" "${include_flags[@]}" "${PROJECT_SOURCES[@]}" -o "$binary" || exit 1
                fi
            else
                run_build "CMake configure" project_command cmake -S . -B "$build_dir" -G Ninja -DCMAKE_BUILD_TYPE=Release || exit 1
                run_build "CMake build" project_command cmake --build "$build_dir" --config Release || exit 1
            fi
        done
    elif [[ "$PROJECT_BUILDER" == "make" ]]; then
        run_build "Make project" project_command make || exit 1
    fi
    if [[ "$PROJECT_BUILDER" == "cargo" ]]; then
        run_build "Cargo build" project_command cargo build || exit 1
    fi
    case "$PROJECT_BUILDER" in go|node|dotnet|maven|gradle|swift|zig) build_external_project || exit $? ;; esac
    for src in "${sources[@]}"; do
        run_build "$src" "$PYTHON_BIN" -m py_compile "$src" || exit 1
    done
    if [[ "$ACTION" == "test" ]]; then
        case "$PROJECT_BUILDER" in
            go|node|dotnet|maven|gradle|swift|zig) test_external_project ;;
            cmake) run_build "CMake tests" project_command ctest --test-dir ".ghostnet-build/$project_platform" --output-on-failure ;;
            make) run_build "Make tests" project_command make test ;;
            cargo) run_build "Cargo tests" project_command cargo test ;;
            python|none)
                [[ -d "$TARGET_DIR/tests" ]] || project_error "Python tests folder not found."
                run_build "Python tests" project_command "$PYTHON_BIN" -m unittest discover -s tests -v ;;
            *) project_error "Define project tests with CMake, Make, Cargo or Python." ;;
        esac
        exit $?
    fi
    [[ -z "$CLEAN_BASE" ]] || clean_inventory record >/dev/null 2>&1 || true
    [[ "$ACTION" == test ]] || record_recent
    if [[ "$RUN_AFTER" == "1" ]]; then
        entry="${RUN_FILE:-$PROJECT_RUN}"
        case "$PROJECT_BUILDER" in go|node|dotnet|swift) run_external_project; exit $? ;; esac
        if [[ -z "$entry" && "$PROJECT_BUILDER" == "cargo" ]]; then
            project_command cargo run -- "${PROJECT_ARGS[@]}"
            exit $?
        fi
        if [[ -z "$entry" && "$PROJECT_BUILDER" == "cpp" ]]; then entry="$project_binary"; fi
        [[ -n "$entry" ]] || select_project_entry
        [[ -n "$entry" ]] || project_error "Set run= in ghostnet.conf or --run-file PATH for this project."
        entry="${entry//\{target\}/$project_platform}"
        extension=""; [[ "$project_platform" != "windows" ]] || extension=".exe"
        entry="${entry//\{exe\}/$extension}"
        relative_project_path "$entry" || project_error "Invalid run path: $entry"
        [[ -f "$TARGET_DIR/$entry" ]] || project_error "Run file not found: $entry"
        remember_entry "$entry"
        printf '[RUN] Running -> %s\n' "$entry"
        case "$entry" in
            *.py) project_command "$PYTHON_BIN" "$entry" "${PROJECT_ARGS[@]}" ;;
            *.jar) project_command java -jar "$entry" "${PROJECT_ARGS[@]}" ;;
            *.js|*.mjs|*.cjs) project_command node "$entry" "${PROJECT_ARGS[@]}" ;;
            *.sh) project_command bash "$entry" "${PROJECT_ARGS[@]}" ;;
            *.rb) project_command ruby "$entry" "${PROJECT_ARGS[@]}" ;;
            *.php) project_command php "$entry" "${PROJECT_ARGS[@]}" ;;
            *.lua) project_command lua "$entry" "${PROJECT_ARGS[@]}" ;;
            *.exe)
                if [[ "$HOST_KIND" == "windows" || "$project_platform" != "windows" ]]; then
                    project_command "./$entry" "${PROJECT_ARGS[@]}"
                elif command -v wine >/dev/null 2>&1; then
                    project_command wine "$entry" "${PROJECT_ARGS[@]}"
                else
                    project_error "Running Windows executables requires Wine."
                fi ;;
            *) project_command "./$entry" "${PROJECT_ARGS[@]}" ;;
        esac
        run_status=$?
        [[ "$run_status" -eq 0 ]] || { printf '[ERROR] Program exited with code %d.\n' "$run_status" >&2; exit "$run_status"; }
    fi
    printf '[OK] Done.\n'
    exit 0
fi

# Only native sources that share a stem need distinct output filenames.
output_base() {
    local source="$1" other
    local stem="${source%.*}"
    for other in "${sources[@]}"; do
        if [[ "$other" != "$source" && "$other" != *.py && "${other%.*}" == "$stem" ]]; then
            printf '%s-%s' "$stem" "${source##*.}"
            return
        fi
    done
    printf '%s' "$stem"
}

# Plan all native outputs before compiling so no source or earlier result is overwritten.
reserved_outputs=()
output_bases=()
base_is_available() {
    local candidate="$1" path existing
    local paths=()
    if [[ "$BUILD_TARGET" == "linux" || "$BUILD_TARGET" == "both" ]]; then
        paths+=("$candidate")
    fi
    if [[ "$BUILD_TARGET" == "windows" || "$BUILD_TARGET" == "both" ]]; then
        paths+=("${candidate}.exe")
    fi
    for path in "${paths[@]}"; do
        for existing in "${sources[@]}" "${reserved_outputs[@]}"; do
            if [[ "$path" == "$existing" || "$path" -ef "$existing" ]]; then
                return 1
            fi
        done
    done
    return 0
}

for src in "${sources[@]}"; do
    if [[ "$src" == *.py ]]; then
        output_bases+=("")
        continue
    fi
    base=$(output_base "$src")
    suffix=0
    while ! base_is_available "$base"; do
        suffix=$((suffix + 1))
        base="${src%.*}-${src##*.}-$suffix"
    done
    output_bases+=("$base")
    if [[ "$BUILD_TARGET" == "linux" || "$BUILD_TARGET" == "both" ]]; then
        reserved_outputs+=("$base")
    fi
    if [[ "$BUILD_TARGET" == "windows" || "$BUILD_TARGET" == "both" ]]; then
        reserved_outputs+=("${base}.exe")
    fi
done

built_files=()
built_kinds=()
fail=0

for ((source_index = 0; source_index < ${#sources[@]}; source_index++)); do
    src="${sources[$source_index]}"
    base="${output_bases[$source_index]}"
    case "$src" in
        *.c|*.go|*.java|*.js|*.mjs|*.cjs|*.ts|*.mts|*.cts|*.cs|*.sh|*.rb|*.php|*.lua|*.swift|*.kt|*.dart|*.zig)
            build_extra_source "$src" "$base" "$source_index" || fail=1
            continue ;;
        *.py)
            if run_build "$src" "$PYTHON_BIN" -m py_compile "$src"; then
                built_files+=("$src")
                built_kinds+=(script)
            else
                fail=1
            fi
            continue
            ;;
        *.rs)
            crate="${src##*/}"
            crate="ghostnet_${crate%.*}"
            crate="${crate//[^a-zA-Z0-9_]/_}"
            if [[ "$BUILD_TARGET" == "linux" || "$BUILD_TARGET" == "both" ]]; then
                if run_build "$HOST_LABEL: $src" rustc --edition=2021 --crate-name "$crate" -O "$src" -o "$base"; then
                    built_files+=("$base")
                    built_kinds+=(native)
                else
                    fail=1
                    continue
                fi
            fi
            if [[ "$BUILD_TARGET" == "windows" || "$BUILD_TARGET" == "both" ]]; then
                if run_build "Windows: $src" rustc --edition=2021 --crate-name "$crate" -O \
                    --target x86_64-pc-windows-gnu -C "linker=$WIN_CXX" "$src" -o "${base}.exe"; then
                    if [[ "$BUILD_TARGET" == "windows" ]]; then
                        built_files+=("${base}.exe")
                        built_kinds+=(windows)
                    fi
                else
                    fail=1
                fi
            fi
            continue
            ;;
    esac

    if [[ "$BUILD_TARGET" == "linux" || "$BUILD_TARGET" == "both" ]]; then
        echo -e "${GREEN}[BUILD]${RESET} ${HOST_LABEL}: $src -> $base"
        if ! run_build "$HOST_LABEL: $src" "$LINUX_CXX" "${CPP_FLAGS[@]}" "$src" -o "$base"; then
            echo -e "${RED}[ERROR]${RESET} Failed to build ${HOST_LABEL} binary for $src"
            fail=1
            continue
        fi
        built_files+=("$base")
        built_kinds+=(native)
    fi

    if [[ "$BUILD_TARGET" == "windows" || "$BUILD_TARGET" == "both" ]]; then
        if [[ "$WIN_METHOD" == "1" ]]; then
            echo -e "${GREEN}[BUILD]${RESET} Windows (method 1): $src -> ${base}.exe"
            if ! run_build "Windows (method 1): $src" "$WIN_CXX" "${CPP_FLAGS[@]}" "$src" -o "${base}.exe" "${WIN_FLAGS_METHOD1[@]}"; then
                echo -e "${RED}[ERROR]${RESET} Failed to build Windows binary for $src (method 1)."
                fail=1
            fi
        elif [[ "$WIN_METHOD" == "2" ]]; then
            echo -e "${GREEN}[BUILD]${RESET} Windows (method 2): $src -> ${base}.exe"
            if ! run_build "Windows (method 2): $src" "$WIN_CXX" "${CPP_FLAGS[@]}" "$src" -o "${base}.exe" "${WIN_FLAGS_METHOD2[@]}"; then
                echo -e "${RED}[ERROR]${RESET} Failed to build Windows binary for $src (method 2)."
                fail=1
            fi
        else
            echo -e "${GREEN}[BUILD]${RESET} Windows (method 1): $src -> ${base}.exe"
            if ! run_build "Windows (method 1): $src" "$WIN_CXX" "${CPP_FLAGS[@]}" "$src" -o "${base}.exe" "${WIN_FLAGS_METHOD1[@]}"; then
                echo -e "${YELLOW}[WARN]${RESET} Method 1 failed. Trying method 2 (full static fallback)..."
                if ! run_build "Windows (method 2): $src" "$WIN_CXX" "${CPP_FLAGS[@]}" "$src" -o "${base}.exe" "${WIN_FLAGS_METHOD2[@]}"; then
                    echo -e "${RED}[ERROR]${RESET} Failed to build Windows binary for $src (both methods)."
                    fail=1
                else
                    echo -e "${GREEN}[OK]${RESET} Windows build completed using method 2."
                fi
            fi
        fi
        if [[ "$BUILD_TARGET" == "windows" && "$fail" -eq 0 ]]; then
            built_files+=("${base}.exe")
            built_kinds+=(windows)
        fi
    fi
done

if [[ "$fail" -ne 0 ]]; then
    exit 1
fi

[[ -z "$CLEAN_BASE" ]] || clean_inventory record "${built_files[@]}" >/dev/null 2>&1 || true
record_recent

if [[ "$RUN_AFTER" == "1" ]]; then
    run_index=-1
    if [[ -n "$RUN_FILE" ]]; then
        run_candidate="$RUN_FILE"
        [[ "$run_candidate" == */* ]] || run_candidate="$TARGET_DIR/$run_candidate"
        for ((i = 0; i < ${#built_files[@]}; i++)); do
            if [[ "$run_candidate" -ef "${built_files[$i]}" || ( "${built_kinds[$i]}" == "windows" && "${run_candidate%.exe}.exe" -ef "${built_files[$i]}" ) ]]; then
                run_index="$i"
                break
            fi
        done
        if [[ "$run_index" -lt 0 ]]; then
            printf '[ERROR] Requested file is not among the build results: %s\n' "$RUN_FILE" >&2
            exit 1
        fi
    elif [[ ${#built_files[@]} -eq 1 ]]; then
        run_index=0
    elif [[ ${#built_files[@]} -gt 1 && -t 0 && -t 1 ]]; then
        choose_menu "Which program should run?" 0 "${built_files[@]}"
        run_index="$MENU_SELECTED"
    else
        printf '[ERROR] Set BAN_RUN_FILE to run one of multiple programs.\n' >&2
        exit 1
    fi

    run_target="${built_files[$run_index]}"
    [[ "$run_target" == */* ]] || run_target="./$run_target"
    printf '%b[RUN]%b Running -> %s\n' "$GREEN" "$RESET" "$run_target"
    case "${built_kinds[$run_index]}" in
        node|java|csharp|kotlin|bash|ruby|php|lua) run_language_entry "$run_target" "${built_kinds[$run_index]}" "${PROJECT_ARGS[@]}" ;;
        script) "$PYTHON_BIN" "$run_target" ;;
        windows)
            if [[ "$HOST_KIND" == "windows" ]]; then
                "$run_target"
            elif ! command -v wine >/dev/null 2>&1; then
                printf '[ERROR] Running .exe files on Linux requires Wine.\n' >&2
                exit 1
            else
                wine "$run_target"
            fi
            ;;
        native) "$run_target" ;;
    esac
    run_status=$?
    if [[ "$run_status" -ne 0 ]]; then
        printf '[ERROR] Program exited with code %d.\n' "$run_status" >&2
        exit "$run_status"
    fi
fi

echo -e "${GREEN}[OK]${RESET} Done."
