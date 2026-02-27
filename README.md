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
- **Self-Update from GitHub** — App checks for new versions on launch and can download & install updates directly on the device (no PC needed)
- **Permissions Dashboard** — View and grant required permissions from within the app, including "Install Unknown Apps" with ADB auto-grant
- **Check for Updates** — Manual update check button in the Permissions dialog
- **Restart App** — Quick restart button in the permissions dialog

## Quick Install (Recommended)

Connect your device via ADB and run:

```bash
curl -sL https://github.com/Baghdady92/DisplayMirror/releases/latest/download/install.sh -o install.sh
chmod +x install.sh
./install.sh
```

This script will:
1. Download the latest APK from GitHub Releases
2. Install it on the connected device
3. Grant all required permissions
4. Push ADB keys for force-stop & split-screen
5. Launch the app

You can also specify a device serial: `./install.sh <serial>`

> **Note:** Requires `adb` and `curl` on your computer. After initial setup, the app can update itself from GitHub — no PC needed.

## Display Setup

| Display ID | Type     | Resolution  | Name              |
|------------|----------|-------------|-------------------|
| 0          | Internal | 2560x1440   | DSI_1 (Main)      |
| 2          | External | 4032x284    | DP_2 (HDMI)       |
| 3          | External | 4032x284    | DP_3 (HDMI)       |
| 4          | External | 1920x480    | DP_4 (HDMI)       |
| 5          | External | 2880x1620   | DP_5 (HDMI)       |

## How It Works

### App Launcher
1. Select a target display from the dropdown (defaults to the saved target)
2. Tap any app icon to launch it on the selected display via `ActivityOptions.setLaunchDisplayId()`
3. Launched apps are tracked in the "Launched Apps" section — tap to force stop via ADB protocol

### Split-Screen Launch
1. Select "Split Left | Right" from the Launch Mode dropdown
2. Tap the first app — it highlights with a teal border (this will be the left app)
3. Tap the second app — both apps launch side-by-side on the target display
4. Tap the same app again to deselect, or switch back to "Fullscreen" to cancel

**How it works:**
1. Enables freeform windowing via ADB: `settings put global enable_freeform_support 1`
2. Launches both apps in freeform mode (`--windowingMode 5`) on the target display
3. Queries `am stack list` to find the task IDs of the newly launched apps
4. Resizes each task to fill exactly half the display: `am task resize <ID> <L> <T> <R> <B>`

> **Note:** Requires ADB keys to be installed (see [Manual Install & Setup](#manual-install--setup)). The split uses Android's freeform windowing mode which may not be supported on all devices.

### Force Stop (via ADB Protocol)
The app communicates with the local ADB daemon on `127.0.0.1:5555` using the ADB wire protocol to execute `am force-stop` with shell (uid=2000) privileges. This bypasses the limitation that normal apps cannot force-stop other apps.

**How it works:**
1. App opens a TCP connection to the local ADB daemon (port 5555)
2. Performs RSA authentication using a pre-installed ADB private key
3. Opens a shell session and runs `am force-stop <package>`
4. Closes the session

**One-time setup:** Push your computer's ADB key to the device (see [Manual Install & Setup](#manual-install--setup)), or use `./install.sh` which does this automatically.

### Self-Update
The app checks GitHub Releases for new versions on every launch. When an update is available:
1. An "Update Available" dialog shows the new version number
2. Tap "Update" to download the APK directly to the device
3. A progress dialog shows download progress
4. Once downloaded, the system package installer launches automatically

The "Install Unknown Apps" permission is required and can be granted from the Permissions dialog via ADB auto-grant. You can also manually check for updates from Permissions > "Check for Updates".

### Screen Mirroring
1. Select a target display from the mirror dropdown (Display 0 is excluded since it's always the source)
2. Tap **Start** to begin mirroring — approve the screen capture consent dialog
3. A `MirrorPresentation` is created on the target display with a full-screen `SurfaceView`
4. A `VirtualDisplay` from `MediaProjection` with `VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR` renders Display 0's content onto the target
5. Tap **Stop** to end the session

> **Note:** Android's MediaProjection API always captures Display 0 (the default display). Mirroring from other source displays is not supported.

### Edge Swipe Gesture
- A foreground service (`SwipeService`) places a narrow invisible overlay (20dp wide, center 40% of screen height) on the left edge of the screen
- Swipe detection: horizontal swipe >= 80dp, vertical drift <= 60dp, duration <= 500ms
- On valid swipe: launches `MainActivity` with `FLAG_ACTIVITY_REORDER_TO_FRONT`
- Starts automatically when the app opens and on device boot

### Floating Overlay Button
- A draggable 56dp circle overlay (teal accent) that floats above all apps
- Tap to open DisplayMirror, drag to reposition
- Toggle on/off from the Permissions dialog
- Persists across reboots when enabled

## Architecture

```
Display 0 (Main)                    Target Display
┌──────────────────┐               ┌──────────────────┐
│                  │  MediaProject  │                  │
│   Main Screen    │ ──────────►   │  MirrorPresent.  │
│                  │  VirtualDisp.  │  (SurfaceView)   │
│  [MainActivity]  │               │  Full Screen      │
└──────────────────┘               └──────────────────┘
         │
         ├─ starts MirrorService       (foreground, screen capture)
         ├─ starts SwipeService        (foreground, edge overlay)
         ├─ starts OverlayButtonService (foreground, floating button)
         ├─ uses AdbShellHelper        (ADB protocol for force-stop)
         └─ uses UpdateChecker         (GitHub releases API for self-update)

BootReceiver ──► SwipeService + OverlayButtonService (auto-start on boot)
```

## UI Layout

1. **Title Row** — "Display Manager" header with "by Baghdady92 · GitHub" subtitle, plus Permissions and Show All Displays buttons
2. **App Launcher Card** — Target display selector + launch mode (Fullscreen / Split) + app grid (12 columns)
3. **Launched Apps Card** — Running apps grid, tap to force stop
4. **Screen Mirror Card** — Target display selector (excludes Display 0) + Start/Stop buttons + status

## Requirements

- Android 11+ (API 30)
- Multi-display hardware (Android Automotive or similar)
- ADB over TCP enabled (the app auto-detects the port; see [Manual Install & Setup](#manual-install--setup) if not pre-configured)
- ADB access for initial permission and key setup

## Build from Source

### Prerequisites

- JDK 17+ (Android Studio or Homebrew `openjdk@17`)
- Android SDK Platform 34
- Android Build Tools 34.0.0+

### Using Make (recommended)

```bash
make help          # Show all available commands
make build         # Build debug APK
make setup         # Build, install, grant permissions, push ADB keys, launch
make run           # Build, install, and launch
make release       # Build signed release APK
make release-github  # Build and publish to GitHub Releases
make deploy        # Bump version + release to GitHub
```

### Manual Build

```bash
export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
# or on macOS with Homebrew:
# export JAVA_HOME=/opt/homebrew/opt/openjdk@17

./gradlew assembleDebug
```

Output APK: `app/build/outputs/apk/debug/app-debug.apk`

## Manual Install & Setup

If you prefer not to use `install.sh`, you can set up manually:

```bash
# Install APK
adb install -r app/build/outputs/apk/debug/app-debug.apk

# Enable plain TCP ADB (required on devices using wireless/TLS ADB)
# Skip this if the device already has persist.adb.tcp.port=5555.
adb tcpip 5555

# Grant required permissions
adb shell appops set com.example.displaymirror SYSTEM_ALERT_WINDOW allow
adb shell appops set com.example.displaymirror PROJECT_MEDIA allow
adb shell appops set com.example.displaymirror REQUEST_INSTALL_PACKAGES allow

# Push ADB keys for force-stop and split-screen functionality (one-time setup)
adb push ~/.android/adbkey /data/local/tmp/adbkey
adb push ~/.android/adbkey.pub /data/local/tmp/adbkey.pub
adb shell "run-as com.example.displaymirror mkdir -p ./files"
adb shell "run-as com.example.displaymirror cp /data/local/tmp/adbkey ./files/adbkey"
adb shell "run-as com.example.displaymirror cp /data/local/tmp/adbkey.pub ./files/adbkey.pub"

# Launch
adb shell am start -n com.example.displaymirror/.MainActivity
```

> **Note:** The ADB key push is a one-time setup. After this, the device can force-stop apps and launch split-screen without a PC connection — even after reboots.
>
> **Note:** On devices connected via wireless ADB (TLS), the `adb tcpip 5555` step enables a plain TCP listener that the app can connect to. This setting may reset on reboot — if ADB features stop working after a reboot, run `adb tcpip 5555` again. Devices with `persist.adb.tcp.port=5555` in their build properties don't need this step.
>
> **Note:** The `SYSTEM_ALERT_WINDOW` permission can also be granted from within the app via the Permissions dialog ("Grant Overlay via ADB" button), as long as ADB keys are installed.

## Usage

1. Open the app on Display 0 (main screen)
2. **Set default target display:** Tap "Show All Displays" and tap "Set Target" on the desired display
3. **Launch apps:** Select a target display, tap an app icon — it opens on that display
4. **Split-screen:** Select "Split Left | Right" from Launch Mode, tap first app (left), tap second app (right) — both launch side-by-side
5. **Force stop apps:** Tap a running app in the "Launched Apps" section, then "Force Stop"
6. **Start mirroring:** Select a target display in the Screen Mirror card, tap "Start", approve capture
7. **Edge swipe:** From any app, swipe right from the left-center edge of the screen to return to DisplayMirror
8. **Overlay button:** Enable from Permissions dialog — a floating circle appears for quick access
9. **Update:** The app checks for updates on launch. You can also check manually from Permissions > "Check for Updates"

## Permissions

| Permission | Purpose |
|------------|---------|
| `FOREGROUND_SERVICE` | Required for foreground services |
| `FOREGROUND_SERVICE_MEDIA_PROJECTION` | Declares the service type for screen capture |
| `SYSTEM_ALERT_WINDOW` | Required for edge swipe overlay, floating button, and Presentation from Service |
| `RECEIVE_BOOT_COMPLETED` | Auto-start services after reboot |
| `QUERY_ALL_PACKAGES` | List all installed apps for the app launcher |
| `KILL_BACKGROUND_PROCESSES` | Force stop launched apps |
| `REQUEST_INSTALL_PACKAGES` | Self-update: install downloaded APK updates |
| `INTERNET` | Self-update: check GitHub releases and download APK |
| `WRITE_EXTERNAL_STORAGE` | Write files to storage |
| `READ_EXTERNAL_STORAGE` | Read files from storage |

Use the **Permissions** button in the app to check which permissions are granted and grant missing ones via ADB.

## Key Design Decisions

| Decision | Reason |
|----------|--------|
| `targetSdk 33` | Avoids Android 14's strict `FOREGROUND_SERVICE_MEDIA_PROJECTION` permission check which requires system-level `CAPTURE_VIDEO_OUTPUT` on non-rooted devices |
| `launchMode="singleTask"` | Prevents duplicate Activity instances when re-opening from launcher or swipe gesture |
| `VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR` | Mirrors the default display content to the VirtualDisplay |
| VirtualDisplay uses target display resolution | Ensures edge-to-edge rendering without black bars |
| `FLAG_LAYOUT_NO_LIMITS` + immersive sticky | Forces the Presentation to cover the entire display including system bar areas |
| `Presentation` API (not `WindowManager`) | Standard Android approach for rendering on secondary displays |
| Static `isRunning()` flags | Allows Activity to sync UI state with services after recreation |
| Mirror dropdown excludes Display 0 | Prevents crash from showing Presentation on the default display |
| `START_STICKY` for SwipeService | System restarts the service if killed |
| SharedPreferences for defaults | Persists target display selection and overlay button state across app restarts |
| ADB `am task resize` for split-screen | `am start --launch-bounds` is not available on Android Automotive 14; instead launch in freeform mode then resize the task by ID |
| Auto-detect ADB port | Different devices use different ports (5555, 55556, etc.); the app probes system properties and common ports at runtime |
| Grant overlay via ADB in-app | Permissions dialog can self-grant `SYSTEM_ALERT_WINDOW` via the ADB client, avoiding the need for manual `adb shell` commands |
| Direct ADB protocol (not daemon) | Each force-stop opens a fresh ADB session — no background process to keep alive |
| RSA key in app internal storage | Survives reinstalls, not accessible by other apps, avoids scoped storage restrictions |
| Self-update via GitHub API | No extra dependencies — uses `HttpURLConnection` + `org.json` (built into Android); `FileProvider` serves APK to system installer |
| Release APK signed with debug key | Allows seamless self-update without signature mismatch on development devices |

## Troubleshooting

### App crashes on "Start Mirroring"

```bash
adb logcat -s MirrorService AndroidRuntime
```

Common causes:
- Missing `PROJECT_MEDIA` appop — run: `adb shell appops set com.example.displaymirror PROJECT_MEDIA allow`
- Missing `SYSTEM_ALERT_WINDOW` — run: `adb shell appops set com.example.displaymirror SYSTEM_ALERT_WINDOW allow`

### Force stop not working

Check that ADB keys are installed:
```bash
adb shell "run-as com.example.displaymirror ls files/adbkey"
```

Check ADB over TCP is enabled:
```bash
adb shell getprop persist.adb.tcp.port
# Should return a port number (e.g. 5555)
# If empty, enable it with:
adb tcpip 5555
```

Check which port the app detected:
```bash
adb logcat -s AdbShellHelper | grep "port"
```

Check logs:
```bash
adb logcat -s AdbShellHelper
```

### Self-update not working

Check that the install permission is granted:
```bash
adb shell appops get com.example.displaymirror REQUEST_INSTALL_PACKAGES
# Should return "allow"
# If not, grant it:
adb shell appops set com.example.displaymirror REQUEST_INSTALL_PACKAGES allow
```

Check update logs:
```bash
adb logcat -s UpdateChecker
```

### Target display not found

Verify the display is connected and active:
```bash
adb shell dumpsys display | grep "Display Id="
```

### Edge swipe not working

Check that the overlay permission is granted:
```bash
adb shell appops get com.example.displaymirror SYSTEM_ALERT_WINDOW
```

Check that SwipeService is running:
```bash
adb shell dumpsys activity services com.example.displaymirror/.SwipeService
```

### Black bars on target display

Ensure the VirtualDisplay is created with the target display's resolution. Check `MirrorService.onSurfaceReady()`.

### Display frozen after stop

Force stop and relaunch:
```bash
adb shell am force-stop com.example.displaymirror
adb shell am start -n com.example.displaymirror/.MainActivity
```

## Project Structure

```
DisplayMirror/
├── build.gradle                          # Project-level Gradle config
├── Makefile                              # Build, install, release automation
├── install.sh                            # One-command install script for end users
├── settings.gradle
├── gradle.properties
├── gradle/wrapper/
│   └── gradle-wrapper.properties         # Gradle 8.10.2
└── app/
    ├── build.gradle                      # App-level config (compileSdk 34, targetSdk 33)
    └── src/main/
        ├── AndroidManifest.xml
        ├── java/com/example/displaymirror/
        │   ├── MainActivity.java         # Main UI — app launcher, mirror controls, permissions, update check
        │   ├── UpdateChecker.java        # GitHub releases API client for self-update
        │   ├── MirrorService.java        # Foreground service managing MediaProjection
        │   ├── MirrorPresentation.java   # Full-screen Presentation on target display
        │   ├── SwipeService.java         # Foreground service with edge swipe overlay
        │   ├── OverlayButtonService.java # Floating draggable overlay button service
        │   ├── BootReceiver.java         # Starts services on boot
        │   ├── AdbShellHelper.java       # ADB protocol client for shell commands
        │   ├── PermissionManager.java    # Permission querying and management helper
        │   ├── CloseActivity.java        # Helper to force-stop apps
        │   ├── AppInfo.java              # Data class for installed apps
        │   ├── AppListAdapter.java       # GridView adapter for app icons
        │   ├── RunningAppInfo.java       # Data class for launched apps
        │   ├── RunningAppAdapter.java    # GridView adapter for running apps
        │   └── ExpandableGridView.java   # Custom GridView that expands to fit content
        └── res/
            ├── layout/
            │   ├── activity_main.xml
            │   ├── presentation_mirror.xml
            │   ├── item_app.xml
            │   └── item_running_app.xml
            ├── drawable/
            │   ├── btn_start.xml
            │   ├── btn_stop.xml
            │   ├── card_bg.xml
            │   ├── overlay_button.xml
            │   └── spinner_bg.xml
            ├── xml/
            │   └── file_paths.xml        # FileProvider paths for APK install
            └── values/
                ├── colors.xml
                ├── strings.xml
                └── styles.xml
```

## License

Internal use.
