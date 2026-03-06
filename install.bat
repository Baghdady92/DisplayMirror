@echo off
setlocal EnableDelayedExpansion

:: ============================================================
::  DisplayMirror — Quick Install Script (Windows)
::  https://github.com/Baghdady92/DisplayMirror
::
::  Usage:
::    install.bat              (auto-detect device)
::    install.bat <serial>     (specify device serial)
:: ============================================================

set "REPO=Baghdady92/DisplayMirror"
set "PACKAGE=com.example.displaymirror"
set "ACTIVITY=%PACKAGE%/.MainActivity"
set "APK_NAME=DisplayMirror.apk"
set "DEVICE=%~1"

:: ── Color helpers (via PowerShell) ───────────────────────────

call :cyan "========================================"
call :bold  "   DisplayMirror Installer for Windows  "
call :cyan  "========================================"
echo.

:: ── Pre-checks ───────────────────────────────────────────────

call :cyan "==> Checking required tools..."

where adb >nul 2>&1
if %errorlevel% neq 0 (
    call :red "ERROR: adb not found in PATH."
    call :red "       Download Android SDK Platform Tools from:"
    call :red "       https://developer.android.com/studio/releases/platform-tools"
    pause
    exit /b 1
)

where curl >nul 2>&1
if %errorlevel% neq 0 (
    call :red "ERROR: curl not found. Windows 10 v1803+ should have curl built-in."
    call :red "       If missing, download from: https://curl.se/windows/"
    pause
    exit /b 1
)

where powershell >nul 2>&1
if %errorlevel% neq 0 (
    call :red "ERROR: PowerShell not found. Required for JSON parsing."
    pause
    exit /b 1
)

call :green "    All required tools found."
echo.

:: ── Device selection ─────────────────────────────────────────

if not "%DEVICE%"=="" (
    call :bold "Device (specified): %DEVICE%"
    goto :device_ok
)

call :cyan "==> Detecting connected device..."

:: Parse 'adb devices' output to find first connected device
for /f "skip=1 tokens=1,2" %%A in ('adb devices 2^>nul') do (
    if "%%B"=="device" (
        if "%DEVICE%"=="" set "DEVICE=%%A"
    )
)

if "%DEVICE%"=="" (
    call :red "ERROR: No device connected."
    call :red "       Connect an Android device with USB debugging enabled and try again."
    pause
    exit /b 1
)

:device_ok
call :bold "Device: %DEVICE%"
set "ADB=adb -s %DEVICE%"
echo.

:: ── Step 1: Download latest release APK ──────────────────────

call :cyan "==> Fetching latest release from GitHub..."

:: Use PowerShell to query GitHub API and extract APK download URL
for /f "usebackq delims=" %%U in (
    `powershell -NoProfile -Command "try { $r = Invoke-RestMethod -Uri 'https://api.github.com/repos/%REPO%/releases/latest' -UseBasicParsing; $asset = $r.assets | Where-Object { $_.name -like '*.apk' } | Select-Object -First 1; Write-Output $asset.browser_download_url } catch { Write-Output '' }"`
) do set "DOWNLOAD_URL=%%U"

if "%DOWNLOAD_URL%"=="" (
    call :red "ERROR: No APK found in latest release."
    call :red "       Check https://github.com/%REPO%/releases"
    pause
    exit /b 1
)

:: Extract version tag from URL
for /f "usebackq delims=" %%V in (
    `powershell -NoProfile -Command "if ('%DOWNLOAD_URL%' -match '(v[0-9]+\.[0-9]+\.[0-9]+)') { $matches[1] } else { 'unknown' }"`
) do set "VERSION=%%V"

call :cyan "==> Downloading %VERSION%..."
curl -L -o "%APK_NAME%" "%DOWNLOAD_URL%"

if not exist "%APK_NAME%" (
    call :red "ERROR: Download failed. Check your internet connection."
    pause
    exit /b 1
)
call :green "    Downloaded: %APK_NAME%"
echo.

:: ── Step 2: Install APK ──────────────────────────────────────

call :cyan "==> Installing APK on device..."
%ADB% install -r "%APK_NAME%"
if %errorlevel% neq 0 (
    call :red "ERROR: APK installation failed."
    del /f "%APK_NAME%" >nul 2>&1
    pause
    exit /b 1
)
call :green "    Installed successfully."
echo.

:: ── Step 3: Grant permissions ─────────────────────────────────

call :cyan "==> Granting permissions..."

:: Special appops permissions
%ADB% shell appops set %PACKAGE% SYSTEM_ALERT_WINDOW allow
%ADB% shell appops set %PACKAGE% PROJECT_MEDIA allow
%ADB% shell appops set %PACKAGE% REQUEST_INSTALL_PACKAGES allow
%ADB% shell appops set %PACKAGE% USE_FULL_SCREEN_INTENT allow 2>nul

:: Runtime permissions (errors silently ignored — device may not support all)
%ADB% shell pm grant %PACKAGE% android.permission.READ_EXTERNAL_STORAGE         2>nul
%ADB% shell pm grant %PACKAGE% android.permission.WRITE_EXTERNAL_STORAGE        2>nul
%ADB% shell pm grant %PACKAGE% android.permission.SYSTEM_ALERT_WINDOW           2>nul
%ADB% shell pm grant %PACKAGE% android.permission.ACCESS_FINE_LOCATION          2>nul
%ADB% shell pm grant %PACKAGE% android.permission.ACCESS_COARSE_LOCATION        2>nul
%ADB% shell pm grant %PACKAGE% android.permission.HIGH_SAMPLING_RATE_SENSORS    2>nul

:: Android Automotive / Car permissions
%ADB% shell pm grant %PACKAGE% android.car.permission.CAR_SPEED                 2>nul
%ADB% shell pm grant %PACKAGE% android.car.permission.CAR_ENERGY                2>nul
%ADB% shell pm grant %PACKAGE% android.car.permission.CAR_ENGINE_DETAILED       2>nul
%ADB% shell pm grant %PACKAGE% android.car.permission.CAR_POWERTRAIN            2>nul
%ADB% shell pm grant %PACKAGE% android.car.permission.CAR_TIRES                 2>nul
%ADB% shell pm grant %PACKAGE% android.car.permission.CAR_INFO                  2>nul
%ADB% shell pm grant %PACKAGE% android.car.permission.CAR_EXTERIOR_ENVIRONMENT  2>nul
%ADB% shell pm grant %PACKAGE% android.car.permission.CAR_MILEAGE               2>nul
%ADB% shell pm grant %PACKAGE% android.car.permission.CAR_VENDOR_EXTENSION      2>nul
%ADB% shell pm grant %PACKAGE% android.car.permission.CAR_DYNAMICS_STATE        2>nul
%ADB% shell pm grant %PACKAGE% android.car.permission.CONTROL_CAR_CLIMATE       2>nul
%ADB% shell pm grant %PACKAGE% android.car.permission.READ_CAR_DISPLAY_UNITS    2>nul
%ADB% shell pm grant %PACKAGE% android.car.permission.CAR_DRIVING_STATE         2>nul

call :green "    Permissions granted."
echo.

:: ── Step 4: Enable auto-start ─────────────────────────────────

call :cyan "==> Enabling auto-start on boot..."
%ADB% shell dumpsys deviceidle whitelist +%PACKAGE%  2>nul
%ADB% shell pm enable %PACKAGE%/.BootReceiver        2>nul
call :green "    Auto-start enabled."
echo.

:: ── Step 5: Push ADB keys ─────────────────────────────────────

call :cyan "==> Pushing ADB keys..."

set "ADBKEY=%USERPROFILE%\.android\adbkey"
set "ADBKEY_PUB=%USERPROFILE%\.android\adbkey.pub"

if exist "%ADBKEY%" if exist "%ADBKEY_PUB%" (
    %ADB% push "%ADBKEY%"     /data/local/tmp/adbkey
    %ADB% push "%ADBKEY_PUB%" /data/local/tmp/adbkey.pub
    call :green "    ADB keys pushed."
) else (
    call :red "    WARNING: ADB keys not found at %USERPROFILE%\.android\"
    call :red "    Force-stop and split-screen features will not work without ADB keys."
    call :red "    Generate keys by running:  adb keygen %USERPROFILE%\.android\adbkey"
)
echo.

:: ── Step 6: Launch app ────────────────────────────────────────

call :cyan "==> Launching DisplayMirror..."
%ADB% shell am start -n "%ACTIVITY%"
echo.

:: ── Cleanup ───────────────────────────────────────────────────

del /f "%APK_NAME%" >nul 2>&1

call :green "========================================"
call :green "   Setup complete!"
call :green "========================================"
echo.
call :bold "Installed : DisplayMirror %VERSION%"
call :bold "Device    : %DEVICE%"
echo.
echo To update later, the app checks GitHub for new versions automatically.
echo You can also re-run this script at any time.
echo.
pause
exit /b 0

:: ═══════════════════════════════════════════════════
::  Color subroutines (PowerShell-based)
:: ═══════════════════════════════════════════════════

:red
powershell -NoProfile -Command "Write-Host '%~1' -ForegroundColor Red"
goto :eof

:green
powershell -NoProfile -Command "Write-Host '%~1' -ForegroundColor Green"
goto :eof

:cyan
powershell -NoProfile -Command "Write-Host '%~1' -ForegroundColor Cyan"
goto :eof

:bold
powershell -NoProfile -Command "Write-Host '%~1' -ForegroundColor White"
goto :eof
