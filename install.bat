@echo off
setlocal EnableDelayedExpansion

::
:: DisplayMirror -- Quick Install Script (Windows)
:: https://github.com/Baghdady92/DisplayMirror
::
:: Usage:
::   install.bat            (auto-detect device)
::   install.bat <serial>   (specify device serial)
::

set REPO=Baghdady92/DisplayMirror
set PACKAGE=com.example.displaymirror
set ACTIVITY=%PACKAGE%/.MainActivity
set APK_NAME=DisplayMirror.apk

:: ── Pre-checks ───────────────────────────────────────────────────────

where adb >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] adb not found. Install Android SDK Platform Tools and add to PATH.
    exit /b 1
)
where curl >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] curl not found. Available by default on Windows 10 1803+.
    exit /b 1
)

:: Device selection
if not "%~1"=="" (
    set DEVICE=%~1
) else (
    for /f "tokens=1" %%A in ('adb devices ^| findstr /r "device$"') do (
        if not defined DEVICE set DEVICE=%%A
    )
)

if not defined DEVICE (
    echo [ERROR] No device connected. Connect a device and try again.
    exit /b 1
)

set ADB=adb -s %DEVICE%
echo [INFO] Device: %DEVICE%

:: ── Step 1: Download latest release APK ─────────────────────────────

echo.
echo ==^> Fetching latest release from GitHub...

for /f "usebackq delims=" %%A in (`powershell -NoProfile -Command "try { (Invoke-RestMethod 'https://api.github.com/repos/%REPO%/releases/latest').assets | Where-Object { $_.name -like '*.apk' } | Select-Object -First 1 -ExpandProperty browser_download_url } catch { exit 1 }"`) do set DOWNLOAD_URL=%%A

if not defined DOWNLOAD_URL (
    echo [ERROR] No APK found in latest release. Check %REPO% on GitHub.
    exit /b 1
)

echo ==^> Downloading APK...
curl -L -o "%APK_NAME%" "%DOWNLOAD_URL%"
if not exist "%APK_NAME%" (
    echo [ERROR] Download failed.
    exit /b 1
)
echo     Downloaded: %APK_NAME%

:: ── Step 2: Install APK ──────────────────────────────────────────────

echo.
echo ==^> Installing APK...
%ADB% install -r "%APK_NAME%"
if %errorlevel% neq 0 (
    echo [ERROR] Installation failed.
    del /f /q "%APK_NAME%" 2>nul
    exit /b 1
)
echo     Installed.

:: ── Step 3: Grant permissions ─────────────────────────────────────────

echo.
echo ==^> Granting permissions...

%ADB% shell appops set %PACKAGE% SYSTEM_ALERT_WINDOW allow
%ADB% shell appops set %PACKAGE% PROJECT_MEDIA allow
%ADB% shell appops set %PACKAGE% REQUEST_INSTALL_PACKAGES allow
%ADB% shell appops set %PACKAGE% USE_FULL_SCREEN_INTENT allow 2>nul

%ADB% shell pm grant %PACKAGE% android.permission.READ_EXTERNAL_STORAGE 2>nul
%ADB% shell pm grant %PACKAGE% android.permission.WRITE_EXTERNAL_STORAGE 2>nul
%ADB% shell pm grant %PACKAGE% android.permission.SYSTEM_ALERT_WINDOW 2>nul
%ADB% shell pm grant %PACKAGE% android.permission.ACCESS_FINE_LOCATION 2>nul
%ADB% shell pm grant %PACKAGE% android.permission.ACCESS_COARSE_LOCATION 2>nul
%ADB% shell pm grant %PACKAGE% android.permission.HIGH_SAMPLING_RATE_SENSORS 2>nul

%ADB% shell pm grant %PACKAGE% android.car.permission.CAR_SPEED 2>nul
%ADB% shell pm grant %PACKAGE% android.car.permission.CAR_ENERGY 2>nul
%ADB% shell pm grant %PACKAGE% android.car.permission.CAR_ENGINE_DETAILED 2>nul
%ADB% shell pm grant %PACKAGE% android.car.permission.CAR_POWERTRAIN 2>nul
%ADB% shell pm grant %PACKAGE% android.car.permission.CAR_TIRES 2>nul
%ADB% shell pm grant %PACKAGE% android.car.permission.CAR_INFO 2>nul
%ADB% shell pm grant %PACKAGE% android.car.permission.CAR_EXTERIOR_ENVIRONMENT 2>nul
%ADB% shell pm grant %PACKAGE% android.car.permission.CAR_MILEAGE 2>nul
%ADB% shell pm grant %PACKAGE% android.car.permission.CAR_VENDOR_EXTENSION 2>nul
%ADB% shell pm grant %PACKAGE% android.car.permission.CAR_DYNAMICS_STATE 2>nul
%ADB% shell pm grant %PACKAGE% android.car.permission.CONTROL_CAR_CLIMATE 2>nul
%ADB% shell pm grant %PACKAGE% android.car.permission.READ_CAR_DISPLAY_UNITS 2>nul
%ADB% shell pm grant %PACKAGE% android.car.permission.CAR_DRIVING_STATE 2>nul
echo     Permissions granted.

echo.
echo ==^> Enabling auto-start on boot...
%ADB% shell dumpsys deviceidle whitelist +%PACKAGE% 2>nul
%ADB% shell pm enable %PACKAGE%/.BootReceiver 2>nul
echo     Auto-start enabled.

:: ── Step 4: Push ADB keys ────────────────────────────────────────────

set ADBKEY=%USERPROFILE%\.android\adbkey
set ADBKEY_PUB=%USERPROFILE%\.android\adbkey.pub

echo.
if exist "%ADBKEY%" (
    if exist "%ADBKEY_PUB%" (
        echo ==^> Pushing ADB keys ^(app auto-imports on start^)...
        %ADB% push "%ADBKEY%" /data/local/tmp/adbkey
        %ADB% push "%ADBKEY_PUB%" /data/local/tmp/adbkey.pub
        echo     ADB keys pushed.
    ) else (
        goto :adbkey_missing
    )
) else (
    :adbkey_missing
    echo [WARNING] ADB keys not found at %ADBKEY%
    echo [WARNING] Force-stop and split-screen will not work without ADB keys.
    echo [WARNING] Generate keys with: adb keygen %%USERPROFILE%%\.android\adbkey
)

:: ── Step 5: Launch ───────────────────────────────────────────────────

echo.
echo ==^> Launching DisplayMirror...
%ADB% shell am start -n "%ACTIVITY%"

:: ── Cleanup ──────────────────────────────────────────────────────────

del /f /q "%APK_NAME%" 2>nul

echo.
echo === Setup complete! ===
echo.
echo Device: %DEVICE%
echo.
echo To update later, the app checks GitHub for new versions automatically.
echo You can also re-run this script at any time.
echo.

endlocal
pause
