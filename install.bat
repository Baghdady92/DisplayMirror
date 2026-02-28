@echo off
setlocal enabledelayedexpansion
REM
REM  DisplayMirror — Quick Install Script (Windows)
REM  https://github.com/Baghdady92/DisplayMirror
REM
REM  Downloads the latest release APK from GitHub, installs it on a connected
REM  Android device, grants required permissions, and pushes ADB keys.
REM
REM  Usage:
REM    install.bat              # auto-detect device
REM    install.bat <serial>     # specify device serial
REM

set "REPO=Baghdady92/DisplayMirror"
set "PACKAGE=com.example.displaymirror"
set "ACTIVITY=%PACKAGE%/.MainActivity"
set "APK_NAME=DisplayMirror.apk"

REM ── Pre-checks ───────────────────────────────────────────────────────

where adb >nul 2>&1
if %errorlevel% neq 0 (
    echo [33mADB not found. Downloading Android SDK Platform Tools...[0m
    set "PT_ZIP=%TEMP%\platform-tools.zip"
    set "PT_DIR=%USERPROFILE%\platform-tools"
    curl -L -o "!PT_ZIP!" "https://dl.google.com/android/repository/platform-tools-latest-windows.zip"
    if not exist "!PT_ZIP!" (
        echo [31mERROR: Failed to download Platform Tools.[0m
        exit /b 1
    )
    echo [36m==^> Extracting to !PT_DIR!...[0m
    powershell -NoProfile -Command "Expand-Archive -Path '!PT_ZIP!' -DestinationPath '%USERPROFILE%' -Force"
    del /f "!PT_ZIP!" >nul 2>&1
    if not exist "!PT_DIR!\adb.exe" (
        echo [31mERROR: Extraction failed. adb.exe not found in !PT_DIR![0m
        exit /b 1
    )
    set "PATH=!PT_DIR!;!PATH!"
    echo [32m    ADB installed to !PT_DIR![0m
    echo [33m    To make permanent, add !PT_DIR! to your system PATH.[0m
)

where curl >nul 2>&1
if %errorlevel% neq 0 (
    echo [31mERROR: curl not found. Windows 10+ includes curl by default.[0m
    exit /b 1
)

REM ── Device selection ────────────────────────────────────────────────

if not "%~1"=="" (
    set "DEVICE=%~1"
) else (
    for /f "skip=1 tokens=1,2" %%a in ('adb devices') do (
        if "%%b"=="device" (
            if not defined DEVICE set "DEVICE=%%a"
        )
    )
)

if not defined DEVICE (
    echo [31mERROR: No device connected. Connect a device and try again.[0m
    exit /b 1
)

set "ADB=adb -s %DEVICE%"
echo [1mDevice: %DEVICE%[0m

REM ── Step 1: Download latest release APK ──────────────────────────────

echo [36m==^> Fetching latest release from GitHub...[0m

REM Use PowerShell to parse JSON and extract APK download URL
for /f "delims=" %%u in ('powershell -NoProfile -Command ^
    "$r = Invoke-RestMethod -Uri 'https://api.github.com/repos/%REPO%/releases/latest'; ^
     $a = $r.assets | Where-Object { $_.name -like '*.apk' } | Select-Object -First 1; ^
     if ($a) { $a.browser_download_url }"') do set "DOWNLOAD_URL=%%u"

if not defined DOWNLOAD_URL (
    echo [31mERROR: No APK found in latest release. Check %REPO% on GitHub.[0m
    exit /b 1
)

REM Extract version from URL
for /f "delims=" %%v in ('powershell -NoProfile -Command ^
    "if ('%DOWNLOAD_URL%' -match 'v[\d]+\.[\d]+\.[\d]+') { $Matches[0] }"') do set "VERSION=%%v"

echo [36m==^> Downloading %VERSION%...[0m
curl -L -o "%APK_NAME%" "%DOWNLOAD_URL%"

if not exist "%APK_NAME%" (
    echo [31mERROR: Download failed.[0m
    exit /b 1
)
echo [32m    Downloaded: %APK_NAME%[0m

REM ── Step 2: Install APK ─────────────────────────────────────────────

echo [36m==^> Installing APK...[0m
%ADB% install -r "%APK_NAME%"
if %errorlevel% neq 0 (
    echo [31mERROR: APK installation failed.[0m
    exit /b 1
)
echo [32m    Installed.[0m

REM ── Step 3: Grant permissions ────────────────────────────────────────

echo [36m==^> Granting permissions...[0m
%ADB% shell appops set %PACKAGE% SYSTEM_ALERT_WINDOW allow
%ADB% shell appops set %PACKAGE% PROJECT_MEDIA allow
%ADB% shell appops set %PACKAGE% REQUEST_INSTALL_PACKAGES allow
echo [32m    Permissions granted.[0m

REM ── Step 4: Push ADB keys ───────────────────────────────────────────

set "ADBKEY=%USERPROFILE%\.android\adbkey"
set "ADBKEY_PUB=%USERPROFILE%\.android\adbkey.pub"

if exist "%ADBKEY%" if exist "%ADBKEY_PUB%" (
    echo [36m==^> Pushing ADB keys ^(app auto-imports on start^)...[0m
    %ADB% push "%ADBKEY%" /data/local/tmp/adbkey
    %ADB% push "%ADBKEY_PUB%" /data/local/tmp/adbkey.pub
    echo [32m    ADB keys pushed.[0m
) else (
    echo [31m    WARNING: ADB keys not found at %ADBKEY%[0m
    echo [31m    Force-stop and split-screen will not work without ADB keys.[0m
    echo [31m    Generate keys with: adb keygen %USERPROFILE%\.android\adbkey[0m
)

REM ── Step 5: Launch ───────────────────────────────────────────────────

echo [36m==^> Launching DisplayMirror...[0m
%ADB% shell am start -n "%ACTIVITY%"

REM ── Cleanup ──────────────────────────────────────────────────────────

del /f "%APK_NAME%" >nul 2>&1

echo.
echo [32m=== Setup complete! ===[0m
echo.
echo [1mInstalled: DisplayMirror %VERSION%[0m
echo [1mDevice:    %DEVICE%[0m
echo.
echo To update later, the app checks GitHub for new versions automatically.
echo You can also re-run this script at any time.

endlocal
