# GHOSTNET

**A terminal build launcher for C++, Rust and Python projects.**

A Watch Dogs 2 inspired terminal: green signals, animated progress and an arrow-key menu. Detect a project, check its tools, build, run and test through its existing build system.

[English](README.md) · [Русский](README.ru.md) · [Download releases](https://github.com/galvatrone/CPP-Builder-Gostnet-/releases/latest)

![GHOSTNET main menu](https://raw.githubusercontent.com/galvatrone/CPP-Builder-Gostnet-/main/assets/ghostnet-menu.png)

## Quick installation

**Linux / macOS — paste into Terminal:**

```bash
bash -c 'f=$(mktemp) || exit; trap '\''rm -f "$f"'\'' EXIT; curl -fsSL https://github.com/galvatrone/CPP-Builder-Gostnet-/releases/latest/download/GHOSTNET-Install.sh -o "$f" && bash "$f"'
```

The installer detects the OS and installs missing Bash 4.4+, C++ compiler, Python, Rust/Cargo, CMake, Ninja and Make. Linux supports apt, dnf and pacman (sudo may be required). macOS uses Homebrew and installs it when missing; follow Apple's command line tools dialog if prompted, then rerun. Project-specific libraries and Python packages remain managed by your project.

**Windows 10/11 x64 — paste into PowerShell:**

```powershell
$f = Join-Path $env:TEMP ('GHOSTNET-Install-' + [guid]::NewGuid() + '.cmd'); try { Invoke-WebRequest -UseBasicParsing -ErrorAction Stop 'https://github.com/galvatrone/CPP-Builder-Gostnet-/releases/latest/download/GHOSTNET-Install.cmd' -OutFile $f; & $f; if ($LASTEXITCODE -ne 0) { throw 'Installation failed' } } finally { Remove-Item -LiteralPath $f -ErrorAction SilentlyContinue }
```

This downloads the standalone Windows installer, which prepares MSYS2/UCRT64 and its build tools. Git is not required. Bash and PowerShell use different command syntax, so choose the command for your terminal.

Both installers ask before installing, download a pinned stable platform ZIP and verify its SHA-256. After installation, open a new terminal and use `ghostnet` or `ghostnet-ru`. Add `--yes --no-launch` to the installer invocation for unattended setup. Linux/macOS support `--prefix /absolute/path` and `--version vX.Y.Z`; Windows supports `--dir PATH` and `--version vX.Y.Z`.

**Already downloaded a ZIP?** Each archive includes its installer alongside both languages:

| Archive | Install from the extracted folder |
| --- | --- |
| Linux | `bash GHOSTNET-Install.sh` |
| macOS | Open `GHOSTNET-Install.command`, or `bash GHOSTNET-Install.sh` |
| Windows | Open `GHOSTNET-Install.cmd` |
| All platforms | All three installers |

Linux/macOS install the local extracted scripts after checking dependencies. Windows uses the verified pinned release download. Archives exclude screenshots, tests, examples and development helpers.


## Download

Download the archive for your host and extract it. Every archive includes the independent English `ban.sh` and Russian `ban-ru.sh` scripts; neither needs the other.

| Host | Latest release |
| --- | --- |
| Linux | [ghostnet-linux.zip](https://github.com/galvatrone/CPP-Builder-Gostnet-/releases/latest/download/ghostnet-linux.zip) |
| Windows with MSYS2 | [ghostnet-windows.zip](https://github.com/galvatrone/CPP-Builder-Gostnet-/releases/latest/download/ghostnet-windows.zip) |
| macOS | [ghostnet-macos.zip](https://github.com/galvatrone/CPP-Builder-Gostnet-/releases/latest/download/ghostnet-macos.zip) |
| All platforms | [ghostnet-all-platforms.zip](https://github.com/galvatrone/CPP-Builder-Gostnet-/releases/latest/download/ghostnet-all-platforms.zip) |

Individual scripts: [ban.sh](https://github.com/galvatrone/CPP-Builder-Gostnet-/releases/latest/download/ban.sh) · [ban-ru.sh](https://github.com/galvatrone/CPP-Builder-Gostnet-/releases/latest/download/ban-ru.sh).

The shell scripts are distributed through GitHub Releases. No npm or Python package installation is needed.

### macOS Bash prerequisite

macOS includes an older Bash. GHOSTNET requires **Bash 4.4 or newer**. Install Homebrew Bash first:

```bash
brew install bash
```

Use `ban.command` or `ban-ru.command`; these launchers select the newer Bash automatically. For a direct terminal launch, use `"$(brew --prefix bash)/bin/bash" ban.sh`.

## Start

**Linux:** open a terminal in the extracted folder and run:

```bash
bash ban.sh
```

**macOS:** open `ban.command`, or run `"$(brew --prefix bash)/bin/bash" ban.sh` in Terminal. Native builds produce macOS executables. Dependency installation uses an existing Homebrew installation. If Apple's command line tools are missing, install them with `xcode-select --install`.

**Windows:** download [GHOSTNET-Install.cmd](https://github.com/galvatrone/CPP-Builder-Gostnet-/releases/latest/download/GHOSTNET-Install.cmd) and double-click it. Confirm installation: it downloads a pinned stable release, verifies SHA-256, prepares MSYS2 tools when missing and creates `ghostnet` / `ghostnet-ru` in your user PATH. Open a new PowerShell or CMD window afterward. Git is not required.

For manual ZIP setup, install [MSYS2](https://www.msys2.org/) and open `ban.cmd`. The launcher uses the MSYS2 **UCRT64** environment, looking in `C:\msys64` by default. For another installation path, set `MSYS2_ROOT` to that folder. You can also run `bash ban.sh` from the MSYS2 UCRT64 terminal. PowerShell and Command Prompt alone do not provide the required Bash/compiler environment.

For the Russian interface, use `ban-ru.sh`, `ban-ru.command` or `ban-ru.cmd`. There is no language-selection menu.

Use **↑ / ↓** to move and **Enter** to select. The main menu offers dependency checking, installation, building, and an automatic check-and-build flow. Choose a project folder and the platform, then decide whether to launch a result. Animations turn off automatically outside an interactive terminal; `--no-animation` disables them explicitly.

Repository launchers and installers live in `tools/`; in release ZIPs they sit next to `ban.sh`. Documentation images stay in `assets/` and are excluded from ZIPs.

## Install the `ghostnet` command

From a cloned repository (in an extracted ZIP, use `bash install.sh` instead):

```bash
bash tools/install.sh
export PATH="$HOME/.local/bin:$PATH"
ghostnet
```

Add the PATH line to your shell configuration to keep it across sessions. This installs copies of both standalone scripts under `~/.local/share/ghostnet`, and `ghostnet` / `ghostnet-ru` under `~/.local/bin`; the original download folder is no longer required. A custom location is supported: `bash tools/install.sh --prefix /your/path`. On Windows run installation and commands inside MSYS2 UCRT64. On macOS install Homebrew Bash first; the command selects it automatically.

You can also run `./tools/ghostnet` directly from the repository. `bash ban.sh` and `bash ban-ru.sh` remain supported and independent.

## Project detection and commands

```bash
ghostnet build ./project
ghostnet run ./project
ghostnet test ./project
ghostnet check ./project
```

Auto detection uses this order:

| Project descriptor | Build / Run / Test |
| --- | --- |
| `ghostnet.conf` | Explicit builder and entry point |
| `CMakeLists.txt` | CMake + Ninja / explicit entry / CTest |
| `Cargo.toml` | Cargo build / run / test |
| `pyproject.toml` | Python syntax checks / explicit entry / unittest in `tests/` |
| `GNUmakefile`, `Makefile`, `makefile` | Make default target / explicit entry / `make test` |
| No descriptor | Independent source files; interactive users can choose one C++ project |

For one related C++ program without a build file:

```bash
ghostnet run --mode project ./project
```

All immediate `.cpp`, `.cc`, `.cxx` files are linked together. Headers are included by the sources, not compiled separately. Outputs go to `.ghostnet-build/<platform>/program`. Multiple `main()` functions mean these are separate programs: use `--mode files` instead.

CMake, Make, Cargo and Python project modes currently support **native builds only**. Standalone files and the direct C++ project builder retain Windows cross-build support. `--mode cmake|make|cargo|python` forces a builder; `--mode files` overrides project detection.

CMake and Make may produce multiple executables, so GHOSTNET requires the intended one:

```bash
ghostnet run --run-file '.ghostnet-build/{target}/app{exe}' ./cmake-project
```

`{target}` becomes `linux`, `macos` or `windows`; `{exe}` becomes `.exe` on Windows and is empty elsewhere. Cargo honors its own default binary / `default-run` configuration. Python requires `--run-file app.py`, `run=` in the configuration, or a root `__main__.py`. Existing `.venv/bin/python` or `.venv/Scripts/python.exe` is used automatically. Python dependencies and packaging remain managed by the project; `pyproject.toml` detection does not run pip. Python checks cover root scripts and the selected Python entry; tests use standard `unittest`, not an inferred pytest setup.

## C++ / Python project configuration

A project can build related C++ sources and then run a Python entry point from its project directory.

`ghostnet.conf` is a literal text file, one `key=value` per line:

```ini
builder=cpp
source=src/main.cpp
source=src/answer.cpp
include=include
output=worker
run=launcher.py
arg=Hello from GHOSTNET
```

Supported builders: `cpp`, `cmake`, `make`, `cargo`, `python`, `none`. Repeat `source`, `include` and `arg` as needed. Sources are exact relative paths; nested folders are supported by listing files. `output` is an executable basename under the generated build folder. `run` is a relative entry path. `builder=none` skips compilation for a Python/application launcher. Values may contain spaces; do not wrap them in quotes. There is no variable expansion or shell evaluation. Lines starting with `#` are comments. Third-party C++ libraries should be described by CMake/Make instead of this small configuration.

## What it builds

In `--mode files`, GHOSTNET builds each immediate `.cpp`, `.cc`, `.cxx`, `.py` and `.rs` file independently. Subfolders are not scanned in this mode.

| Source | Action | Result |
| --- | --- | --- |
| `.cpp` | Compile with C++17 | Native executable and/or Windows `.exe` |
| `.py` | Validate with `python3 -m py_compile` | Python bytecode cache; launch the original script with `python3` only when requested |
| `.rs` | Compile with `rustc --edition=2021` | Native executable and/or Windows `.exe` |

Native executables are written beside their sources, usually using the source filename without its extension. Windows results use `.exe`. Sources with a shared filename stem receive distinct output names, and output planning avoids overwriting source files. The build output shows the actual filenames.

Project mode delegates source trees and dependencies to CMake, Make or Cargo. A small C++ project can also link related sources directly. Python validation checks syntax; it does not bundle an executable or install imported modules.

## Host and target support

`--target native` selects the current host's native platform.

| Host | Accepted targets | Meaning of `both` |
| --- | --- | --- |
| Linux | `native`, `linux`, `windows`, `both` | Linux + Windows |
| macOS | `native`, `macos`, `windows`, `both` | macOS + Windows |
| Windows / MSYS2 UCRT64 | `native`, `windows` | Unavailable |

Windows cross-compilation on Linux/macOS uses MinGW-w64. macOS does not provide Linux cross-compilation, and Windows does not provide Linux or macOS builds. A native Windows `.exe` runs directly; launching a cross-built `.exe` on Linux/macOS requires Wine, installed separately.

Rust Windows cross-builds also need the target standard library. With a rustup-managed toolchain, install it explicitly:

```bash
rustup target add x86_64-pc-windows-gnu
```

GHOSTNET does not install Rust target standard libraries automatically. A distribution's `rustc` package may not include this cross-target support.

## Command-line use

```bash
# Check only the tools needed by this folder and target
bash ban.sh --check --target native ./project

# Check the environment and build for this host
bash ban.sh --auto --target native ./project

# Build and run (a single result is selected automatically)
bash ban.sh --auto --target native --run ./project

# Linux/macOS: build native and Windows results
bash ban.sh --auto --target both ./project

# Install missing tools with explicit approval
bash ban.sh --install-deps --target native --yes ./project
```

| Option | Purpose |
| --- | --- |
| `--check` | Check required tools without building |
| `--install-deps` | Install missing tools |
| `--auto` | Check tools, offer installation if needed, then build |
| `--target TARGET` | Select a supported target from the host table |
| `--run` | Launch one successful result after building |
| `--yes` | Approve dependency installation without an additional prompt |
| `--no-animation` | Disable terminal animations |
| `--help` | Show usage |

Quote paths containing spaces. Use `--` before a project path beginning with `-`. Without `--yes`, package installation requires terminal confirmation. Unattended runs should provide an explicit action, target and project folder.

Advanced environment settings:

| Variable | Purpose |
| --- | --- |
| `BAN_SOURCE_FILE` | Process one `.cpp`, `.py` or `.rs` file instead of scanning a folder |
| `BAN_TARGET_DIR` | Default project folder |
| `BAN_RUN_FILE` | Select a particular result for `--run` |
| `BAN_WIN_METHOD` | Windows C++ strategy: `auto`, `1` or `2` |
| `BAN_NO_ANIMATION=1` | Disable animations |

```bash
BAN_SOURCE_FILE=./project/main.py bash ban.sh --auto --target native --run ./project
BAN_RUN_FILE=hello bash ban.sh --auto --target native --run ./project
```

With several results, interactive runs offer a selection menu. Noninteractive runs require `BAN_RUN_FILE`. Python source paths are valid run selections after successful validation. A failed build or launched program returns a nonzero exit status.

## Tools and installation

Checks and installation follow the detected sources and chosen target: C++ needs its compiler, Python needs `python3`, and Rust needs `rustc`. Windows cross-builds also need the MinGW linker. A check or installation without a project inspects the complete supported toolset.

| Host | Package manager |
| --- | --- |
| Debian / Ubuntu | `apt-get` |
| Fedora | `dnf` |
| Arch Linux | `pacman` |
| macOS | Homebrew (`brew`) |
| Windows / MSYS2 UCRT64 | MSYS2 `pacman` with UCRT64 packages |

The installer proposes the missing packages before installation. Linux system package installation may require `sudo`. Install Homebrew or MSYS2 yourself before using their dependency flows.

## Terminal preview

The previews capture actual GHOSTNET terminal output.

![GHOSTNET building programs](https://raw.githubusercontent.com/galvatrone/CPP-Builder-Gostnet-/main/assets/ghostnet-build.png)

![GHOSTNET completed build](https://raw.githubusercontent.com/galvatrone/CPP-Builder-Gostnet-/main/assets/ghostnet-complete.png)

## Development

The scripts remain standalone Bash entry points. [GitHub Actions](https://github.com/galvatrone/CPP-Builder-Gostnet-/actions/workflows/platforms.yml) runs standalone and multi-source C++ builds, CMake/Make/Cargo project builds and tests, Python project validation and execution, and launcher checks on Linux, macOS and Windows/MSYS2. The Linux job also checks Windows cross-compilation and output-name collisions.

## Windows updates

```powershell
ghostnet update
```

The updater selects the latest published stable release and uses its versioned ZIP and SHA256SUMS. Staging happens before activation; a failed download or checksum does not replace the active version. Previous payload folders remain under `%LOCALAPPDATA%\GHOSTNET\versions`.

Installer options: `--yes`, `--no-launch`, `--version vX.Y.Z`, `--dir PATH`, `--msys2-root PATH`. Default GHOSTNET folder: `%LOCALAPPDATA%\GHOSTNET`; default MSYS2: `C:\msys64`. Fresh MSYS2 installation uses a pinned official x64 installer and verifies its SHA-256. Windows x64 10/11, built-in curl and Windows PowerShell are required. MSYS2 setup may require elevation. User PATH is updated without setx; reopen existing terminals to pick up the change.
