@echo off
setlocal DisableDelayedExpansion
rem Launch with the native MSYS2 UCRT64 toolchain.
if not defined MSYS2_ROOT set "MSYS2_ROOT=C:\msys64"
if not exist "%MSYS2_ROOT%\usr\bin\bash.exe" (
    echo MSYS2 was not found.
    echo Install MSYS2 from https://www.msys2.org/ or set MSYS2_ROOT to its installation folder.
    echo.
    echo Press any key to close...
    pause >nul
    exit /b 1
)
set "MSYS2_PATH_TYPE=inherit"
set "MSYSTEM=UCRT64"
set "CHERE_INVOKING=1"
set "GHOSTNET_SCRIPT=%~dp0ban.sh"
if not exist "%GHOSTNET_SCRIPT%" set "GHOSTNET_SCRIPT=%~dp0..\ban.sh"
set "GHOSTNET_SCRIPT=%GHOSTNET_SCRIPT:\=/%"
"%MSYS2_ROOT%\usr\bin\bash.exe" --login "%GHOSTNET_SCRIPT%" %*
set "GHOSTNET_EXIT=%ERRORLEVEL%"
if not "%GHOSTNET_EXIT%"=="0" (
    echo.
    echo Press any key to close...
    pause >nul
)
exit /b %GHOSTNET_EXIT%
