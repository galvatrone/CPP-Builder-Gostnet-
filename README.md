# GHOSTNET

**A terminal builder for standalone C++, Python and Rust programs.**

A Watch Dogs 2 inspired terminal: green signals, animated progress and an arrow-key menu. Pick a project, check its tools, build, and optionally launch a result.

[English](README.md) · [Русский](README.ru.md) · [Download releases](https://github.com/galvatrone/CPP-Builder-Gostnet-/releases/latest)

![GHOSTNET main menu](assets/ghostnet-menu.png)

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

**Windows:** install [MSYS2](https://www.msys2.org/), then open `ban.cmd`. The launcher uses the MSYS2 **UCRT64** environment, looking in `C:\msys64` by default. For another installation path, set `MSYS2_ROOT` to that folder. You can also run `bash ban.sh` from the MSYS2 UCRT64 terminal. PowerShell and Command Prompt alone do not provide the required Bash/compiler environment.

For the Russian interface, use `ban-ru.sh`, `ban-ru.command` or `ban-ru.cmd`. There is no language-selection menu.

Use **↑ / ↓** to move and **Enter** to select. The main menu offers dependency checking, installation, building, and an automatic check-and-build flow. Choose a project folder and the platform, then decide whether to launch a result. Animations turn off automatically outside an interactive terminal; `--no-animation` disables them explicitly.

## What it builds

GHOSTNET scans the selected folder's immediate `.cpp`, `.py` and `.rs` files. Each file is processed independently; subfolders are not scanned.

| Source | Action | Result |
| --- | --- | --- |
| `.cpp` | Compile with C++17 | Native executable and/or Windows `.exe` |
| `.py` | Validate with `python3 -m py_compile` | Python bytecode cache; launch the original script with `python3` only when requested |
| `.rs` | Compile with `rustc --edition=2021` | Native executable and/or Windows `.exe` |

Native executables are written beside their sources, usually using the source filename without its extension. Windows results use `.exe`. Sources with a shared filename stem receive distinct output names, and output planning avoids overwriting source files. The build output shows the actual filenames.

This is for standalone files. Multi-source linking, Cargo projects, external libraries and Python dependency management require a separate project build system. Python validation checks syntax; it does not bundle an executable or install imported modules.

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

![GHOSTNET building programs](assets/ghostnet-build.png)

![GHOSTNET completed build](assets/ghostnet-complete.png)

## Development

The scripts remain standalone Bash entry points. CI is configured to validate the supported Linux, macOS and Windows/MSYS2 hosts. Host-specific behavior still needs verification on the corresponding operating system; a Linux test run alone does not establish macOS or Windows compatibility.
