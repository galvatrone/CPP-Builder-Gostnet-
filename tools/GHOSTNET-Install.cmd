@echo off
setlocal DisableDelayedExpansion
set "GHOSTNET_INSTALLER=%~f0"
set "GHOSTNET_YES=0"
set "GHOSTNET_NO_LAUNCH=0"
set "GHOSTNET_UPDATE=0"
set "GHOSTNET_VERSION=v1.3.0"
set "GHOSTNET_APP_DIR=%LOCALAPPDATA%\GHOSTNET"
:parse
if "%~1"=="" goto execute
if /i "%~1"=="--yes" (
    set "GHOSTNET_YES=1"
    shift
    goto parse
)
if /i "%~1"=="--no-launch" (
    set "GHOSTNET_NO_LAUNCH=1"
    shift
    goto parse
)
if /i "%~1"=="--update" (
    set "GHOSTNET_UPDATE=1"
    shift
    goto parse
)
if /i "%~1"=="--version" (
    if "%~2"=="" goto usage
    set "GHOSTNET_VERSION=%~2"
    shift
    shift
    goto parse
)
if /i "%~1"=="--dir" (
    if "%~2"=="" goto usage
    set "GHOSTNET_APP_DIR=%~2"
    shift
    shift
    goto parse
)
if /i "%~1"=="--msys2-root" (
    if "%~2"=="" goto usage
    set "MSYS2_ROOT=%~2"
    shift
    shift
    goto parse
)
:usage
echo Usage: GHOSTNET-Install.cmd [--yes] [--no-launch] [--update] [--version vX.Y.Z] [--dir PATH] [--msys2-root PATH]
exit /b 2
:execute
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$raw=Get-Content -LiteralPath $env:GHOSTNET_INSTALLER -Raw; $body=($raw -split '(?m)^# GHOSTNET POWERSHELL START\r?$',2)[1]; & ([scriptblock]::Create($body))"
set "GHOSTNET_STATUS=%ERRORLEVEL%"
if not "%GHOSTNET_STATUS%"=="0" if "%GHOSTNET_YES%"=="0" pause
exit /b %GHOSTNET_STATUS%
# GHOSTNET POWERSHELL START
$ErrorActionPreference='Stop'
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
$Repository='galvatrone/CPP-Builder-Gostnet-'
function Download-File([string]$Url,[string]$Destination) {
    & curl.exe --fail --location --silent --show-error --retry 3 --proto '=https' --tlsv1.2 --output $Destination $Url
    if ($LASTEXITCODE -ne 0) { throw "Download failed: $Url" }
}
function Get-LatestVersion {
    # GitHub's public release redirect avoids anonymous API rate limits.
    $Url=& curl.exe --fail --location --silent --show-error --retry 3 --proto '=https' --tlsv1.2 --head --output NUL --write-out '%{url_effective}' "https://github.com/$Repository/releases/latest"
    if ($LASTEXITCODE -ne 0) { throw 'Could not resolve the latest release.' }
    $Uri=[uri]($Url -join '')
    $Pattern='^/'+[regex]::Escape($Repository)+'/releases/tag/(v\d+\.\d+\.\d+)/?$'
    if ($Uri.Scheme -ne 'https' -or $Uri.Host -ne 'github.com' -or $Uri.AbsolutePath -notmatch $Pattern) { throw 'Invalid stable release redirect.' }
    return $Matches[1]
}
function Check-Checksum([string]$File,[string]$Checksums,[string]$Name) {
    $MatchesFound=@(Get-Content -LiteralPath $Checksums | Where-Object { $_ -match ('^[0-9a-fA-F]{64}\s+\*?'+[regex]::Escape($Name)+'\s*$') })
    if ($MatchesFound.Count -ne 1) { throw "Missing or ambiguous SHA-256 entry: $Name" }
    $Expected=($MatchesFound[0] -split '\s+')[0]
    $Actual=(Get-FileHash -LiteralPath $File -Algorithm SHA256).Hash
    if ($Actual -ne $Expected) { throw "SHA-256 mismatch: $Name. Existing installation was preserved." }
}
function Install-Payload([string]$Archive,[string]$Checksums,[string]$Version,[string]$Root) {
    if ($Version -notmatch '^v\d+\.\d+\.\d+$') { throw 'Only stable version tags vX.Y.Z are accepted.' }
    Check-Checksum $Archive $Checksums 'ghostnet-windows.zip'
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $Zip=[IO.Compression.ZipFile]::OpenRead($Archive)
    try {
        foreach ($Entry in $Zip.Entries) {
            $Name=$Entry.FullName.Replace('\','/')
            if (!$Name.StartsWith('GHOSTNET/') -or $Name -match '(^|/)\.\.(/|$)|:') { throw "Invalid ZIP entry: $Name" }
        }
    } finally { $Zip.Dispose() }
    $Stage=Join-Path $Root ('staging-'+[guid]::NewGuid())
    $Versions=Join-Path $Root 'versions'
    $Final=Join-Path $Versions ($Version+'-'+[guid]::NewGuid())
    try {
        New-Item -ItemType Directory -Path $Stage -Force | Out-Null
        Expand-Archive -LiteralPath $Archive -DestinationPath $Stage
        $Payload=Join-Path $Stage 'GHOSTNET'
        foreach ($Name in 'ban.sh','ban-ru.sh') {
            if (!(Test-Path -LiteralPath (Join-Path $Payload $Name) -PathType Leaf)) { throw "Release is missing $Name" }
        }
        New-Item -ItemType Directory -Path $Versions -Force | Out-Null
        Move-Item -LiteralPath $Payload -Destination $Final
        return $Final
    } finally { if (Test-Path -LiteralPath $Stage) { Remove-Item -LiteralPath $Stage -Recurse -Force } }
}
function Ensure-Msys2([string]$Requested,[string]$Work) {
    $Root=$Requested
    if (!$Root) { $Root='C:\msys64' }
    $Bash=Join-Path $Root 'usr\bin\bash.exe'
    if (!(Test-Path -LiteralPath $Bash)) {
        if (Test-Path -LiteralPath $Root) { throw "Incomplete MSYS2 folder: $Root. Choose another --msys2-root." }
        if ($Root -match '[^\x21-\x7e]') { throw 'For a new MSYS2 installation choose a short ASCII path without spaces.' }
        Write-Host '[MSYS2] Downloading official installer...'
        $Name='msys2-x86_64-20260927.exe'
        $Url="https://github.com/msys2/msys2-installer/releases/download/2026-09-27/$Name"
        $Installer=Join-Path $Work $Name; $Sum=Join-Path $Work 'msys2.sha256'
        Download-File $Url $Installer; Download-File ($Url+'.sha256') $Sum
        Check-Checksum $Installer $Sum $Name
        $Arguments='in --confirm-command --accept-messages --root "'+$Root.Replace('\','/')+'"'
        $Process=Start-Process -FilePath $Installer -ArgumentList $Arguments -Wait -PassThru
        if ($Process.ExitCode -ne 0 -or !(Test-Path -LiteralPath $Bash)) { throw 'MSYS2 installation failed.' }
    }
    $env:MSYS2_PATH_TYPE='inherit';$env:MSYSTEM='UCRT64'; $env:CHERE_INVOKING='1'
    & $Bash --login -c 'for tool in g++ python rustc cargo cmake ninja make; do command -v "$tool" >/dev/null || exit 1; done' | Out-Host
    if ($LASTEXITCODE -ne 0) {
        Write-Host '[MSYS2] Preparing C++, Python, Rust, CMake and Make tools...'
        # A core update can close its shell. The second full upgrade must succeed.
        & $Bash --login -c 'pacman -Syu --noconfirm' | Out-Host
        & $Bash --login -c 'pacman -Syu --noconfirm' | Out-Host
        if ($LASTEXITCODE -ne 0) { throw 'MSYS2 system update failed.' }
        & $Bash --login -c 'pacman -S --needed --noconfirm mingw-w64-ucrt-x86_64-gcc mingw-w64-ucrt-x86_64-python mingw-w64-ucrt-x86_64-rust mingw-w64-ucrt-x86_64-cmake mingw-w64-ucrt-x86_64-ninja make' | Out-Host
        if ($LASTEXITCODE -ne 0) { throw 'MSYS2 tool installation failed.' }
    }
    return $Root
}
function Write-Bridges([string]$Root) {
    $Bin=Join-Path $Root 'bin'; New-Item -ItemType Directory -Path $Bin -Force | Out-Null
    $Launcher=@'
param([string]$Language,[Parameter(ValueFromRemainingArguments=$true)][string[]]$ForwardedArgs)
$ErrorActionPreference='Stop'
$Root=Split-Path $PSScriptRoot -Parent
if ($ForwardedArgs.Count -gt 0 -and $ForwardedArgs[0] -eq 'update') {
    $Arguments=@('--update','--dir',$Root)
    if ($ForwardedArgs.Count -gt 1) { $Arguments+=$ForwardedArgs[1..($ForwardedArgs.Count-1)] }
    & (Join-Path $Root 'GHOSTNET-Install.cmd') @Arguments
    exit $LASTEXITCODE
}
$State=Get-Content -LiteralPath (Join-Path $Root 'installation.json') -Raw | ConvertFrom-Json
$Bash=Join-Path $State.MsysRoot 'usr\bin\bash.exe'
if (!(Test-Path -LiteralPath $Bash)) { Write-Error 'MSYS2 is missing. Run GHOSTNET-Install.cmd again.'; exit 1 }
$Script='ban.sh';if ($Language -eq 'ru') { $Script='ban-ru.sh' }
$Script=(Join-Path $State.Payload $Script).Replace('\','/')
$env:MSYS2_PATH_TYPE='inherit';$env:MSYSTEM='UCRT64';$env:CHERE_INVOKING='1'
& $Bash --login $Script @ForwardedArgs
exit $LASTEXITCODE
'@
    Set-Content -LiteralPath (Join-Path $Bin 'ghostnet-launch.ps1') -Value $Launcher -Encoding UTF8
    foreach ($Pair in @(@('ghostnet','en'),@('ghostnet-ru','ru'))) {
        $Command="@echo off`r`nsetlocal DisableDelayedExpansion`r`npowershell.exe -NoProfile -ExecutionPolicy Bypass -File `"%~dp0ghostnet-launch.ps1`" $($Pair[1]) %*`r`nexit /b %ERRORLEVEL%`r`n"
        Set-Content -LiteralPath (Join-Path $Bin ($Pair[0]+'.cmd')) -Value $Command -Encoding ASCII
    }
}
function Add-UserPath([string]$Bin) {
    $UserPath=[Environment]::GetEnvironmentVariable('Path','User')
    $Found=@($UserPath -split ';' | Where-Object { $_.TrimEnd('\') -ieq $Bin.TrimEnd('\') }).Count -gt 0
    if (!$Found) {
        $NewPath=$Bin;if ($UserPath) { $NewPath=$UserPath.TrimEnd(';')+';'+$Bin }
        [Environment]::SetEnvironmentVariable('Path',$NewPath,'User')
    }
    if (!(($env:Path -split ';') -contains $Bin)) { $env:Path=$Bin+';'+$env:Path }
    # Tell Explorer to refresh environment for newly opened terminals.
    Add-Type -TypeDefinition @'
using System;using System.Runtime.InteropServices;
public static class GhostnetEnvironment {
 [DllImport("user32.dll",CharSet=CharSet.Unicode,SetLastError=true)]
 public static extern IntPtr SendMessageTimeout(IntPtr h,uint m,UIntPtr w,string l,uint f,uint t,out UIntPtr r);
}
'@
    $Result=[UIntPtr]::Zero
    [void][GhostnetEnvironment]::SendMessageTimeout([IntPtr]0xffff,0x1a,[UIntPtr]::Zero,'Environment',2,5000,[ref]$Result)
}
function Write-ActiveState([string]$Root,[string]$Version,[string]$Payload,[string]$MsysRoot) {
    $State=Join-Path $Root 'installation.json';$Temp=Join-Path $Root ('state-'+[guid]::NewGuid()+'.json')
    @{Version=$Version;Payload=$Payload;MsysRoot=$MsysRoot} | ConvertTo-Json | Set-Content -LiteralPath $Temp -Encoding UTF8
    if (Test-Path -LiteralPath $State) { [IO.File]::Replace($Temp,$State,[NullString]::Value) } else { [IO.File]::Move($Temp,$State) }
}
# Main: downloads and installation require the user's initial confirmation.
$Work=$null;$Lock=$null
try {
    if (![Environment]::Is64BitOperatingSystem -or $env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { throw 'This installer requires x64 Windows 10/11.' }
    $Root=[IO.Path]::GetFullPath($env:GHOSTNET_APP_DIR)
    $Version=$env:GHOSTNET_VERSION
    if ($env:GHOSTNET_UPDATE -eq '1') {
        $Version=Get-LatestVersion
    }
    if ($Version -notmatch '^v\d+\.\d+\.\d+$') { throw 'Invalid stable release version.' }
    Write-Host "GHOSTNET INSTALLER - $Version"
    Write-Host "Install directory: $Root"
    Write-Host 'Installs GHOSTNET, prepares MSYS2 tools if missing, and adds commands to your user PATH.'
    if ($env:GHOSTNET_YES -ne '1') {
        $Answer=Read-Host 'Install / update? [y/N]'
        if ($Answer -notmatch '^(y|yes)$') { Write-Host 'Cancelled.'; exit 0 }
    }
    New-Item -ItemType Directory -Path $Root -Force | Out-Null
    $LockPath=Join-Path $Root '.install.lock'
    $Lock=[IO.File]::Open($LockPath,[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
    $Work=Join-Path ([IO.Path]::GetTempPath()) ('ghostnet-download-'+[guid]::NewGuid())
    New-Item -ItemType Directory -Path $Work | Out-Null
    $Base="https://github.com/$Repository/releases/download/$Version"
    $Archive=Join-Path $Work 'ghostnet-windows.zip';$Checksums=Join-Path $Work 'SHA256SUMS'
    Write-Host '[1/4] Downloading versioned release and checksums...'
    Download-File "$Base/ghostnet-windows.zip" $Archive; Download-File "$Base/SHA256SUMS" $Checksums
    Write-Host '[2/4] Verifying and staging release...'
    $Payload=Install-Payload $Archive $Checksums $Version $Root
    Write-Host '[3/4] Checking MSYS2...'
    $Requested=$env:MSYS2_ROOT
    $StatePath=Join-Path $Root 'installation.json'
    if (!$Requested -and (Test-Path -LiteralPath $StatePath)) { $Requested=(Get-Content -LiteralPath $StatePath -Raw | ConvertFrom-Json).MsysRoot }
    $Msys=Ensure-Msys2 $Requested $Work
    Write-Host '[4/4] Creating commands and updating user PATH...'
    Write-Bridges $Root
    $NewInstaller=Join-Path $Payload 'GHOSTNET-Install.cmd'
    if (!(Test-Path -LiteralPath $NewInstaller)) { $NewInstaller=$env:GHOSTNET_INSTALLER }
    $Destination=Join-Path $Root 'GHOSTNET-Install.cmd'
    if ([IO.Path]::GetFullPath($NewInstaller) -ne [IO.Path]::GetFullPath($Destination)) { Copy-Item -LiteralPath $NewInstaller -Destination $Destination -Force }
    Add-UserPath (Join-Path $Root 'bin')
    Write-ActiveState $Root $Version $Payload $Msys
    Write-Host "Installed $Version. Open a new terminal and run ghostnet or ghostnet-ru."
    if ($env:GHOSTNET_NO_LAUNCH -ne '1') {
        & (Join-Path $Root 'bin\ghostnet.cmd')
        exit $LASTEXITCODE
    }
} catch { Write-Host ('[ERROR] '+$_.Exception.Message) -ForegroundColor Red; exit 1 }
finally {
    if ($Lock) { $Lock.Dispose() }
    if ($Work -and (Test-Path -LiteralPath $Work)) { Remove-Item -LiteralPath $Work -Recurse -Force -ErrorAction SilentlyContinue }
}
