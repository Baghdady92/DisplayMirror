#!/bin/bash
#
# DisplayMirror — Quick Install Script
# https://github.com/Baghdady92/DisplayMirror
#
# Downloads the latest release APK from GitHub, installs it on a connected
# Android device, grants required permissions, and pushes ADB keys.
#
# Usage:
#   ./install.sh            # auto-detect device
#   ./install.sh <serial>   # specify device serial
#

set -e

REPO="Baghdady92/DisplayMirror"
PACKAGE="com.example.displaymirror"
ACTIVITY="$PACKAGE/.MainActivity"
APK_NAME="DisplayMirror.apk"

# ── Helpers ──────────────────────────────────────────────────────────

red()   { printf "\033[31m%s\033[0m\n" "$*"; }
green() { printf "\033[32m%s\033[0m\n" "$*"; }
cyan()  { printf "\033[36m%s\033[0m\n" "$*"; }
bold()  { printf "\033[1m%s\033[0m\n" "$*"; }

fail() { red "ERROR: $*"; exit 1; }

# ── Pre-checks ───────────────────────────────────────────────────────

command -v adb >/dev/null 2>&1 || fail "adb not found. Install Android SDK Platform Tools."
command -v curl >/dev/null 2>&1 || fail "curl not found."

# Device selection
if [ -n "$1" ]; then
    DEVICE="$1"
else
    DEVICE=$(adb devices | awk 'NR==2 && $2=="device" {print $1}')
fi
[ -z "$DEVICE" ] && fail "No device connected. Connect a device and try again."

ADB="adb -s $DEVICE"
bold "Device: $DEVICE"

# ── Step 1: Download latest release APK ──────────────────────────────

cyan "==> Fetching latest release from GitHub..."
DOWNLOAD_URL=$(curl -s "https://api.github.com/repos/$REPO/releases/latest" \
    | grep "browser_download_url.*\.apk" \
    | head -1 \
    | cut -d '"' -f 4)

[ -z "$DOWNLOAD_URL" ] && fail "No APK found in latest release. Check $REPO on GitHub."

VERSION=$(echo "$DOWNLOAD_URL" | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+')
cyan "==> Downloading $VERSION..."
curl -L -o "$APK_NAME" "$DOWNLOAD_URL"
[ -f "$APK_NAME" ] || fail "Download failed."
green "    Downloaded: $APK_NAME"

# ── Step 2: Install APK ─────────────────────────────────────────────

cyan "==> Installing APK..."
$ADB install -r "$APK_NAME"
green "    Installed."

# ── Step 3: Grant permissions ────────────────────────────────────────

cyan "==> Granting permissions..."
$ADB shell appops set $PACKAGE SYSTEM_ALERT_WINDOW allow
$ADB shell appops set $PACKAGE PROJECT_MEDIA allow
$ADB shell appops set $PACKAGE REQUEST_INSTALL_PACKAGES allow
green "    Permissions granted."

# ── Step 4: Push ADB keys ───────────────────────────────────────────

ADBKEY="$HOME/.android/adbkey"
ADBKEY_PUB="$HOME/.android/adbkey.pub"

if [ -f "$ADBKEY" ] && [ -f "$ADBKEY_PUB" ]; then
    cyan "==> Pushing ADB keys (app auto-imports on start)..."
    $ADB push "$ADBKEY" /data/local/tmp/adbkey
    $ADB push "$ADBKEY_PUB" /data/local/tmp/adbkey.pub
    green "    ADB keys pushed."
else
    red "    WARNING: ADB keys not found at $ADBKEY"
    red "    Force-stop and split-screen will not work without ADB keys."
    red "    Generate keys with: adb keygen ~/.android/adbkey"
fi

# ── Step 5: Launch ───────────────────────────────────────────────────

cyan "==> Launching DisplayMirror..."
$ADB shell am start -n "$ACTIVITY"

# ── Cleanup ──────────────────────────────────────────────────────────

rm -f "$APK_NAME"

echo ""
green "=== Setup complete! ==="
echo ""
bold "Installed: DisplayMirror $VERSION"
bold "Device:    $DEVICE"
echo ""
echo "To update later, the app checks GitHub for new versions automatically."
echo "You can also re-run this script at any time."
