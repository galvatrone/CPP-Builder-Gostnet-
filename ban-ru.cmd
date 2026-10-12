@echo off
setlocal DisableDelayedExpansion
chcp 65001 >nul
if not defined MSYS2_ROOT set "MSYS2_ROOT=C:\msys64"
if not exist "%MSYS2_ROOT%\usr\bin\bash.exe" (
    echo MSYS2 не найден.
    echo Установите MSYS2 с https://www.msys2.org/ или задайте MSYS2_ROOT с папкой установки.
    echo.
    echo Нажмите любую клавишу для выхода...
    pause >nul
    exit /b 1
)
set "MSYSTEM=UCRT64"
set "CHERE_INVOKING=1"
set "GHOSTNET_SCRIPT=%~dp0ban-ru.sh"
if not exist "%GHOSTNET_SCRIPT%" set "GHOSTNET_SCRIPT=%~dp0..\ban-ru.sh"
set "GHOSTNET_SCRIPT=%GHOSTNET_SCRIPT:\=/%"
"%MSYS2_ROOT%\usr\bin\bash.exe" --login "%GHOSTNET_SCRIPT%" %*
set "GHOSTNET_EXIT=%ERRORLEVEL%"
if not "%GHOSTNET_EXIT%"=="0" (
    echo.
    echo Нажмите любую клавишу для выхода...
    pause >nul
)
exit /b %GHOSTNET_EXIT%
