# Building Memos iOS App - Complete Guide

This guide will walk you through building and deploying the Memos iOS app with full offline functionality using gomobile.

## Overview

Your iOS app architecture:
```
┌─────────────────────────────────────┐
│   iOS App (SwiftUI + WKWebView)     │
│                                     │
│   ServerManager.swift               │
│        ↓ (imports Mobile)           │
│   Mobile.xcframework                │
│        ↓ (gomobile binding)         │
│   mobile/server.go                  │
│        ↓                            │
│   Full Memos Go Backend             │
│   • HTTP/gRPC Server                │
│   • SQLite Database                 │
│   • All API Services                │
└─────────────────────────────────────┘
```

## Prerequisites

### Required Tools

1. **macOS** with Xcode 15 or later
   ```bash
   xcode-select --install
   ```

2. **Go 1.21 or later**
   ```bash
   go version
   ```

3. **gomobile** (for building iOS framework)
   ```bash
   go install golang.org/x/mobile/cmd/gomobile@latest
   gomobile init
   ```

4. **Node.js & pnpm** (for building the web frontend)
   ```bash
   node --version
   pnpm --version
   ```

### Verify Your Setup

Check that gomobile is installed:
```bash
which gomobile
# Should output: /Users/[your-username]/go/bin/gomobile
```

Ensure $GOPATH/bin is in your PATH:
```bash
echo $PATH | grep -q "go/bin" && echo "✓ Go bin in PATH" || echo "✗ Add $GOPATH/bin to PATH"
```

## Step 1: Build the Frontend

The iOS app embeds the React frontend inside the Go binary. Build it first:

```bash
cd web
pnpm install
pnpm release
cd ..
```

This builds the frontend and copies it to `server/router/frontend/dist/` where it's embedded into the Go binary.

## Step 2: Build the Go Mobile Framework

The gomobile framework compiles your entire Go backend into a native iOS framework.

### Quick Build (Recommended)

Use the provided build script:

```bash
chmod +x scripts/build-ios.sh
./scripts/build-ios.sh
```

This will:
- Clean previous builds
- Build `Mobile.xcframework` for both device and simulator
- Place it in `ios/Frameworks/`
- Takes 5-10 minutes on first build

### Manual Build (Alternative)

If you need to customize the build:

```bash
# Build for both iOS device and simulator
gomobile bind -target=ios -o ios/Frameworks/Mobile.xcframework ./mobile
```

**Build Flags Explained:**
- `-target=ios` - Builds for iOS (both arm64 device and x86_64/arm64 simulator)
- `-o ios/Frameworks/Mobile.xcframework` - Output location
- `./mobile` - Package to bind (exports functions from mobile/server.go)

### What Gets Built

The framework exposes these functions from `mobile/server.go`:

```go
// Start server and return URL
func NewServer(dataDir string, port int, addr string, mode string) (string, error)

// Stop the running server
func StopServer() error

// Check if server is running
func IsServerRunning() bool

// Get appropriate data directory for iOS
func GetDataDirectory(documentsDir string) string
```

These are callable from Swift as:
```swift
MobileNewServer(dataDir, port, addr, mode, &error)
MobileStopServer(&error)
MobileIsServerRunning()
MobileGetDataDirectory(documentsDir)
```

## Step 3: Configure Xcode Project

### Open Project

```bash
open ios/Memos.xcodeproj
```

### Verify Framework Integration

1. **Check Framework is Linked:**
   - Select "Memos" project in navigator
   - Select "Memos" target
   - Go to "Frameworks, Libraries, and Embedded Content"
   - Verify `Mobile.xcframework` is listed as "Embed & Sign"

2. **If Framework is Missing:**
   - Click "+" button
   - Click "Add Other..." → "Add Files..."
   - Navigate to `ios/Frameworks/Mobile.xcframework`
   - Select it and click "Add"
   - Set to "Embed & Sign"

### Configure Code Signing

1. Select "Memos" target
2. Go to "Signing & Capabilities"
3. **Team:** Select your Apple Developer account
4. **Bundle Identifier:** Change if needed (e.g., `com.yourname.memos`)
5. Xcode will auto-generate provisioning profile

### Verify Capabilities

The following capabilities are already configured in `Info.plist`:

✅ **Background Modes** (for offline functionality):
- Audio (silent audio keep-alive)
- Background fetch (periodic updates)
- Background processing (maintenance tasks)

✅ **Local Network Access**:
- Allows network sharing when enabled
- Required for other devices to connect

✅ **Background Task Identifiers**:
- `com.usememos.ios.refresh`
- `com.usememos.ios.processing`

## Step 4: Build and Run

### Choose Target Device

- **iOS Simulator** (for testing):
  - Select any iPhone simulator from scheme menu
  - Faster builds, no code signing needed
  - Full functionality except actual background execution

- **Physical Device** (for real testing):
  - Connect your iPhone/iPad via USB
  - Select it from scheme menu
  - Required to test background execution

### Build the App

Press `⌘R` or click the "Run" button.

**First Build:**
- May take 2-3 minutes (compiling Swift + linking framework)
- Subsequent builds are much faster (30-60 seconds)

### Monitor Logs

Open Xcode console (⌘⇧Y) to see:
```
App launched
Server started at: http://localhost:5230
Memos server started url=http://localhost:5230
```

## Step 5: First Launch Setup

1. **App launches** → Shows "Starting Memos Server..."
2. **Server starts** (3-5 seconds) → WebView loads
3. **Initial setup appears** → Create admin account
4. **You're in!** → Full Memos interface running locally

### Data Location

All data is stored in the iOS app's Documents directory:
```
~/Library/Developer/CoreSimulator/Devices/[UUID]/data/Containers/Data/Application/[UUID]/Documents/memos-data/
  ├── memos_prod.db      # SQLite database
  └── assets/            # Uploaded files
```

On physical device:
```
/var/mobile/Containers/Data/Application/[UUID]/Documents/memos-data/
```

## Step 6: Enable Full Offline Functionality

### Offline-First Architecture

The app is **already fully offline** by default:
- ✅ SQLite database stored locally
- ✅ No internet connection required
- ✅ All features work offline (create, edit, search memos)
- ✅ Attachments stored locally

### Network Access (Optional)

To access from other devices on your network:

1. Tap **Settings** (⚙️)
2. Enable **"Allow Network Access"**
3. Server restarts on `0.0.0.0:5230`
4. Access from other devices at `http://[your-ip]:5230`

**Security Note:** Only enable on trusted networks!

### Background Execution (Optional)

By default, the server stops when app is backgrounded (iOS standard). To keep running:

1. Tap **Settings** (⚙️)
2. Enable **"Keep Running in Background"**
3. Enable **Background App Refresh** in iOS Settings:
   - Settings → General → Background App Refresh
   - Enable globally and for Memos

**How it works:**
- Silent audio playback (keeps app active)
- Background tasks (periodic wake-ups)
- Auto-saves server state

**Limitations:**
- iOS restricts background time (see below)
- Uses ~5-10% battery per hour
- Best for active use, not 24/7 operation

## Understanding iOS Background Execution

### Timeline of Background Execution

When app is backgrounded with keep-alive enabled:

| Time Period | Expected Behavior | Reliability |
|-------------|------------------|-------------|
| 0-5 min | Server stays running | ✅ Very reliable |
| 5-15 min | Mostly running, occasional pauses | ⚠️ Good |
| 15-30 min | Periodic wake-ups only | ⚠️ Intermittent |
| 30+ min | Likely suspended | ❌ Limited |
| Hours | Only scheduled background refreshes | ❌ Very limited |

### When to Use Background Mode

✅ **Good use cases:**
- Actively accessing from another device (< 15 min)
- During a work session where you switch between apps
- Quick background periods while using other apps

❌ **Not recommended for:**
- Overnight operation
- All-day background server
- 24/7 self-hosting (use desktop/server instead)

### iOS Restrictions

Apple limits background execution to preserve battery:
- Background audio must actually play (we use silent audio)
- Background tasks have strict time limits (30 seconds)
- Background fetch is opportunistic (iOS decides when)
- VoIP/location alternatives violate App Store guidelines

## Troubleshooting

### Build Errors

**"gomobile: command not found"**
```bash
go install golang.org/x/mobile/cmd/gomobile@latest
gomobile init
export PATH=$PATH:$(go env GOPATH)/bin
```

**"Mobile.xcframework not found"**
```bash
./scripts/build-ios.sh
# Then rebuild in Xcode
```

**"Code signing requires a development team"**
- In Xcode: Select target → Signing & Capabilities → Select your team
- If no team: Sign up for free Apple Developer account at developer.apple.com

**"Cannot load framework"**
- Clean build folder: Xcode → Product → Clean Build Folder (⌘⇧K)
- Rebuild framework: `./scripts/build-ios.sh`
- Rebuild app: ⌘B

### Runtime Errors

**Server fails to start**

Check Xcode console for errors:
```
Failed to start server: failed to create data directory: permission denied
```

Solutions:
- Delete app and reinstall (resets permissions)
- Check iOS storage space (Settings → General → iPhone Storage)

**WebView shows blank page**
- Wait 5-10 seconds (server is starting)
- Check console for "Server started" message
- Restart app if still blank after 15 seconds

**Can't access from other devices**

1. Ensure "Allow Network Access" is **enabled**
2. Check both devices on same Wi-Fi network
3. Try IP address shown in Settings
4. Disable VPN on both devices
5. Check firewall on client device

**Background execution not working**

1. Verify Background App Refresh is enabled:
   ```
   Settings → General → Background App Refresh → ON
   Settings → Memos → Background App Refresh → ON
   ```

2. Check background status in app Settings (should show "Available")

3. Remember: iOS limits background time (see timeline above)

4. Look for these logs in Xcode console:
   ```
   App entering background
   Keep running in background is enabled
   Silent audio started
   Background refresh task started
   ```

### Development Tips

**Rebuilding After Go Changes**

1. Make changes to Go code (backend, mobile/server.go, etc.)
2. Rebuild framework: `./scripts/build-ios.sh`
3. Rebuild app in Xcode: ⌘B
4. No need to clean build unless framework structure changed

**Debugging Go Code**

All Go logs appear in Xcode console. Add logging:
```go
logger.Info("Debug message", "key", value)
```

For verbose logging, change mode in `ServerManager.swift:60`:
```swift
let url = MobileNewServer(dataDir, port, addr, "dev", &serverError)
```

**Testing Offline Functionality**

1. **Airplane Mode Test:**
   - Enable airplane mode on device
   - App should work perfectly (it's truly offline!)
   - All features available except network sharing

2. **Background Test:**
   - Enable keep-alive in Settings
   - Background app
   - Access from another device
   - Check Xcode console for background logs

3. **Data Persistence Test:**
   - Create some memos
   - Force quit app (swipe up in app switcher)
   - Relaunch app
   - All data should persist

## Deployment to TestFlight / App Store

### Prepare for Distribution

1. **Archive the App:**
   - Select "Any iOS Device" target
   - Xcode → Product → Archive
   - Wait for build to complete

2. **Upload to App Store Connect:**
   - Organizer window opens automatically
   - Select archive → Distribute App
   - App Store Connect → Upload
   - Wait for processing (10-30 minutes)

3. **TestFlight:**
   - Go to App Store Connect
   - Select your app → TestFlight
   - Add internal testers
   - Testers get email invite

### App Store Considerations

**App Review Requirements:**

1. **Background Modes Justification:**
   - Be prepared to explain background audio usage
   - Emphasize it's for self-hosted server functionality
   - Note: May face scrutiny, have clear explanation ready

2. **Local Network Permission:**
   - Usage description already set in Info.plist
   - Clearly explain why network access is needed

3. **Server Functionality:**
   - Ensure app works without network access (offline-first)
   - Don't use for cryptocurrency mining or similar
   - Clear privacy policy

**Potential Issues:**

⚠️ Background audio for non-audio app may be questioned
⚠️ Running server might be seen as unusual for iOS
⚠️ May need to justify use case clearly

Consider positioning as:
- Personal knowledge management tool
- Offline-first note-taking app
- Self-hosted alternative to cloud services

## Performance Optimization

### Reduce Framework Size

Current framework is ~50-80 MB. To reduce:

1. **Strip debug symbols:**
   ```bash
   gomobile bind -target=ios -ldflags="-s -w" -o ios/Frameworks/Mobile.xcframework ./mobile
   ```

2. **Build for specific architectures only:**
   ```bash
   # Device only (arm64)
   gomobile bind -target=ios/arm64 -o ios/Frameworks/Mobile.xcframework ./mobile
   ```

### Improve Startup Time

Currently takes 3-5 seconds to start server. To optimize:

1. Database is already SQLite (fastest for mobile)
2. Consider lazy-loading non-essential services
3. Pre-warm database connection pool

### Battery Optimization

Background mode uses significant battery. User options:

1. **Default (battery-friendly):**
   - Server stops when backgrounded
   - Restarts when app opens
   - Minimal battery impact

2. **Keep-alive (battery-intensive):**
   - Silent audio + background tasks
   - ~5-10% battery per hour
   - Only enable when needed

## Next Steps

### Enhancements to Consider

- [ ] **Share Extension:** Quick memo capture from anywhere
- [ ] **Widgets:** Recent memos on home screen
- [ ] **Siri Shortcuts:** Voice-activated memo creation
- [ ] **Watch App:** View and create memos from Apple Watch
- [ ] **Smart Background:** Auto-stop when no network clients
- [ ] **iCloud Sync:** Sync between multiple iOS devices
- [ ] **Backup/Export:** Easy database backup to Files app

### Architecture Improvements

- [ ] **Incremental Updates:** Only rebuild changed parts
- [ ] **Faster Startup:** Lazy initialization of services
- [ ] **Better Error Handling:** More descriptive error messages
- [ ] **Health Monitoring:** Track server health and restart if needed

## Resources

### Documentation

- **Gomobile Docs:** https://pkg.go.dev/golang.org/x/mobile/cmd/gomobile
- **iOS Background Execution:** https://developer.apple.com/documentation/backgroundtasks
- **Memos API Docs:** See `CLAUDE.md` for API architecture

### File Structure Reference

```
.
├── mobile/
│   └── server.go              # Gomobile bindings
├── ios/
│   ├── Memos/
│   │   ├── MemosApp.swift           # App entry point
│   │   ├── ServerManager.swift      # Go server interface
│   │   ├── ContentView.swift        # Main UI
│   │   ├── BackgroundTaskManager.swift
│   │   ├── KeepAliveManager.swift
│   │   └── Info.plist               # App configuration
│   ├── Frameworks/
│   │   └── Mobile.xcframework       # Built Go framework
│   └── Memos.xcodeproj/
├── scripts/
│   └── build-ios.sh           # Build automation
└── web/
    └── ...                     # React frontend
```

## Support

If you encounter issues:

1. Check Xcode console for error messages
2. Try clean build: `rm -rf ios/Frameworks/Mobile.xcframework && ./scripts/build-ios.sh`
3. Verify all prerequisites are installed
4. Check iOS version compatibility (iOS 15+)

For Memos-specific issues, see main project documentation.

## License

Same as main Memos project (MIT License).
