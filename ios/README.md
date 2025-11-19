# Memos iOS App

This directory contains the iOS app for Memos, allowing you to run your personal Memos instance directly on your iPhone or iPad.

## Features

- ✅ **Full Memos Backend**: Runs the complete Go backend server locally on your device
- ✅ **Native iOS App**: SwiftUI-based native app with WKWebView for the web UI
- ✅ **Network Access**: Optional network access to allow other devices to connect
- ✅ **Offline First**: All data stored locally on your device using SQLite
- ✅ **No Cloud Required**: Completely self-hosted on your iOS device

## Architecture

The iOS app uses `gomobile` to compile the Go backend as an iOS framework that runs natively on iOS:

```
┌─────────────────────────────────────┐
│         iOS App (SwiftUI)           │
│  ┌──────────────────────────────┐   │
│  │   WKWebView (React UI)       │   │
│  └──────────────────────────────┘   │
│  ┌──────────────────────────────┐   │
│  │   ServerManager (Swift)      │   │
│  └──────────────────────────────┘   │
│               ↓                     │
│  ┌──────────────────────────────┐   │
│  │  Mobile Framework (Go/gomobile)│ │
│  │  - HTTP/gRPC Server          │   │
│  │  - SQLite Database           │   │
│  │  - All Backend Logic         │   │
│  └──────────────────────────────┘   │
└─────────────────────────────────────┘
```

## Prerequisites

- macOS with Xcode 15 or later
- Go 1.21 or later
- `gomobile` (will be installed automatically by build script)

## Building

### 1. Build the Go Framework

From the project root:

```bash
chmod +x scripts/build-ios.sh
./scripts/build-ios.sh
```

This will:
- Install `gomobile` if not present
- Compile the Go backend to an iOS framework (`Mobile.xcframework`)
- Place the framework in `ios/Frameworks/`

The first build may take 5-10 minutes as it compiles the entire Go backend for iOS.

### 2. Open in Xcode

```bash
open ios/Memos.xcodeproj
```

### 3. Configure Code Signing

1. Select the "Memos" project in the navigator
2. Select the "Memos" target
3. Go to "Signing & Capabilities"
4. Select your development team
5. Xcode will automatically manage provisioning

### 4. Build and Run

- Select your iOS device or simulator from the scheme dropdown
- Press `Cmd+R` to build and run

## Usage

### First Launch

1. Launch the app on your device
2. The server will start automatically (may take a few seconds)
3. The web UI will load in the app
4. Complete the initial setup (create admin account)

### Network Access

To allow other devices on your network to access your Memos instance:

1. Tap the gear icon (⚙️) in the top-right
2. Toggle "Allow Network Access" ON
3. The server will restart and bind to `0.0.0.0`
4. Your network address will be displayed (e.g., `http://192.168.1.100:5230`)
5. Other devices can now access Memos at this address

**Security Note**: When network access is enabled, anyone on your local network can access your Memos instance. Ensure you're on a trusted network and set a strong password.

### Background Execution

By default, the server stops when the app is backgrounded (iOS standard behavior). To keep the server running in the background:

1. Tap the gear icon (⚙️) in Settings
2. Toggle "Keep Running in Background" ON
3. The app will use background execution techniques to maintain server uptime

**How it works**:
- Uses silent audio playback to keep app active
- Schedules background tasks for periodic wake-ups
- Automatically saves and restores server state

**Limitations**:
- iOS limits background execution time
- Server may pause during extended background periods (hours)
- Increases battery usage (~5-10% per hour)
- Background App Refresh must be enabled in iOS Settings

**When to use**:
- ✅ Active use: Keep enabled when actively accessing server from other devices
- ❌ Overnight: Disable to save battery during long inactive periods

See [BACKGROUND_EXECUTION.md](../BACKGROUND_EXECUTION.md) for detailed technical information.

### Data Storage

All data is stored in your iOS app's Documents directory:

```
Documents/
  └── memos-data/
      ├── memos_prod.db    # SQLite database
      └── assets/          # Uploaded files
```

This data persists between app launches and is backed up to iCloud (if enabled).

## Configuration

The iOS app uses the following default settings:

- **Port**: 5230 (same as default Memos)
- **Database**: SQLite (stored in app Documents)
- **Mode**: Production
- **Bind Address**:
  - `""` (localhost only) - default
  - `"0.0.0.0"` (all interfaces) - when network access enabled

## Troubleshooting

### Build Errors

**"gomobile: command not found"**
```bash
go install golang.org/x/mobile/cmd/gomobile@latest
gomobile init
```

**Framework not found in Xcode**

Make sure you've run `./scripts/build-ios.sh` first to build the Go framework.

**Code signing errors**

Ensure you've selected a valid development team in Xcode project settings.

### Runtime Issues

**Server fails to start**

Check the Xcode console for error messages. Common issues:
- Data directory permissions
- Port already in use (unlikely on iOS)
- Database migration errors

**Can't access from other devices**

1. Ensure "Allow Network Access" is enabled
2. Check that devices are on the same network
3. Try disabling VPN on either device
4. Check firewall settings (on the client device)

**WebView shows blank page**

- Wait a few seconds for the server to fully start
- Check Xcode console for server startup messages
- Try force-quitting and restarting the app

**Background execution not working**

1. Check Background App Refresh is enabled:
   - Settings > General > Background App Refresh
   - Enable globally and for Memos app
2. Verify "Keep Running in Background" is ON in app settings
3. Check background status indicator (should show "Available" not "Denied")
4. Look for these logs in Xcode console:
   - "Keep running in background is enabled"
   - "Silent audio started"
   - "Background refresh task started"
5. Remember: iOS limits background execution - server may pause after 15+ minutes

**Server stops in background even with keep-alive enabled**

This is expected iOS behavior. The keep-alive feature extends background runtime but doesn't guarantee 24/7 operation:
- First 5 minutes: Usually works well
- 5-15 minutes: May be intermittent
- 15+ minutes: Only periodic wake-ups
- Hours: Likely suspended

See [BACKGROUND_EXECUTION.md](../BACKGROUND_EXECUTION.md) for details on iOS limitations.

## Development

### Rebuilding the Framework

After making changes to the Go backend:

```bash
./scripts/build-ios.sh
```

Then rebuild the iOS app in Xcode (Cmd+B).

### Debugging

Go logs are printed to the Xcode console. You can view them in Xcode's debug console when running the app.

To enable more verbose logging, change the mode to "dev" in `ServerManager.swift`:

```swift
let url = MobileNewServer(dataDir, port, addr, "dev", &serverError)
```

### Project Structure

```
ios/
├── Memos/                              # iOS app source
│   ├── MemosApp.swift                 # App entry point + AppDelegate
│   ├── ContentView.swift              # Main UI with WebView
│   ├── ServerManager.swift            # Go server interface + lifecycle
│   ├── BackgroundTaskManager.swift    # Background tasks (fetch/processing)
│   ├── KeepAliveManager.swift         # Silent audio keep-alive
│   ├── BackgroundURLSessionManager.swift  # Background network transfers
│   ├── Assets.xcassets/               # App icons and assets
│   └── Info.plist                     # App configuration + background modes
├── Memos.xcodeproj/                   # Xcode project
├── Frameworks/                        # Generated frameworks (gitignored)
│   └── Mobile.xcframework            # Go backend framework
└── README.md                          # This file
```

## Limitations

- **Background Execution**: iOS limits background execution. Even with keep-alive enabled, the server may pause after 15+ minutes in background (see BACKGROUND_EXECUTION.md for details)
- **Network Access**: Requires devices to be on the same local network
- **Performance**: May be slower than desktop due to mobile hardware constraints
- **Database Size**: Limited by available iOS storage
- **Battery Life**: Background execution mode uses 5-10% battery per hour

## Future Enhancements

Possible improvements for the iOS app:

- [x] Background server execution (using background modes) ✅ **Implemented**
- [ ] Local network service discovery (Bonjour)
- [ ] Share extension for quick memo capture
- [ ] Siri shortcuts integration
- [ ] Widget support
- [ ] Watch app companion
- [ ] iCloud sync between devices
- [ ] Export/import database
- [ ] Smart suspension (stop when no clients connected)
- [ ] Battery-aware modes

## License

Same as the main Memos project (MIT License).
