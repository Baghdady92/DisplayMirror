# DisplayMirror

Android multi-display management app for Android Automotive systems. Mirrors the primary display to secondary displays, launches apps on any connected display, force-stops running apps, and provides a system-wide edge swipe gesture to open the app from anywhere.

Built and tested on a **Qualcomm Gen4 (SA8775p)** based Android Automotive 14 head unit (Chery/Autolink BSP) with 5 physical displays.

## Features

- **App Launcher** — Launch any installed app on any connected display
- **Split-Screen Launch** — Launch two apps side-by-side (left/right split) on any display using freeform windowing
- **Screen Mirroring** — Mirror Display 0 to any secondary display using MediaProjection
- **Force Stop Apps** — Kill running apps directly via ADB protocol with shell privileges (no root needed)
- **Floating Overlay Button** — Draggable circle overlay for quick access to DisplayMirror from anywhere
- **Edge Swipe Gesture** — Swipe from the left edge of the screen to open DisplayMirror from any app (always-on)
- **Default Target Display** — Set a default target display from the display list, persisted across restarts
- **Auto-start on Boot** — Edge swipe service and overlay button start automatically after device reboot
- **Permissions Dashboard** — View and grant required permissions from within the app

## Requirements

- Android 11+ (API 30)
- Multi-display hardware (Android Automotive or similar)
- ADB over TCP enabled (the app auto-detects the port)
- ADB access for initial permission and key setup

## Download

Download the latest APK from the [Releases](https://github.com/Baghdady92/DisplayMirror/releases) page.

## Install & Setup

```bash
# Install APK
adb install -r DisplayMirror-v2.1.0.apk

# Enable plain TCP ADB (required on devices using wireless/TLS ADB)
adb tcpip 5555

# Grant required permissions
adb shell appops set com.example.displaymirror SYSTEM_ALERT_WINDOW allow
adb shell appops set com.example.displaymirror PROJECT_MEDIA allow

# Push ADB keys for force-stop and split-screen functionality (one-time setup)
adb push ~/.android/adbkey /data/local/tmp/adbkey
adb push ~/.android/adbkey.pub /data/local/tmp/adbkey.pub
adb shell "run-as com.example.displaymirror mkdir -p ./files"
adb shell "run-as com.example.displaymirror cp /data/local/tmp/adbkey ./files/adbkey"
adb shell "run-as com.example.displaymirror cp /data/local/tmp/adbkey.pub ./files/adbkey.pub"

# Launch
adb shell am start -n com.example.displaymirror/.MainActivity
```

## Usage

1. Open the app on Display 0 (main screen)
2. **Set default target display:** Tap "Show All Displays" and tap "Set Target" on the desired display
3. **Launch apps:** Select a target display, tap an app icon — it opens on that display
4. **Split-screen:** Select "Split Left | Right" from Launch Mode, tap first app (left), tap second app (right) — both launch side-by-side
5. **Force stop apps:** Tap a running app in the "Launched Apps" section, then "Force Stop"
6. **Start mirroring:** Select a target display in the Screen Mirror card, tap "Start", approve capture
7. **Edge swipe:** From any app, swipe right from the left-center edge of the screen to return to DisplayMirror
8. **Overlay button:** Enable from Permissions dialog — a floating circle appears for quick access

## Permissions

| Permission | Purpose |
|------------|---------|
| `FOREGROUND_SERVICE` | Required for foreground services |
| `FOREGROUND_SERVICE_MEDIA_PROJECTION` | Declares the service type for screen capture |
| `SYSTEM_ALERT_WINDOW` | Required for edge swipe overlay, floating button, and Presentation from Service |
| `RECEIVE_BOOT_COMPLETED` | Auto-start services after reboot |
| `QUERY_ALL_PACKAGES` | List all installed apps for the app launcher |

## License

All rights reserved.
