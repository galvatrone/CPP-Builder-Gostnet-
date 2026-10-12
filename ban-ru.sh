#!/usr/bin/env bash

set -u
shopt -s nullglob

HOST_SYSTEM=$(uname -s)
case "$HOST_SYSTEM" in
    Linux) HOST_KIND="linux"; HOST_LABEL="Linux" ;;
    Darwin) HOST_KIND="macos"; HOST_LABEL="macOS" ;;
    MINGW*|MSYS*) HOST_KIND="windows"; HOST_LABEL="Windows" ;;
    *) printf '[ERROR] Неподдерживаемая система: %s\n' "$HOST_SYSTEM" >&2; exit 1 ;;
esac
if [[ "${BASH_VERSINFO[0]}" -lt 4 || ( "${BASH_VERSINFO[0]}" -eq 4 && "${BASH_VERSINFO[1]}" -lt 4 ) ]]; then
    printf '[ERROR] Нужен Bash 4.4 или новее. На macOS: brew install bash.\n' >&2
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
INTERFACE_LANG=ru
INIT_TYPE=""

usage() {
    cat <<'HELP'
Команды: ghostnet-ru build|run|test|check [параметры] [папка]

GHOSTNET — сборка программ для Linux, Windows и macOS

Запуск без параметров: меню со стрелками ↑/↓ и Enter.

  --type TYPE        Шаблон для ghostnet init
  --check            Проверить необходимые инструменты
  --install-deps     Установить недостающие инструменты
  --auto             Проверить окружение и собрать без лишних вопросов
  --target TARGET    native, linux, macos, windows или both
  --mode MODE        auto, files, project, cmake, make, cargo или python
  --run-file PATH    Точка запуска проекта (путь от папки проекта)
  --run              Запустить программу после успешной сборки
  --yes              Разрешить установку пакетов без дополнительного вопроса
  --no-animation     Отключить анимации
  --version          GHOSTNET 1.2.0
  --help             Показать справку

Пример: bash ban.sh --auto --target linux --run ./project
Без --yes установка пакетов требует подтверждения в терминале.
HELP
}

while [[ $# -gt 0 ]]; do
    case "$1" in
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
                printf '[ERROR] После --target нужна платформа.\n' >&2
                exit 2
            fi
            BUILD_TARGET="$2"
            shift
            ;;
        --mode|--run-file)
            [[ $# -ge 2 ]] || { printf '[ERROR] %s требует значение.\n' "$1" >&2; exit 2; }
            if [[ "$1" == "--mode" ]]; then BUILD_MODE="$2"; else RUN_FILE="$2"; fi
            shift ;;
        --run) RUN_AFTER=1; RUN_CHOICE_SET=1 ;;
        --yes) ASSUME_YES=1 ;;
        --no-animation) BAN_NO_ANIMATION=1 ;;
        --version) printf 'GHOSTNET 1.2.0\n'; exit 0 ;;
        --help|-h) usage; exit 0 ;;
        --)
            shift
            if [[ $# -eq 1 && -z "$TARGET_DIR" ]]; then
                TARGET_DIR="$1"
                shift
                break
            fi
            printf '[ERROR] Укажите одну папку проекта.\n' >&2
            exit 2
            ;;
        -*) printf '[ERROR] Неизвестная опция: %s\n' "$1" >&2; exit 2 ;;
        *)
            if [[ -n "$TARGET_DIR" ]]; then
                printf '[ERROR] Укажите одну папку проекта.\n' >&2
                exit 2
            fi
            TARGET_DIR="$1"
            ;;
    esac
    shift
done

case "$BUILD_MODE" in auto|files|project|cmake|make|cargo|python) ;; *) printf '[ERROR] Неверный режим сборки: %s\n' "$BUILD_MODE" >&2; exit 2 ;; esac

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
PYTHON_BIN="python3"
if [[ "$HOST_KIND" == "windows" ]]; then
    WIN_CXX="g++"
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
        "$@" || status=$?
    fi

    elapsed=$(( $(build_time_ms) - started ))
    if [[ "$status" -eq 0 ]]; then
        printf '%b[✓] %s  COMPLETE  %d.%ds%b\n' "$GREEN" "$label" "$((elapsed / 1000))" "$((elapsed % 1000 / 100))" "$RESET"
    else
        printf '%b[✗] %s  FAILED  %d.%ds%b\n' "$RED" "$label" "$((elapsed / 1000))" "$((elapsed % 1000 / 100))" "$RESET"
    fi
    if [[ -n "$BUILD_LOG" ]]; then
        cat -- "$BUILD_LOG"
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
            'C++ single file' 'C++ CMake' 'C single file' 'Rust / Cargo' 'Python' 'Go' 'Java' \
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
        choose_menu "GHOSTNET — главное меню (↑/↓ + Enter):" 2 \
            "Проверить окружение" \
            "Установить инструменты" \
            "Собрать программу" \
            "Полная автосборка" \
            "Выход" \
            "$(ui 'Inspect project' 'Паспорт проекта')" \
            "$(ui 'Supported languages' 'Поддерживаемые языки')" \
            "$(ui 'Create project' 'Создать проект')" \
            "$(ui 'Recent projects' 'Недавние проекты')"
        case "$MENU_SELECTED" in
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
    else
        ACTION="build"
    fi
fi

if [[ "$ACTION" == recent ]]; then recent_projects; fi

if [[ "$ACTION" == init ]]; then init_project; exit $?; fi

case "$ACTION" in
    check|install|build|auto|test|inspect) ;;
    *) printf '[ERROR] Неверный режим: %s\n' "$ACTION" >&2; exit 2 ;;
esac

[[ "$ACTION" != inspect ]] || BUILD_TARGET="${BUILD_TARGET:-native}"

if [[ -z "$BUILD_TARGET" || "$BUILD_TARGET" == "native" ]]; then
    if [[ "$BUILD_TARGET" == "native" ]]; then
        BUILD_TARGET="$HOST_KIND"
    elif [[ "$HOST_KIND" == "windows" ]]; then
        BUILD_TARGET="windows"
    else
        platform_menu=("$HOST_LABEL" "Windows" "$HOST_LABEL и Windows")
        choose_menu "Платформа (↑/↓ + Enter):" 0 "${platform_menu[@]}"
        case "$MENU_SELECTED" in
            0) BUILD_TARGET="$HOST_KIND" ;;
            1) BUILD_TARGET="windows" ;;
            *) BUILD_TARGET="both" ;;
        esac
    fi
fi
if [[ "$HOST_KIND" == "windows" && "$BUILD_TARGET" != "windows" ]]; then
    printf '[ERROR] На Windows доступна только сборка для Windows.\n' >&2
    exit 1
fi
if [[ "$HOST_KIND" != "linux" && "$BUILD_TARGET" == "linux" ]]; then
    printf '[ERROR] Сборка для Linux требует Linux. Используйте --target native.\n' >&2
    exit 1
fi
if [[ "$BUILD_TARGET" == "macos" ]]; then
    if [[ "$HOST_KIND" != "macos" ]]; then
        printf '[ERROR] Сборка для macOS требует macOS.\n' >&2
        exit 1
    fi
    BUILD_TARGET="linux" # Internal native branch; labels use the actual host.
fi
if [[ "$BUILD_TARGET" != "linux" && "$BUILD_TARGET" != "windows" && "$BUILD_TARGET" != "both" ]]; then
    printf '[ERROR] Неверный BAN_BUILD_TARGET: %s\n' "$BUILD_TARGET" >&2
    exit 1
fi
DISPLAY_TARGET="$BUILD_TARGET"
[[ "$HOST_KIND" != "macos" || "$BUILD_TARGET" != "linux" ]] || DISPLAY_TARGET="macos"

sources=()
has_cpp=0
has_py=0
has_rs=0

if [[ "$ACTION" == "build" || "$ACTION" == "auto" || "$ACTION" == "test" || -n "$TARGET_DIR" || -n "$TARGET_DIR_PRESET" || -n "$SOURCE_FILE" ]]; then
    if [[ -z "$TARGET_DIR" ]]; then
        if [[ -n "$TARGET_DIR_PRESET" ]]; then
            TARGET_DIR="$TARGET_DIR_PRESET"
        elif [[ ( "$ACTION" == "build" || "$ACTION" == "auto" || "$ACTION" == "test" ) && -t 0 ]]; then
            read -r -p "Папка для компиляции (. по умолчанию): " TARGET_DIR || exit 1
        fi
    fi
    TARGET_DIR="${TARGET_DIR:-.}"
    [[ "$TARGET_DIR" == "/" ]] || TARGET_DIR="${TARGET_DIR%/}"
    if [[ ! -d "$TARGET_DIR" ]]; then
        printf '[ERROR] Папка не найдена: %s\n' "$TARGET_DIR" >&2
        exit 1
    fi
    sources=("$TARGET_DIR"/*.cpp "$TARGET_DIR"/*.cc "$TARGET_DIR"/*.cxx "$TARGET_DIR"/*.py "$TARGET_DIR"/*.rs)
    if [[ -n "$SOURCE_FILE" ]]; then
        case "$SOURCE_FILE" in
            *.cpp|*.cc|*.cxx|*.py|*.rs)
                if [[ -f "$SOURCE_FILE" ]]; then
                    sources=("$SOURCE_FILE")
                else
                    printf '[ERROR] Файл не найден: %s\n' "$SOURCE_FILE" >&2
                    exit 1
                fi
                ;;
            *) printf '[ERROR] Неподдерживаемый файл: %s\n' "$SOURCE_FILE" >&2; exit 1 ;;
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

# Literal project configuration: values are never evaluated as shell code.
project_error() { printf '[ERROR] %s\n' "$*" >&2; exit 1; }
relative_project_path() {
    [[ -n "$1" && "$1" != /* && "$1" != *\\* && "/$1/" != */../* ]]
}
PROJECT_BUILDER=""
PROJECT_OUTPUT="program"
PROJECT_RUN=""
PROJECT_SOURCES=() PROJECT_INCLUDES=() PROJECT_ARGS=()
if [[ "$BUILD_MODE" != "files" ]]; then
    if [[ -f "$TARGET_DIR/ghostnet.conf" ]]; then
        while IFS= read -r config_line || [[ -n "$config_line" ]]; do
            config_line="${config_line%$'\r'}"
            [[ -n "$config_line" && "$config_line" != \#* ]] || continue
            [[ "$config_line" == *=* ]] || project_error "Неверная строка ghostnet.conf: $config_line"
            key="${config_line%%=*}" value="${config_line#*=}"
            case "$key" in
                builder) PROJECT_BUILDER="$value" ;;
                source) relative_project_path "$value" || project_error "Неверный путь исходника: $value"; PROJECT_SOURCES+=("$value") ;;
                include) relative_project_path "$value" || project_error "Неверный путь заголовков: $value"; PROJECT_INCLUDES+=("$value") ;;
                output) [[ "$value" =~ ^[a-zA-Z0-9_-][a-zA-Z0-9_.-]*$ ]] || project_error "Неверное имя результата: $value"; PROJECT_OUTPUT="$value" ;;
                run) relative_project_path "$value" || project_error "Неверный путь запуска: $value"; PROJECT_RUN="$value" ;;
                arg) PROJECT_ARGS+=("$value") ;;
                *) project_error "Неизвестный ключ ghostnet.conf: $key" ;;
            esac
        done < "$TARGET_DIR/ghostnet.conf"
        PROJECT_BUILDER="${PROJECT_BUILDER:-cpp}"
    elif [[ -f "$TARGET_DIR/CMakeLists.txt" ]]; then
        PROJECT_BUILDER="cmake"
    elif [[ -f "$TARGET_DIR/Cargo.toml" ]]; then
        PROJECT_BUILDER="cargo"
    elif [[ -f "$TARGET_DIR/pyproject.toml" ]]; then
        PROJECT_BUILDER="python"
    elif [[ -f "$TARGET_DIR/GNUmakefile" || -f "$TARGET_DIR/Makefile" || -f "$TARGET_DIR/makefile" ]]; then
        PROJECT_BUILDER="make"
    fi
    case "$BUILD_MODE" in
        cmake|make|cargo|python) PROJECT_BUILDER="$BUILD_MODE" ;;
        project) PROJECT_BUILDER="${PROJECT_BUILDER:-cpp}" ;;
        auto)
            if [[ -z "$PROJECT_BUILDER" && ( "$ACTION" == "build" || "$ACTION" == "auto" || "$ACTION" == "test" ) && -t 0 && -t 1 ]]; then
                choose_menu "Режим сборки (↑/↓ + Enter):" 0 "Отдельные программы" "Один проект (связанные файлы C++)"
                [[ "$MENU_SELECTED" -eq 0 ]] || PROJECT_BUILDER="cpp"
            fi
            ;;
    esac
fi
if [[ -n "$PROJECT_BUILDER" ]]; then
    case "$PROJECT_BUILDER" in cpp|cmake|make|cargo|python|none) ;; *) project_error "Неверная система сборки: $PROJECT_BUILDER" ;; esac
    [[ -z "$SOURCE_FILE" ]] || project_error "BAN_SOURCE_FILE требует --mode files."
    if [[ "$PROJECT_BUILDER" == "cmake" || "$PROJECT_BUILDER" == "make" || "$PROJECT_BUILDER" == "cargo" || "$PROJECT_BUILDER" == "python" ]]; then
        if [[ "$BUILD_TARGET" == "both" || ( "$BUILD_TARGET" == "windows" && "$HOST_KIND" != "windows" ) ]]; then
            project_error "Эта система сборки поддерживает только --target native."
        fi
    fi
    if [[ "$PROJECT_BUILDER" == "cmake" ]]; then
        [[ -f "$TARGET_DIR/CMakeLists.txt" ]] || project_error "CMakeLists.txt не найден."
    elif [[ "$PROJECT_BUILDER" == "make" ]]; then
        [[ -f "$TARGET_DIR/GNUmakefile" || -f "$TARGET_DIR/Makefile" || -f "$TARGET_DIR/makefile" ]] || project_error "Makefile не найден."
    elif [[ "$PROJECT_BUILDER" == "cargo" ]]; then
        [[ -f "$TARGET_DIR/Cargo.toml" ]] || project_error "Cargo.toml не найден."
    elif [[ "$PROJECT_BUILDER" == "python" ]]; then
        [[ -f "$TARGET_DIR/pyproject.toml" ]] || project_error "pyproject.toml не найден."
        if [[ -z "$PROJECT_RUN" && -f "$TARGET_DIR/__main__.py" ]]; then PROJECT_RUN="__main__.py"; fi
    elif [[ "$PROJECT_BUILDER" == "cpp" ]]; then
        if [[ ${#PROJECT_SOURCES[@]} -eq 0 ]]; then
            for src in "$TARGET_DIR"/*.cpp "$TARGET_DIR"/*.cc "$TARGET_DIR"/*.cxx; do
                PROJECT_SOURCES+=("${src##*/}")
            done
        fi
        [[ ${#PROJECT_SOURCES[@]} -gt 0 ]] || project_error "Нет исходников C++ для проекта."
        for src in "${PROJECT_SOURCES[@]}"; do
            case "$src" in *.cpp|*.cc|*.cxx) ;; *) project_error "Неподдерживаемый исходник C++: $src" ;; esac
            [[ -f "$TARGET_DIR/$src" ]] || project_error "Исходник не найден: $src"
        done
        for include in "${PROJECT_INCLUDES[@]}"; do
            [[ -d "$TARGET_DIR/$include" ]] || project_error "Папка заголовков не найдена: $include"
        done
    fi
    # The project build tools own source discovery; Python checks remain explicit.
    sources=("$TARGET_DIR"/*.py)
    entry="${RUN_FILE:-$PROJECT_RUN}"
    if [[ "$entry" == *.py && -f "$TARGET_DIR/$entry" ]]; then
        sources+=("$TARGET_DIR/$entry")
    fi
    has_cpp=0 has_rs=0 has_py=0
    case "$PROJECT_BUILDER" in cpp) has_cpp=1 ;; esac
    [[ "$PROJECT_BUILDER" != "python" ]] || has_py=1
    if [[ -x "$TARGET_DIR/.venv/bin/python" ]]; then
        PYTHON_BIN=$(cd -- "$TARGET_DIR" && pwd)/.venv/bin/python
    elif [[ -x "$TARGET_DIR/.venv/Scripts/python.exe" ]]; then
        PYTHON_BIN=$(cd -- "$TARGET_DIR" && pwd)/.venv/Scripts/python.exe
    fi
    [[ ${#sources[@]} -eq 0 ]] || has_py=1
fi

project_passport
[[ "$ACTION" != inspect ]] || exit 0

if [[ -z "$PROJECT_BUILDER" && ( "$ACTION" == "build" || "$ACTION" == "auto" ) ]]; then
    if [[ ${#sources[@]} -eq 0 ]]; then
        printf '[ERROR] В папке нет поддерживаемых исходников: %s\n' "$TARGET_DIR" >&2
        exit 1
    fi
fi

if [[ "$has_cpp" -eq 1 && ( "$BUILD_TARGET" == "windows" || "$BUILD_TARGET" == "both" ) ]]; then
    if [[ -z "$WIN_METHOD" ]]; then
        if [[ "$ACTION" == "auto" || "$ACTION" == "check" || "$ACTION" == "install" ]]; then
            WIN_METHOD="auto"
        else
            choose_menu "Способ сборки Windows (↑/↓ + Enter):" 0 \
                "Автоматически (рекомендуется)" \
                "Статическая сборка" \
                "Расширенная статическая сборка"
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
    echo -e "${RED}[ERROR]${RESET} Неверный BAN_WIN_METHOD: $WIN_METHOD"
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
if [[ "$ACTION" == "test" && -z "$PROJECT_BUILDER" ]]; then project_error "Для тестирования нужен проект CMake, Make, Cargo или Python."; fi

check_dependencies() {
    local compiler missing=0
    [[ ! -x "$PYTHON_BIN" ]] && select_python
    for compiler in "${required_compilers[@]}"; do
        [[ "$compiler" != "python3" ]] || compiler="$PYTHON_BIN"
        if command -v "$compiler" >/dev/null 2>&1; then
            printf '%b[✓] %s — найден%b\n' "$GREEN" "$compiler" "$RESET"
        else
            printf '%b[✗] %s — не найден%b\n' "$RED" "$compiler" "$RESET"
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
            printf '[ERROR] Установите Homebrew или необходимые инструменты вручную.\n' >&2
            return 1
        fi
        manager="brew"
        command_args=(brew install)
    elif [[ "$HOST_KIND" == "windows" ]]; then
        if [[ "${MSYSTEM:-}" != "UCRT64" ]] || ! command -v pacman >/dev/null 2>&1; then
            printf '[ERROR] Запустите скрипт в MSYS2 UCRT64.\n' >&2
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
        printf '[ERROR] Поддерживаются apt-get, dnf и pacman. Установите инструменты вручную.\n' >&2
        return 1
    fi

    for compiler in "${required_compilers[@]}"; do
        command -v "$compiler" >/dev/null 2>&1 && continue
        case "$manager:$compiler" in
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
            *) printf '[ERROR] Нет пакета для инструмента: %s\n' "$compiler" >&2; return 1 ;;
        esac
        packages+=("$package")
    done
    if [[ ${#packages[@]} -eq 0 ]]; then
        printf '[OK] Все необходимые инструменты уже установлены.\n'
        return 0
    fi
    if [[ "$HOST_KIND" == "linux" && "$EUID" -ne 0 ]]; then
        if ! command -v sudo >/dev/null 2>&1; then
            printf '[ERROR] Для установки необходим sudo или запуск от root.\n' >&2
            return 1
        fi
        privilege=(sudo)
    fi
    printf 'Недостающие пакеты: %s\n' "${packages[*]}"
    printf 'Команда установки:'
    printf ' %q' "${privilege[@]}" "${command_args[@]}" "${packages[@]}"
    printf '\n'
    if [[ "$ASSUME_YES" -ne 1 ]]; then
        if [[ ! -t 0 || ! -t 1 ]]; then
            printf '[ERROR] Установка требует подтверждения в терминале или --yes.\n' >&2
            return 1
        fi
        choose_menu "Установить эти пакеты?" 0 "Отмена" "Установить"
        if [[ "$MENU_SELECTED" -ne 1 ]]; then
            printf 'Установка отменена.\n'
            return 1
        fi
    fi
    "${privilege[@]}" "${command_args[@]}" "${packages[@]}" || return 1
    hash -r
    check_dependencies
}

case "$ACTION" in
    check) check_dependencies; exit $? ;;
    install) install_dependencies; exit $? ;;
    auto)
        if ! check_dependencies; then
            install_dependencies || exit 1
        fi
        ;;
    build|test) check_dependencies || exit 1 ;;
esac

echo -e "${GREEN}[BUILD]${RESET} ${WHITE}Целевая папка ->${RESET} $TARGET_DIR"
echo -e "${GREEN}[BUILD]${RESET} ${WHITE}Режим платформы ->${RESET} $DISPLAY_TARGET"

if [[ "$ACTION" != "test" && -t 0 && -t 1 && -z "$RUN_CHOICE_SET" ]]; then
    choose_menu "Запустить после сборки?" 0 "Только собрать" "Собрать и запустить"
    RUN_AFTER="$MENU_SELECTED"
fi

# Project builds keep related files together and run from the project directory.
if [[ -n "$PROJECT_BUILDER" ]]; then
    TARGET_DIR=$(cd -- "$TARGET_DIR" && pwd) || exit 1
    printf '[BUILD] Система сборки -> %s\n' "$PROJECT_BUILDER"
    project_platform="$DISPLAY_TARGET"
    [[ "$BUILD_TARGET" != "both" ]] || project_platform="$HOST_KIND"
    project_binary=".ghostnet-build/$project_platform/$PROJECT_OUTPUT"
    [[ "$project_platform" != "windows" ]] || project_binary+=".exe"
    project_command() { (cd -- "$TARGET_DIR" && "$@"); }
    # Never traverse a user-provided symlink for generated output.
    [[ ! -L "$TARGET_DIR/.ghostnet-build" ]] || project_error ".ghostnet-build не должен быть символической ссылкой."
    platforms=("$project_platform")
    [[ "$BUILD_TARGET" != "both" ]] || platforms+=(windows)
    if [[ "$PROJECT_BUILDER" == "cpp" || "$PROJECT_BUILDER" == "cmake" ]]; then
        for platform in "${platforms[@]}"; do
            build_dir=".ghostnet-build/$platform"
            [[ ! -L "$TARGET_DIR/$build_dir" ]] || project_error "Папка сборки не должна быть символической ссылкой: $build_dir"
            mkdir -p -- "$TARGET_DIR/$build_dir" || exit 1
            if [[ "$PROJECT_BUILDER" == "cpp" ]]; then
                binary="$build_dir/$PROJECT_OUTPUT"
                compiler="$LINUX_CXX"
                [[ "$platform" != "windows" ]] || { binary+=".exe"; compiler="$WIN_CXX"; }
                [[ ! -L "$TARGET_DIR/$binary" ]] || project_error "Результат не должен быть символической ссылкой: $binary"
                for source_path in "${PROJECT_SOURCES[@]}"; do
                    [[ ! "$TARGET_DIR/$binary" -ef "$TARGET_DIR/$source_path" ]] || project_error "Результат перезапишет исходник: $source_path"
                done
                include_flags=()
                for include in "${PROJECT_INCLUDES[@]}"; do include_flags+=(-I "$include"); done
                if [[ "$platform" == "windows" ]]; then
                    if [[ "$WIN_METHOD" == "2" ]]; then
                        run_build "$platform: проект" project_command "$compiler" "${CPP_FLAGS[@]}" "${include_flags[@]}" "${PROJECT_SOURCES[@]}" -o "$binary" "${WIN_FLAGS_METHOD2[@]}" || exit 1
                    elif ! run_build "$platform: проект" project_command "$compiler" "${CPP_FLAGS[@]}" "${include_flags[@]}" "${PROJECT_SOURCES[@]}" -o "$binary" "${WIN_FLAGS_METHOD1[@]}"; then
                        [[ "$WIN_METHOD" == "auto" ]] || exit 1
                        run_build "$platform: проект (резервный способ)" project_command "$compiler" "${CPP_FLAGS[@]}" "${include_flags[@]}" "${PROJECT_SOURCES[@]}" -o "$binary" "${WIN_FLAGS_METHOD2[@]}" || exit 1
                    fi
                else
                    run_build "$platform: проект" project_command "$compiler" "${CPP_FLAGS[@]}" "${include_flags[@]}" "${PROJECT_SOURCES[@]}" -o "$binary" || exit 1
                fi
            else
                run_build "Настройка CMake" project_command cmake -S . -B "$build_dir" -G Ninja -DCMAKE_BUILD_TYPE=Release || exit 1
                run_build "Сборка CMake" project_command cmake --build "$build_dir" --config Release || exit 1
            fi
        done
    elif [[ "$PROJECT_BUILDER" == "make" ]]; then
        run_build "Сборка Make" project_command make || exit 1
    fi
    if [[ "$PROJECT_BUILDER" == "cargo" ]]; then
        run_build "Сборка Cargo" project_command cargo build || exit 1
    fi
    for src in "${sources[@]}"; do
        run_build "$src" "$PYTHON_BIN" -m py_compile "$src" || exit 1
    done
    if [[ "$ACTION" == "test" ]]; then
        case "$PROJECT_BUILDER" in
            cmake) run_build "Тесты CMake" project_command ctest --test-dir ".ghostnet-build/$project_platform" --output-on-failure ;;
            make) run_build "Тесты Make" project_command make test ;;
            cargo) run_build "Тесты Cargo" project_command cargo test ;;
            python|none)
                [[ -d "$TARGET_DIR/tests" ]] || project_error "Папка tests для Python не найдена."
                run_build "Тесты Python" project_command "$PYTHON_BIN" -m unittest discover -s tests -v ;;
            *) project_error "Определите тесты проекта через CMake, Make, Cargo или Python." ;;
        esac
        exit $?
    fi
    [[ "$ACTION" == test ]] || record_recent
    if [[ "$RUN_AFTER" == "1" ]]; then
        entry="${RUN_FILE:-$PROJECT_RUN}"
        if [[ -z "$entry" && "$PROJECT_BUILDER" == "cargo" ]]; then
            project_command cargo run -- "${PROJECT_ARGS[@]}"
            exit $?
        fi
        if [[ -z "$entry" && "$PROJECT_BUILDER" == "cpp" ]]; then entry="$project_binary"; fi
        [[ -n "$entry" ]] || select_project_entry
        [[ -n "$entry" ]] || project_error "Укажите run= в ghostnet.conf или --run-file ПУТЬ для этого проекта."
        entry="${entry//\{target\}/$project_platform}"
        extension=""; [[ "$project_platform" != "windows" ]] || extension=".exe"
        entry="${entry//\{exe\}/$extension}"
        relative_project_path "$entry" || project_error "Неверный путь запуска: $entry"
        [[ -f "$TARGET_DIR/$entry" ]] || project_error "Файл запуска не найден: $entry"
        remember_entry "$entry"
        printf '[RUN] Запуск -> %s\n' "$entry"
        case "$entry" in
            *.py) project_command "$PYTHON_BIN" "$entry" "${PROJECT_ARGS[@]}" ;;
            *.exe)
                if [[ "$HOST_KIND" == "windows" || "$project_platform" != "windows" ]]; then
                    project_command "./$entry" "${PROJECT_ARGS[@]}"
                elif command -v wine >/dev/null 2>&1; then
                    project_command wine "$entry" "${PROJECT_ARGS[@]}"
                else
                    project_error "Для запуска исполняемых файлов Windows нужен Wine."
                fi ;;
            *) project_command "./$entry" "${PROJECT_ARGS[@]}" ;;
        esac
        run_status=$?
        [[ "$run_status" -eq 0 ]] || { printf '[ERROR] Программа завершилась с кодом %d.\n' "$run_status" >&2; exit "$run_status"; }
    fi
    printf '[OK] Готово.\n'
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
            echo -e "${RED}[ERROR]${RESET} Не удалось собрать ${HOST_LABEL} бинарник для $src"
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
                echo -e "${RED}[ERROR]${RESET} Не удалось собрать Windows бинарник для $src (method 1)."
                fail=1
            fi
        elif [[ "$WIN_METHOD" == "2" ]]; then
            echo -e "${GREEN}[BUILD]${RESET} Windows (method 2): $src -> ${base}.exe"
            if ! run_build "Windows (method 2): $src" "$WIN_CXX" "${CPP_FLAGS[@]}" "$src" -o "${base}.exe" "${WIN_FLAGS_METHOD2[@]}"; then
                echo -e "${RED}[ERROR]${RESET} Не удалось собрать Windows бинарник для $src (method 2)."
                fail=1
            fi
        else
            echo -e "${GREEN}[BUILD]${RESET} Windows (method 1): $src -> ${base}.exe"
            if ! run_build "Windows (method 1): $src" "$WIN_CXX" "${CPP_FLAGS[@]}" "$src" -o "${base}.exe" "${WIN_FLAGS_METHOD1[@]}"; then
                echo -e "${YELLOW}[WARN]${RESET} Method 1 не прошел. Пробую method 2 (full static fallback)..."
                if ! run_build "Windows (method 2): $src" "$WIN_CXX" "${CPP_FLAGS[@]}" "$src" -o "${base}.exe" "${WIN_FLAGS_METHOD2[@]}"; then
                    echo -e "${RED}[ERROR]${RESET} Не удалось собрать Windows бинарник для $src (оба метода)."
                    fail=1
                else
                    echo -e "${GREEN}[OK]${RESET} Windows build собран методом 2."
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
            printf '[ERROR] Указанный файл не входит в результаты сборки: %s\n' "$RUN_FILE" >&2
            exit 1
        fi
    elif [[ ${#built_files[@]} -eq 1 ]]; then
        run_index=0
    elif [[ ${#built_files[@]} -gt 1 && -t 0 && -t 1 ]]; then
        choose_menu "Какую программу запустить?" 0 "${built_files[@]}"
        run_index="$MENU_SELECTED"
    else
        printf '[ERROR] Укажите BAN_RUN_FILE для запуска одной из нескольких программ.\n' >&2
        exit 1
    fi

    run_target="${built_files[$run_index]}"
    [[ "$run_target" == */* ]] || run_target="./$run_target"
    printf '%b[RUN]%b Запуск -> %s\n' "$GREEN" "$RESET" "$run_target"
    case "${built_kinds[$run_index]}" in
        script) "$PYTHON_BIN" "$run_target" ;;
        windows)
            if [[ "$HOST_KIND" == "windows" ]]; then
                "$run_target"
            elif ! command -v wine >/dev/null 2>&1; then
                printf '[ERROR] Для запуска .exe на Linux необходим Wine.\n' >&2
                exit 1
            else
                wine "$run_target"
            fi
            ;;
        native) "$run_target" ;;
    esac
    run_status=$?
    if [[ "$run_status" -ne 0 ]]; then
        printf '[ERROR] Программа завершилась с кодом %d.\n' "$run_status" >&2
        exit "$run_status"
    fi
fi

echo -e "${GREEN}[OK]${RESET} Готово."
