# GHOSTNET

**Терминальный запускатель сборки проектов C++, Rust и Python.**

Терминал в духе Watch Dogs 2: зелёные сигналы, анимация процесса и меню со стрелками. Выберите проект, проверьте инструменты, соберите программу и при необходимости запустите результат.

[English](README.md) · [Русский](README.ru.md) · [Скачать релиз](https://github.com/galvatrone/CPP-Builder-Gostnet-/releases/latest)

![Главное меню GHOSTNET](https://raw.githubusercontent.com/galvatrone/CPP-Builder-Gostnet-/main/assets/ghostnet-menu.png)

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

## Установка команды `ghostnet`

Из распакованного архива или клонированного репозитория:

```bash
bash install.sh
export PATH="$HOME/.local/bin:$PATH"
ghostnet-ru
```

Добавьте строку PATH в настройки оболочки для следующих сеансов. Установка копирует оба самостоятельных скрипта в `~/.local/share/ghostnet`, а команды `ghostnet` / `ghostnet-ru` — в `~/.local/bin`. Исходную папку после этого можно удалить. Другой путь: `bash install.sh --prefix /ваш/путь`. На Windows устанавливайте и запускайте команды внутри MSYS2 UCRT64. На macOS сначала установите Bash через Homebrew; команда автоматически выбирает его.

Можно запускать `./ghostnet-ru` прямо из репозитория. Самостоятельные `bash ban.sh` и `bash ban-ru.sh` продолжают работать.

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
| Нет описания | Отдельные исходники; в меню можно выбрать один проект C++ |

Связанные исходники C++ без системы сборки:

```bash
ghostnet-ru run --mode project ./project
```

Все непосредственные `.cpp`, `.cc`, `.cxx` связываются в одну программу. Заголовки подключаются исходниками, отдельно они не компилируются. Результат: `.ghostnet-build/<платформа>/program`. Если в папке несколько `main()`, это отдельные программы: выберите `--mode files`.

Режимы проектов CMake, Make, Cargo и Python пока поддерживают **только нативную сборку**. Отдельные файлы и прямой сборщик проекта C++ сохраняют кросс-компиляцию для Windows. `--mode cmake|make|cargo|python` выбирает систему явно; `--mode files` отключает определение проекта.

CMake и Make могут создать несколько программ, поэтому точка запуска задаётся явно:

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

Системы сборки: `cpp`, `cmake`, `make`, `cargo`, `python`, `none`. Поля `source`, `include` и `arg` можно повторять. Исходники задаются точными относительными путями, в том числе из вложенных папок. `output` — имя программы внутри папки сборки, `run` — относительный путь точки запуска. `builder=none` пропускает компиляцию для запуска Python/приложения. Пробелы в значениях разрешены; кавычки добавлять не нужно. Подстановок переменных и исполнения команд оболочки нет. Строки с `#` — комментарии. Внешние библиотеки C++ лучше описывать через CMake/Make.

## Что поддерживается

В режиме `--mode files` GHOSTNET обрабатывает непосредственные файлы `.cpp`, `.cc`, `.cxx`, `.py` и `.rs` отдельно. В этом режиме вложенные папки не сканируются.

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
| `BAN_SOURCE_FILE` | Обработать один файл `.cpp`, `.py` или `.rs` вместо сканирования папки |
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
