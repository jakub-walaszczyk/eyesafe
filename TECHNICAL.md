# EyeSafe - Technical Documentation

This document covers everything a developer needs to understand about the EyeSafe project: what was built, how the pieces fit together, what system resources the app touches, and how the Xcode build system turns the source files into a running macOS application.

## What is EyeSafe

EyeSafe is a native macOS menu bar application that implements the 20/20/20 rule: every 20 minutes of screen work, look at something 20 feet away for 20 seconds. The app lives entirely in the macOS menu bar (the strip of icons in the top-right corner of the screen). It has no dock icon and no main window.

## Project Structure

```
eyesafe/
├── CLAUDE.md                          # Build plan and architecture notes
├── TECHNICAL.md                       # This file
├── README.md                          # User-facing documentation
├── EyeSafe.xcodeproj/
│   └── project.pbxproj                # Xcode project definition
└── EyeSafe/
    ├── Info.plist                      # App configuration (hides dock icon)
    ├── EyeSafe.entitlements         # Security entitlements
    ├── Package.swift                   # Swift Package Manager manifest (alternative build)
    └── Sources/EyeSafe/
        ├── EyeSafeApp.swift         # App entry point
        ├── Models/
        │   └── TimerState.swift        # State machine enum
        ├── ViewModels/
        │   └── TimerViewModel.swift    # Timer logic and state management
        ├── Views/
        │   ├── MenuBarView.swift       # Main popover UI
        │   └── SettingsView.swift      # Preferences panel
        ├── Services/
        │   └── NotificationManager.swift  # macOS notification delivery
        └── Assets.xcassets/            # Asset catalog (app icons)
            ├── Contents.json
            └── AppIcon.appiconset/
                └── Contents.json
```

## How to Build

There are two ways to build the project:

### Option A: Xcode (recommended for a proper .app bundle)

```bash
xcodebuild -project EyeSafe.xcodeproj -scheme EyeSafe -configuration Debug build
```

The built `.app` bundle lands in `~/Library/Developer/Xcode/DerivedData/EyeSafe-<hash>/Build/Products/Debug/EyeSafe.app`. You can also open `EyeSafe.xcodeproj` in Xcode and press Cmd+R to build and run.

### Option B: Swift Package Manager (command-line executable only)

```bash
cd EyeSafe
swift build
```

This compiles the code but produces a bare executable, not a `.app` bundle. The app will still work (menu bar icon appears, timer runs) but it will show a dock icon because there is no `Info.plist` bundled with it. Use Option A for the full experience.

## Architecture Overview

The app follows the MVVM (Model-View-ViewModel) pattern with a service layer:

```
EyeSafeApp (entry point)
    │
    ├── TimerViewModel (ObservableObject — owns all timer logic)
    │       │
    │       └── NotificationManager (singleton — delivers macOS notifications)
    │
    └── MenuBarView (SwiftUI — popover UI)
            │
            └── SettingsView (SwiftUI — inline preferences)
```

Data flows one way: `TimerViewModel` publishes state changes via `@Published`, and SwiftUI views reactively update. Settings flow from views to the view model via a `syncSettings()` bridge that runs whenever `@AppStorage` values change.

## File-by-File Breakdown

### EyeSafeApp.swift

This is the app entry point, marked with `@main`. It defines a single `Scene` using `MenuBarExtra` — a SwiftUI API introduced in macOS 13 that creates a menu bar item with an attached popover window.

Key details:
- `@StateObject private var viewModel` creates a single `TimerViewModel` instance that lives for the entire app lifetime. `@StateObject` ensures it is created once and never re-created across SwiftUI view updates.
- `@AppStorage("showTimerInMenuBar")` reads a boolean from `UserDefaults` to decide whether to show the countdown next to the menu bar icon.
- `.menuBarExtraStyle(.window)` makes the popover a floating window (as opposed to `.menu`, which would render a plain dropdown menu).
- The `label` closure controls what appears in the menu bar: an SF Symbol icon (`eye` or `eye.trianglebadge.exclamationmark`) and optionally the remaining time as text.

### Models/TimerState.swift

A Swift `enum` that models the app's finite state machine. The four states are:

| State | Associated Data | Meaning |
|-------|----------------|---------|
| `.idle` | none | Timer has not been started |
| `.working(remaining:)` | `TimeInterval` (seconds left) | Counting down the work interval |
| `.breakTime(remaining:)` | `TimeInterval` (seconds left) | Counting down the break |
| `.paused(previous:)` | `PausedState` | Timer frozen, remembers what to resume |

`PausedState` is a nested enum with two cases (`.working` and `.breakTime`), each carrying the remaining seconds. This lets the app resume exactly where it left off.

The enum conforms to `Equatable` so SwiftUI can detect state changes and re-render views. It also exposes convenience computed properties (`isIdle`, `isPaused`, `isWorking`, `isBreakTime`, `remaining`) so views and the view model can query state without `switch` statements everywhere.

### ViewModels/TimerViewModel.swift

This is the core of the app. It is an `ObservableObject` — a class that SwiftUI observes for changes. When the `@Published var state` property changes, every view that references this object re-renders.

**Timer mechanism:** Uses Combine's `Timer.publish(every: 1, on: .main, in: .common)` to create a publisher that emits every second on the main run loop. The `sink` subscriber calls `tick()`, which decrements the remaining time by 1 and transitions state when time runs out.

**State transitions:**
- `idle` → `start()` → `working(workInterval)`
- `working(0)` → `breakTime(breakDuration)` + break notification
- `breakTime(0)` → `working(workInterval)` + break-over notification
- Any running state → `pause()` → `paused(previous state)`
- `paused` → `resume()` → restore previous state
- Any state → `reset()` → `idle`
- `breakTime` → `skip()` → `working(workInterval)`

**Sleep/wake handling:** On `init()`, the view model registers two observers with `NSWorkspace.shared.notificationCenter`:
- `willSleepNotification`: Records the current time and stops the timer.
- `didWakeNotification`: Calculates how long the Mac was asleep and subtracts that from the remaining time. If the remaining time went negative during sleep (e.g., the work interval expired while the lid was closed), it transitions to the next state and fires the appropriate notification.

**Computed properties for the UI:**
- `formattedTime`: Converts remaining seconds to "M:SS" or "Ns" format.
- `statusText`: Human-readable status like "Working — 18:42 left".
- `menuBarTitle`: Shorter string for the menu bar (just the time, or a pause icon).
- `progress`: A 0.0–1.0 fraction for the circular progress indicator.
- `menuBarIcon`: Returns the appropriate SF Symbol name.

### Views/MenuBarView.swift

The main popover content. It is a `VStack` with four sections:

1. **Header:** An SF Symbol icon and status text. The icon turns orange during breaks.
2. **Progress ring:** A `ZStack` of two `Circle` shapes — a gray background ring and a colored foreground arc that fills as time progresses. Uses `.trim(from:to:)` to draw a partial circle and `.rotationEffect(.degrees(-90))` to start from the top (12 o'clock position). Only shown when the timer is running.
3. **Controls:** Context-sensitive buttons. Shows "Start" when idle, "Pause/Reset" when running (plus "Skip" during breaks), and "Resume/Reset" when paused.
4. **Bottom bar:** A gear button that toggles the inline settings panel, and a "Quit" button that calls `NSApplication.shared.terminate(nil)`.

**Settings synchronization:** The view owns `@AppStorage` properties for work interval, break duration, and sound toggle. Whenever any of these change (detected via `.onChange(of:)`), the `syncSettings()` method pushes the new values into the `TimerViewModel`. This keeps settings in `UserDefaults` (persistent) and mirrors them into the view model (runtime). The `@AppStorage` wrapper is a SwiftUI property wrapper that reads from and writes to `UserDefaults` automatically.

### Views/SettingsView.swift

An inline settings panel embedded in the popover (not a separate window). It receives `@Binding` properties from `MenuBarView`, meaning changes here flow back to the parent and get synced to the view model.

Controls:
- **Work interval slider:** 1–60 minutes, step 1. Shows the current value as text above the slider.
- **Break duration slider:** 5–120 seconds, step 5.
- **Notification sound toggle.**
- **Show timer in menu bar toggle.**
- **Launch at login toggle:** Uses `SMAppService.mainApp.register()` and `.unregister()` from the `ServiceManagement` framework. This is a macOS 13+ API that lets apps register themselves to launch at login without needing a separate helper app or LaunchAgent. If registration fails (e.g., the user has denied it in System Settings), the toggle reverts. On appear, it reads the current status from `SMAppService.mainApp.status`.

### Services/NotificationManager.swift

A singleton (`static let shared`) that wraps Apple's `UNUserNotificationCenter` API. It is a subclass of `NSObject` and conforms to `UNUserNotificationCenterDelegate` so it can handle notification presentation while the app is in the foreground.

Three methods:
- `requestPermission()`: Asks the user for notification permission (alert + sound). Called once when the user first taps "Start". macOS remembers the user's choice, so subsequent calls are no-ops.
- `sendBreakNotification(soundEnabled:)`: Posts a notification with title "Time for a break!" and body "Look at something 20 feet away for 20 seconds." Uses a `nil` trigger, which means "deliver immediately."
- `sendBreakOverNotification(soundEnabled:)`: Posts a "Break over" notification.

The `userNotificationCenter(_:willPresent:)` delegate method returns `[.banner, .sound]`, which tells macOS to show the notification banner even when EyeSafe is the frontmost app. Without this delegate method, notifications would be silently suppressed when the app is active.

Each notification uses a fixed `identifier` string (`"break-start"` or `"break-over"`). If a previous notification with the same identifier is still in the notification center, the new one replaces it rather than stacking.

### Info.plist

Contains a single key:

```xml
<key>LSUIElement</key>
<true/>
```

`LSUIElement` (Launch Services UI Element) tells macOS that this app is an "agent" application. Effects:
- No icon appears in the Dock.
- The app does not appear in the Cmd+Tab application switcher.
- The app has no main menu bar (File, Edit, etc.).

This is the standard mechanism for menu bar-only apps. Without this key, the app would show a dock icon with no windows, which is confusing.

The build settings also set `GENERATE_INFOPLIST_FILE = YES` and `INFOPLIST_KEY_LSUIElement = YES`, which means Xcode generates a merged Info.plist at build time combining the manual file with build-setting-derived keys (like bundle identifier, version, etc.).

### EyeSafe.entitlements

```xml
<key>com.apple.security.app-sandbox</key>
<false/>
```

This disables App Sandbox. The app runs with the same permissions as any regular macOS application. App Sandbox is required for Mac App Store distribution but not for direct distribution. Since this app uses `SMAppService` (launch at login) and `NSWorkspace` notifications (sleep/wake), and doesn't do anything sensitive (no file access, no network, no camera), sandboxing is disabled for simplicity.

If you wanted to distribute via the Mac App Store, you would need to enable sandboxing and might need to adjust the `SMAppService` usage.

### Package.swift

The Swift Package Manager manifest. Declares:
- Minimum platform: macOS 13
- A single executable target named `EyeSafe`
- Asset catalog processing via `.process("Assets.xcassets")`

This file exists as an alternative build path. The primary build uses the `.xcodeproj`.

### EyeSafe.xcodeproj/project.pbxproj

The Xcode project file. This is a structured text file in the "old-style plist" format that Xcode uses internally. It defines:

- **PBXFileReference:** Every source file, asset catalog, plist, and entitlements file registered with the project.
- **PBXGroup:** The logical folder structure shown in Xcode's project navigator. Files are grouped under a "EyeSafe" group.
- **PBXBuildFile:** Associates file references with build phases (which files get compiled, which get copied as resources).
- **PBXSourcesBuildPhase:** Lists all `.swift` files to compile.
- **PBXResourcesBuildPhase:** Lists resources to bundle (the asset catalog).
- **PBXFrameworksBuildPhase:** Empty — no external frameworks.
- **PBXNativeTarget:** Defines the "EyeSafe" target as `com.apple.product-type.application` (a macOS app).
- **XCBuildConfiguration:** Two configurations (Debug and Release) at both project and target level. Key settings:
  - `MACOSX_DEPLOYMENT_TARGET = 13.0` — minimum macOS version.
  - `PRODUCT_BUNDLE_IDENTIFIER = com.eyesafe.app` — the app's unique identifier.
  - `CODE_SIGN_STYLE = Automatic` — Xcode signs with a local development identity.
  - `SWIFT_VERSION = 5.0` — Swift language version.

### Assets.xcassets

The asset catalog. Currently contains only an empty `AppIcon` icon set (no actual image files — the app uses the system default icon). To add a custom app icon, place `.png` files in the `AppIcon.appiconset` directory and update its `Contents.json` to reference them.

## System Interactions

### What macOS subsystems does EyeSafe touch?

| Subsystem | How | Impact |
|-----------|-----|--------|
| **Menu bar** | `MenuBarExtra` scene | Adds an icon to the system menu bar strip |
| **UserDefaults** | `@AppStorage` | Writes 4 keys to `~/Library/Preferences/com.eyesafe.app.plist`: `workMinutes`, `breakSeconds`, `soundEnabled`, `showTimerInMenuBar` |
| **Notification Center** | `UNUserNotificationCenter` | Requests notification permission; delivers banner notifications with optional sound |
| **Launch Services** | `LSUIElement` in Info.plist | Registers the app as a UI-less agent (no dock icon) |
| **Login Items** | `SMAppService.mainApp` | Registers/unregisters the app as a login item visible in System Settings > General > Login Items |
| **NSWorkspace notifications** | `willSleepNotification`, `didWakeNotification` | Observes system sleep/wake events to adjust the timer |
| **Run loop** | `Timer.publish(every: 1, on: .main, in: .common)` | Schedules a repeating timer on the main run loop |

### What files does EyeSafe create on disk?

- `~/Library/Preferences/com.eyesafe.app.plist` — UserDefaults storage (created automatically by the system the first time any `@AppStorage` value is written).
- Login item registration is stored in the system's login items database (managed by `SMAppService`, not directly by the app).

### What permissions does EyeSafe request?

Only one: **Notifications**. The permission prompt appears the first time the user starts the timer. The user can grant or deny it in System Settings > Notifications > EyeSafe. If denied, the timer still works — the user just won't see banner notifications.

### What does EyeSafe NOT do?

- No network access.
- No file system access beyond UserDefaults.
- No accessibility API usage.
- No screen recording or camera.
- No background processing or background app refresh.
- No data sent to any server.

## Apple Frameworks Used

| Framework | Import | Purpose |
|-----------|--------|---------|
| SwiftUI | `import SwiftUI` | All UI: `MenuBarExtra`, views, `@AppStorage`, `@StateObject` |
| Foundation | `import Foundation` | `Timer`, `TimeInterval`, `Date`, `NotificationCenter` |
| Combine | `import Combine` | `Timer.publish()`, `AnyCancellable`, `sink` |
| AppKit | `import AppKit` | `NSWorkspace` (sleep/wake), `NSApplication.shared.terminate()` |
| UserNotifications | `import UserNotifications` | `UNUserNotificationCenter`, `UNNotificationRequest` |
| ServiceManagement | `import ServiceManagement` | `SMAppService.mainApp` for launch-at-login |

All of these ship with macOS. There are zero third-party dependencies.

## Key Concepts for Non-Swift Developers

### @main
Marks the struct as the application entry point. Swift synthesizes a `main()` function that launches the SwiftUI app lifecycle.

### @StateObject vs @ObservedObject
`@StateObject` creates and owns an `ObservableObject` instance — it survives SwiftUI view re-creation. `@ObservedObject` references an existing instance owned by someone else. The app entry point uses `@StateObject`; the views use `@ObservedObject`.

### @Published
A property wrapper that makes a property observable. When its value changes, any SwiftUI view referencing it re-renders automatically. Only works inside `ObservableObject` classes.

### @AppStorage
A property wrapper that reads/writes a value to `UserDefaults`. It behaves like `@State` (triggers view updates) but the value persists across app launches.

### @Binding
A two-way reference to a value owned by a parent view. Changes in the child propagate back to the parent. Used in `SettingsView` so slider/toggle changes flow back to `MenuBarView`.

### MenuBarExtra
A SwiftUI `Scene` type (macOS 13+) that creates a menu bar item. It replaces the older `NSStatusItem` API. The `.window` style gives it a floating popover window.

### Combine Framework
Apple's reactive programming framework. `Timer.publish()` creates a publisher that emits values at a regular interval. `.autoconnect()` starts it immediately. `.sink` subscribes to the values and runs a closure for each emission. `AnyCancellable` is the subscription token — when it is set to `nil` or deallocated, the subscription stops.

### SF Symbols
Apple's built-in icon library. Referenced by name in `Image(systemName: "eye")`. The app uses `eye` for the normal state and `eye.trianglebadge.exclamationmark` for break time. These icons are available on all supported macOS versions.

## Deployment Target Considerations

The app targets macOS 13 (Ventura). Some APIs used in the initial implementation were macOS 14+ only:
- `onChange(of:) { }` (no-parameter closure) — macOS 14+. Fixed to use `onChange(of:) { _ in }` (macOS 13 compatible).
- `.symbolEffect(.pulse)` — macOS 14+. Removed.

If you raise the deployment target to macOS 14+, you can restore these for a slightly cleaner codebase and animated icon effects.
