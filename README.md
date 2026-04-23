# EyeSafe

A lightweight macOS menu bar app that protects your eyes using the 20/20/20 rule: every 20 minutes, take a 20-second break and look at something 20 feet away.

EyeSafe sits quietly in your menu bar, tracks your work time, and notifies you when it's time to rest your eyes. No dock icon, no clutter, no subscriptions.

## Requirements

- macOS 13 (Ventura) or later
- Xcode 15 or later (for building from source)

## Installation

### Option 1: Build and install with the terminal

```bash
# Clone the repository
git clone https://github.com/jakub-walaszczyk/eyesafe.git
cd eyesafe

# Build the app
xcodebuild -project EyeSafe.xcodeproj -scheme EyeSafe -configuration Release build

# Copy to Applications
cp -R "$(xcodebuild -project EyeSafe.xcodeproj -scheme EyeSafe -configuration Release -showBuildSettings 2>/dev/null | grep -m1 'BUILT_PRODUCTS_DIR' | awk '{print $3}')/EyeSafe.app" /Applications/

# Launch it
open /Applications/EyeSafe.app
```

### Option 2: Build with Xcode

1. Clone the repository:
   ```bash
   git clone https://github.com/jakub-walaszczyk/eyesafe.git
   ```
2. Open `EyeSafe.xcodeproj` in Xcode.
3. Press **Cmd+R** to build and run.
4. To install permanently, change the scheme to **Release** (Product > Scheme > Edit Scheme > Run > Build Configuration > Release), build with **Cmd+B**, then right-click the product in Xcode's Project Navigator and choose **Show in Finder**. Copy `EyeSafe.app` to `/Applications`.

### After installation

- An **eye icon** will appear in your menu bar (top-right of your screen).
- The app has no dock icon — this is by design.
- On first launch, macOS will ask for notification permission. Grant it to receive break reminders.

### Uninstalling

1. Quit EyeSafe (click the eye icon > Quit).
2. Delete `EyeSafe.app` from `/Applications`.
3. Optionally remove saved settings:
   ```bash
   defaults delete com.eyesafe.app
   ```

## Usage

### Getting started

1. Launch EyeSafe. An **eye icon** appears in your menu bar.
2. Click the icon to open the popover.
3. Click **Start**. The 20-minute countdown begins.
4. When the timer runs out, you'll receive a notification: *"Time for a break! Look at something 20 feet away for 20 seconds."*
5. A 20-second break countdown starts automatically.
6. After the break, the work timer restarts. The cycle repeats until you pause or quit.

### Controls

| Button | When it appears | What it does |
|--------|----------------|--------------|
| **Start** | Timer is idle | Begins the work countdown |
| **Pause** | Timer is running | Freezes the countdown |
| **Resume** | Timer is paused | Continues from where you left off |
| **Reset** | Timer is running or paused | Stops the timer and returns to idle |
| **Skip** | During a break | Skips the remaining break time and starts a new work interval |

### Menu bar icon

- **Eye icon** — normal state (idle or working)
- **Eye with exclamation mark** — break time (look away from your screen)

### Settings

Click the **gear icon** in the popover to expand the settings panel:

- **Work interval** — How long you work before a break (1 to 60 minutes, default: 20 minutes)
- **Break duration** — How long each break lasts (5 to 120 seconds, default: 20 seconds)
- **Notification sound** — Play a sound with break notifications (on/off)
- **Show timer in menu bar** — Display the remaining time next to the eye icon in the menu bar (on/off, default: off). Note: this takes extra menu bar space
- **Launch at login** — Start EyeSafe automatically when you log in (on/off)

All settings are saved automatically and persist across app restarts.

### Notifications

The first time you start the timer, macOS will ask for notification permission. Grant it to receive break reminders as banner notifications.

If you accidentally denied permission, you can re-enable it in **System Settings > Notifications > EyeSafe**.

The app still works without notification permission — the popover and menu bar icon will update, but you won't see banner notifications or hear sounds.

### Sleep and wake

If your Mac goes to sleep while the timer is running, EyeSafe adjusts automatically when it wakes up. If the work interval expired during sleep, you'll get a break notification immediately upon waking.

If the timer was paused before sleep, it stays paused.

## Quitting

Click the eye icon in the menu bar, then click **Quit** at the bottom of the popover.

## Privacy

EyeSafe:
- Runs entirely on your Mac. No data is sent anywhere.
- Only requests notification permission. No other system permissions are needed.
- Stores settings locally in macOS UserDefaults.
- Has no network access, analytics, or telemetry.
- Zero third-party dependencies — built entirely with Apple frameworks.

## Tech Stack

- Swift + SwiftUI
- macOS 13+ (MenuBarExtra, SMAppService)
- No third-party dependencies

## Troubleshooting

**The eye icon doesn't appear in the menu bar**
Make sure the app is running. Check Activity Monitor for a "EyeSafe" process. If your menu bar is crowded, the icon may be hidden — try closing other menu bar apps.

**Notifications don't appear**
Open System Settings > Notifications > EyeSafe and make sure notifications are allowed. Also check that your Mac is not in a Focus mode that silences EyeSafe.

**Launch at login doesn't stick**
Check System Settings > General > Login Items and make sure EyeSafe is listed and enabled.

**"EyeSafe.app is damaged" or Gatekeeper warning**
Since the app is not notarized, macOS may block it. Right-click the app, choose **Open**, then click **Open** in the dialog. You only need to do this once.

## License

MIT
