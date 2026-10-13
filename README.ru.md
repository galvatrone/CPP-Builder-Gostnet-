# GHOSTNET

**Терминальный запускатель сборки для 17 языков и систем сборки проектов.**

Терминал в духе Watch Dogs 2: зелёные сигналы, анимация процесса и меню со стрелками. Выберите проект, проверьте инструменты, соберите программу и при необходимости запустите результат.

[English](README.md) · [Русский](README.ru.md) · [Скачать релиз](https://github.com/galvatrone/CPP-Builder-Gostnet-/releases/latest)

![Главное меню GHOSTNET](https://raw.githubusercontent.com/galvatrone/CPP-Builder-Gostnet-/main/assets/ghostnet-menu.png)

## Быстрая установка

**Linux / macOS — вставьте в терминал:**

```bash
bash -c 'f=$(mktemp -d) || exit; trap '\''rm -rf "$f"'\'' EXIT; curl -fsSL https://github.com/galvatrone/CPP-Builder-Gostnet-/releases/latest/download/GHOSTNET-Install.sh -o "$f/GHOSTNET-Install.sh" && bash "$f/GHOSTNET-Install.sh"'
```

Установщик определяет ОС и устанавливает недостающие Bash 4.4+, компилятор C++, Python, Rust/Cargo, CMake, Ninja и Make. В Linux поддерживаются apt, dnf и pacman; может понадобиться sudo. В macOS используется Homebrew: если его нет, установщик предложит установку. Если появится окно инструментов Apple, завершите их установку и повторите команду. Библиотеки проекта и пакеты Python устанавливаются средствами самого проекта.

**Windows 10/11 x64 — вставьте в PowerShell:**

```powershell
$f = Join-Path $env:TEMP ('GHOSTNET-Install-' + [guid]::NewGuid() + '.cmd'); try { Invoke-WebRequest -UseBasicParsing -ErrorAction Stop 'https://github.com/galvatrone/CPP-Builder-Gostnet-/releases/latest/download/GHOSTNET-Install.cmd' -OutFile $f; & $f; if ($LASTEXITCODE -ne 0) { throw 'Installation failed' } } finally { Remove-Item -LiteralPath $f -ErrorAction SilentlyContinue }
```

Команда скачивает самостоятельный установщик Windows, который подготавливает MSYS2/UCRT64 и инструменты сборки. Git не нужен. У Bash и PowerShell различается синтаксис, поэтому выберите команду для своего терминала.

Оба установщика запрашивают подтверждение, скачивают ZIP конкретной стабильной версии для вашей ОС и проверяют SHA-256. После установки откройте новый терминал и запустите `ghostnet` или `ghostnet-ru`. Для автоматической установки добавьте к вызову установщика `--yes --no-launch`. Linux/macOS поддерживают `--prefix /полный/путь` и `--version vX.Y.Z`; Windows — `--dir PATH` и `--version vX.Y.Z`.

**ZIP уже скачан?** В каждом архиве рядом с обеими языковыми версиями лежит нужный установщик:

| Архив | Установка из распакованной папки |
| --- | --- |
| Linux | `bash GHOSTNET-Install.sh` |
| macOS | Откройте `GHOSTNET-Install.command` или выполните `bash GHOSTNET-Install.sh` |
| Windows | Откройте `GHOSTNET-Install.cmd` |
| Все платформы | Все три установщика |

Linux/macOS устанавливают локальные распакованные скрипты после проверки зависимостей. Windows скачивает проверяемый релиз указанной версии. В ZIP нет изображений, тестов, примеров и вспомогательных файлов разработки.


## Скачать

Скачайте и распакуйте архив для своей системы. Каждый архив содержит независимые скрипты: английский `ban.sh` и русский `ban-ru.sh`. Для работы одного второй не требуется.

| Система | Последний релиз |
| --- | --- |
| Linux | [ghostnet-linux.zip](https://github.com/galvatrone/CPP-Builder-Gostnet-/releases/latest/download/ghostnet-linux.zip) |
| Windows с MSYS2 | [ghostnet-windows.zip](https://github.com/galvatrone/CPP-Builder-Gostnet-/releases/latest/download/ghostnet-windows.zip) |
| macOS | [ghostnet-macos.zip](https://github.com/galvatrone/CPP-Builder-Gostnet-/releases/latest/download/ghostnet-macos.zip) |
| Все платформы | [ghostnet-all-platforms.zip](https://github.com/galvatrone/CPP-Builder-Gostnet-/releases/latest/download/ghostnet-all-platforms.zip) |

Отдельные скрипты: [ban.sh](https://github.com/galvatrone/CPP-Builder-Gostnet-/releases/latest/download/ban.sh) · [ban-ru.sh](https://github.com/galvatrone/CPP-Builder-Gostnet-/releases/latest/download/ban-ru.sh).

Скрипты распространяются через GitHub Releases. Установка пакета npm или Python не требуется.

### Bash на macOS

В macOS встроен старый Bash. GHOSTNET требует **Bash 4.4 или новее**. Сначала установите Bash через Homebrew:

```bash
brew install bash
```

Используйте `ban.command` или `ban-ru.command`: они автоматически выбирают новый Bash. Для запуска из терминала: `"$(brew --prefix bash)/bin/bash" ban-ru.sh`.

## Запуск

**Linux:** откройте терминал в распакованной папке и выполните:

```bash
bash ban-ru.sh
```

**macOS:** откройте `ban-ru.command` или выполните `"$(brew --prefix bash)/bin/bash" ban-ru.sh` в Terminal. Нативная сборка создаёт исполняемые файлы macOS. Для установки инструментов используется уже установленный Homebrew. Если отсутствуют инструменты командной строки Apple, установите их командой `xcode-select --install`.

**Windows:** скачайте [GHOSTNET-Install.cmd](https://github.com/galvatrone/CPP-Builder-Gostnet-/releases/latest/download/GHOSTNET-Install.cmd) и запустите двойным кликом. Подтвердите установку: загрузится закреплённый стабильный релиз, проверится SHA-256, при необходимости установятся MSYS2 и инструменты, а команды `ghostnet` / `ghostnet-ru` добавятся в пользовательский PATH. Затем откройте новое окно PowerShell или CMD. Git не требуется.

Для ручной установки из ZIP установите [MSYS2](https://www.msys2.org/) и откройте `ban-ru.cmd`. Лаунчер использует среду MSYS2 **UCRT64** и по умолчанию ищет её в `C:\msys64`. Для другого расположения задайте `MSYS2_ROOT`, указав папку установки. Можно также выполнить `bash ban-ru.sh` в терминале MSYS2 UCRT64. Одних PowerShell или командной строки недостаточно: нужна среда Bash и компиляторов MSYS2.

Для английского интерфейса используйте `ban.sh`, `ban.command` или `ban.cmd`. Меню переключения языка отсутствует.

Перемещайтесь клавишами **↑ / ↓**, выбирайте пункт клавишей **Enter**. Главное меню предлагает проверку инструментов, их установку, сборку и автоматический режим проверки со сборкой. Выберите папку проекта и платформу, затем решите, запускать ли результат. Вне интерактивного терминала анимация отключается автоматически; параметр `--no-animation` отключает её явно.

В репозитории запускатели и установщики находятся в `tools/`; в ZIP они лежат рядом с `ban.sh`. Картинки для README остаются в `assets/` и не включаются в ZIP.

## Установка команды `ghostnet`

Из клонированного репозитория (в распакованном ZIP используйте `bash install.sh`):

```bash
bash tools/install.sh
export PATH="$HOME/.local/bin:$PATH"
ghostnet-ru
```

Добавьте строку PATH в настройки оболочки для следующих сеансов. Установка копирует оба самостоятельных скрипта в `~/.local/share/ghostnet`, а команды `ghostnet` / `ghostnet-ru` — в `~/.local/bin`. Исходную папку после этого можно удалить. Другой путь: `bash tools/install.sh --prefix /ваш/путь`. На Windows устанавливайте и запускайте команды внутри MSYS2 UCRT64. На macOS сначала установите Bash через Homebrew; команда автоматически выбирает его.

Можно запускать `./tools/ghostnet-ru` прямо из репозитория. Самостоятельные `bash ban.sh` и `bash ban-ru.sh` продолжают работать.

## Новые возможности и прежний стиль терминала

Сохранены прежние заставка, зелёные анимации, индикатор сборки и управление стрелками. Перед сборкой добавлен паспорт проекта с голубыми и фиолетовыми акцентами. Старые пять пунктов меню остаются на своих местах; после них идут просмотр проекта, языки, создание и недавние проекты. При перенаправлении вывода нет ANSI-цветов и анимаций. Подсказки `[HINT]` дополняют исходные ошибки компилятора.

```bash
ghostnet-ru inspect ./project                 # паспорт без сборки
ghostnet-ru languages                         # список языков и инструментов
ghostnet-ru init --type cmake ./my-project     # существующие файлы не заменяются
ghostnet-ru init --type go ./go-app
ghostnet-ru recent                            # пять последних успешных проектов
ghostnet-ru run ./my-project
ghostnet-ru test ./my-project
```

`ghostnet-ru init` открывает меню шаблонов в терминале. Типы: `cpp`, `cmake`, `c`, `rust`, `python`, `go`, `java`, `javascript`, `typescript`, `csharp`, `bash`, `ruby`, `php`, `lua`, `swift`, `kotlin`, `dart`, `zig`. Создание только записывает файлы, без установки зависимостей. История путей хранится локально в `${XDG_STATE_HOME:-$HOME/.local/state}/ghostnet`.

Пример обновлённого меню и паспорта проекта — реальный вывод `ban-ru.sh`:

![ Обновлённое меню GHOSTNET и паспорт проекта ](https://raw.githubusercontent.com/galvatrone/CPP-Builder-Gostnet-/main/assets/ghostnet-expanded-ru.png)

```text
GHOSTNET — главное меню (↑/↓ + Enter):
    Проверить окружение
    Установить инструменты
    Собрать программу
    Полная автосборка
    Выход
  > Паспорт проекта
    Поддерживаемые языки
    Создать проект
    Недавние проекты


[SCAN COMPLETE]
  ПРОЕКТ › .
  ЯЗЫКИ › C / C++
  СБОРЩИК › cmake
  ПЛАТФОРМА › linux
  ЗАПУСК › выбор после сборки
```

## Языки и SDK

| Язык | Режим files | Проекты |
| --- | --- | --- |
| C / C++ | gcc C17 / g++ C++17 → программа | Прямая линковка, CMake, Make |
| Rust | rustc → программа | Cargo |
| Python | Проверка синтаксиса, запуск python3 | pyproject.toml / unittest |
| Go | go build → программа | go.mod / build, run, test |
| Java | javac, запуск исходника java (JDK 11+) | Maven / Gradle |
| JavaScript | node --check, запуск node | package.json / npm scripts |
| TypeScript | tsc → JS, запуск node | package.json / npm scripts |
| C# | Временный SDK-проект → DLL, запуск dotnet | .csproj в корне / dotnet |
| Bash | bash -n, запуск bash | Отдельные файлы |
| Ruby | ruby -c, запуск ruby | Отдельные файлы |
| PHP | php -l, запуск php | Отдельные файлы |
| Lua | luac -p, запуск lua | Отдельные файлы |
| Swift | swiftc → программа | SwiftPM |
| Kotlin | kotlinc → JAR, запуск java | Gradle |
| Dart | dart compile exe | Отдельные файлы |
| Zig | zig build-exe | Zig build system |

Проверяются инструменты выбранного проекта. Установщик сохраняет базовый набор C/C++/Rust/Python и не загружает 17 SDK. `--install-deps` предлагает доступные системные пакеты; если подходящего пакета нет, показывает ссылку для ручной установки SDK. Нужен полный SDK с компилятором; после установки откройте терминал заново. Запускатели Windows наследуют Windows PATH, поэтому установленные Go, Node, JDK и .NET доступны в MSYS2. Для Homebrew `openjdk` на macOS может потребоваться добавить его `bin` в PATH.

Для шаблона TypeScript один раз установите зависимости проекта:

```bash
ghostnet-ru init --type typescript ./web-tool
cd web-tool
npm install
ghostnet-ru run .
```

GHOSTNET не запускает автоматически `npm install`, pip или pub и не меняет зависимости Maven/Gradle. Системы сборки выполняют обычное разрешение зависимостей. В Maven/Gradle укажите исполняемый JAR через `--run-file target/app.jar` или `--run-file build/libs/app.jar`; точка входа библиотеки не угадывается. В Go `--run-file` задаёт относительную папку пакета, в .NET — `.csproj`, в Swift — имя продукта. Аргументы проекта задаются повторными строками `arg=` в `ghostnet.conf`. В режиме files при нескольких результатах выбирайте фактический выходной файл, указанный в выводе сборки. Доступность Swift, Kotlin, Dart, Zig и .NET зависит от поддерживаемых SDK ОС и архитектур.

## Определение проекта и команды

```bash
ghostnet-ru build ./project
ghostnet-ru run ./project
ghostnet-ru test ./project
ghostnet-ru check ./project
```

Порядок автоматического определения:

| Описание проекта | Сборка / запуск / тесты |
| --- | --- |
| `ghostnet.conf` | Явные система сборки и точка запуска |
| `CMakeLists.txt` | CMake + Ninja / явная точка запуска / CTest |
| `Cargo.toml` | Cargo build / run / test |
| `pyproject.toml` | Проверка Python / явная точка запуска / unittest в `tests/` |
| `GNUmakefile`, `Makefile`, `makefile` | Основная цель Make / явная точка запуска / `make test` |
| `go.mod` | Go build / run / test |
| `package.json` | npm scripts: build / start / test |
| `*.csproj` (в корне) | dotnet build / run / test |
| `pom.xml` | Maven package / указанный JAR / test |
| `build.gradle`, `build.gradle.kts` | Gradle build / указанная точка входа / test |
| `Package.swift` | SwiftPM build / run / test |
| `build.zig` | Zig build / выбранная программа / build test |
| Нет описания | Отдельные исходники; в меню можно выбрать один проект C++ |

Связанные исходники C++ без системы сборки:

```bash
ghostnet-ru run --mode project ./project
```

Все непосредственные `.c`, `.cpp`, `.cc`, `.cxx` связываются в одну программу. C компилируется как C17 и при необходимости линкуется с объектами C++. Заголовки подключаются исходниками, отдельно они не компилируются. Результат: `.ghostnet-build/<платформа>/program`. Если в папке несколько `main()`, это отдельные программы: выберите `--mode files`.

Режимы проектов CMake, Make, Cargo и Python пока поддерживают **только нативную сборку**. Отдельные C/C++ и Rust, а также прямой сборщик C/C++ сохраняют кросс-компиляцию для Windows. Новые языковые адаптеры и системы проектов поддерживают только нативную сборку. `--mode cmake|make|cargo|python|go|node|dotnet|maven|gradle|swift|zig` выбирает систему явно; `--mode files` отключает определение проекта.

Выходы CMake, Make и Zig определяются после сборки. Единственная программа выбирается автоматически, несколько результатов — через меню в терминале. Выбор сохраняется в `.ghostnet-build/run-entry`. Без терминала укажите точку запуска явно:

```bash
ghostnet-ru run --run-file '.ghostnet-build/{target}/app{exe}' ./cmake-project
```

`{target}` заменяется на `linux`, `macos` или `windows`, `{exe}` — на `.exe` для Windows и пустую строку для других систем. Cargo использует собственную основную программу / `default-run`. Для Python укажите `--run-file app.py`, `run=` в настройках или создайте корневой `__main__.py`. Существующий интерпретатор `.venv/bin/python` или `.venv/Scripts/python.exe` выбирается автоматически. Зависимости и упаковкой Python управляет сам проект: определение `pyproject.toml` не запускает pip. Проверяются корневые скрипты и выбранная Python-точка запуска; тесты запускаются через стандартный `unittest`, автоматического определения pytest нет.

## Настройка проекта C++ / Python

Проект может собрать связанные исходники C++, затем запустить точку входа Python из своей папки.

`ghostnet.conf` — обычный текстовый файл, одна запись `ключ=значение` на строку:

```ini
builder=cpp
source=src/main.cpp
source=src/answer.cpp
include=include
output=worker
run=launcher.py
arg=Hello from GHOSTNET
```

Системы сборки: `cpp`, `cmake`, `make`, `cargo`, `python`, `none`, `go`, `node`, `dotnet`, `maven`, `gradle`, `swift`, `zig`. Поля `source`, `include` и `arg` можно повторять. Исходники задаются точными относительными путями, в том числе из вложенных папок. `output` — имя программы внутри папки сборки, `run` — относительный путь точки запуска. `builder=none` пропускает компиляцию для запуска Python/приложения. Пробелы в значениях разрешены; кавычки добавлять не нужно. Подстановок переменных и исполнения команд оболочки нет. Строки с `#` — комментарии. Внешние библиотеки C++ лучше описывать через CMake/Make.

## Что поддерживается

В режиме `--mode files` GHOSTNET обрабатывает непосредственные файлы из таблицы языков ниже отдельно. В этом режиме вложенные папки не сканируются.

| Исходник | Действие | Результат |
| --- | --- | --- |
| `.cpp` | Компиляция по стандарту C++17 | Нативный исполняемый файл и/или Windows `.exe` |
| `.py` | Проверка через `python3 -m py_compile` | Кеш байткода Python; исходный скрипт запускается через `python3` только по запросу |
| `.rs` | Компиляция через `rustc --edition=2021` | Нативный исполняемый файл и/или Windows `.exe` |

Нативные исполняемые файлы создаются рядом с исходниками, обычно под именем исходника без расширения. Для Windows добавляется `.exe`. Если основы имён совпадают, выходные файлы получают разные имена; планирование результатов предотвращает перезапись исходников. Фактические имена видны в выводе сборки.

В режиме проекта GHOSTNET передаёт сборку дерева исходников и управление зависимостями CMake, Make или Cargo. Небольшой проект C++ также можно собрать напрямую из связанных исходников. Проверка Python проверяет синтаксис, но не упаковывает программу в исполняемый файл и не устанавливает импортируемые модули.

## Системы и цели сборки

`--target native` выбирает нативную платформу текущей системы.

| Система запуска | Допустимые цели | Значение `both` |
| --- | --- | --- |
| Linux | `native`, `linux`, `windows`, `both` | Linux + Windows |
| macOS | `native`, `macos`, `windows`, `both` | macOS + Windows |
| Windows / MSYS2 UCRT64 | `native`, `windows` | Недоступно |

Кросс-компиляция для Windows на Linux/macOS использует MinGW-w64. Сборка для Linux на macOS недоступна; Windows не поддерживает сборку для Linux или macOS. Нативный Windows `.exe` запускается напрямую. Для запуска Windows `.exe`, собранного на Linux/macOS, нужен отдельно установленный Wine.

Для кросс-компиляции Rust под Windows также нужна стандартная библиотека целевой платформы. Если инструментами управляет rustup, установите её явно:

```bash
rustup target add x86_64-pc-windows-gnu
```

GHOSTNET не устанавливает стандартные библиотеки целевых платформ Rust автоматически. Пакет `rustc` из репозитория дистрибутива может не содержать необходимую поддержку кросс-компиляции.

## Командная строка

```bash
# Проверить только инструменты для этой папки и цели
bash ban-ru.sh --check --target native ./project

# Проверить окружение и собрать для текущей системы
bash ban-ru.sh --auto --target native ./project

# Собрать и запустить (единственный результат выбирается автоматически)
bash ban-ru.sh --auto --target native --run ./project

# Linux/macOS: собрать для своей системы и Windows
bash ban-ru.sh --auto --target both ./project

# Установить недостающие инструменты с явным разрешением
bash ban-ru.sh --install-deps --target native --yes ./project
```

| Параметр | Назначение |
| --- | --- |
| `--check` | Проверить необходимые инструменты без сборки |
| `--install-deps` | Установить недостающие инструменты |
| `--auto` | Проверить инструменты, предложить установку и собрать |
| `--target TARGET` | Выбрать допустимую цель из таблицы систем |
| `--run` | Запустить один успешный результат после сборки |
| `--yes` | Разрешить установку зависимостей без дополнительного вопроса |
| `--no-animation` | Отключить анимацию терминала |
| `--help` | Показать справку |

Пути с пробелами заключайте в кавычки. Если путь проекта начинается с `-`, укажите перед ним `--`. Без `--yes` установка пакетов требует подтверждения в терминале. Для запуска без участия пользователя задайте действие, цель и папку проекта явно.

Дополнительные переменные окружения:

| Переменная | Назначение |
| --- | --- |
| `BAN_SOURCE_FILE` | Обработать один поддерживаемый исходник вместо сканирования папки |
| `BAN_TARGET_DIR` | Папка проекта по умолчанию |
| `BAN_RUN_FILE` | Выбрать конкретный результат для `--run` |
| `BAN_WIN_METHOD` | Способ сборки C++ для Windows: `auto`, `1` или `2` |
| `BAN_NO_ANIMATION=1` | Отключить анимацию |

```bash
BAN_SOURCE_FILE=./project/main.py bash ban-ru.sh --auto --target native --run ./project
BAN_RUN_FILE=hello bash ban-ru.sh --auto --target native --run ./project
```

Если результатов несколько, интерактивный запуск предлагает меню выбора. При неинтерактивном запуске требуется `BAN_RUN_FILE`. После успешной проверки можно выбрать путь исходника Python. Ошибка сборки или запущенной программы возвращает ненулевой код завершения.

## Инструменты и установка

Проверка и установка учитывают найденные исходники и выбранную цель: для C++ нужен компилятор, для Python — `python3`, для Rust — `rustc`. Кросс-компиляция для Windows также требует компоновщик MinGW. Проверка или установка без проекта охватывает весь поддерживаемый набор инструментов.

| Система | Менеджер пакетов |
| --- | --- |
| Debian / Ubuntu | `apt-get` |
| Fedora | `dnf` |
| Arch Linux | `pacman` |
| macOS | Homebrew (`brew`) |
| Windows / MSYS2 UCRT64 | MSYS2 `pacman` с пакетами UCRT64 |

Перед установкой инструмент показывает недостающие пакеты. Установка системных пакетов Linux может требовать `sudo`. Homebrew или MSYS2 нужно установить самостоятельно до использования соответствующего сценария установки зависимостей.

## Вид терминала

Изображения созданы из настоящего терминального вывода GHOSTNET.

![Сборка программ в GHOSTNET](https://raw.githubusercontent.com/galvatrone/CPP-Builder-Gostnet-/main/assets/ghostnet-build.png)

![Завершённая сборка GHOSTNET](https://raw.githubusercontent.com/galvatrone/CPP-Builder-Gostnet-/main/assets/ghostnet-complete.png)

## Разработка

Скрипты остаются самостоятельными точками входа на Bash. [GitHub Actions](https://github.com/galvatrone/CPP-Builder-Gostnet-/actions/workflows/platforms.yml) проверяет сборку отдельных и связанных исходников C++, проекты CMake/Make/Cargo и их тесты, проверку и запуск Python-проектов, а также лаунчеры на Linux, macOS и Windows/MSYS2. Задача Linux также проверяет кросс-компиляцию для Windows и защиту от совпадений имён выходных файлов.

## Обновление на Windows

```powershell
ghostnet update
```

Обновление выбирает последний опубликованный стабильный релиз и скачивает ZIP и SHA256SUMS по адресу конкретной версии. Подготовка выполняется до переключения: ошибка загрузки или проверки суммы не заменяет активную версию. Предыдущие версии сохраняются в `%LOCALAPPDATA%\GHOSTNET\versions`.

Параметры установщика: `--yes`, `--no-launch`, `--version vX.Y.Z`, `--dir ПУТЬ`, `--msys2-root ПУТЬ`. По умолчанию GHOSTNET устанавливается в `%LOCALAPPDATA%\GHOSTNET`, MSYS2 — в `C:\msys64`. Для новой установки используется закреплённый официальный установщик MSYS2 x64 с проверкой SHA-256. Требуются Windows x64 10/11, встроенные curl и Windows PowerShell. Установка MSYS2 может запросить права администратора. PATH изменяется через API пользовательского окружения без setx; уже открытый терминал нужно перезапустить.
