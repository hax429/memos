# iOS Background Execution Guide

This document explains how background execution works in the Memos iOS app and the techniques used to keep the server running when the app is backgrounded.

## Overview

iOS normally suspends apps shortly after they enter the background to save battery and system resources. The Memos iOS app implements multiple strategies to maintain server uptime even when backgrounded:

1. **Background App Refresh** - Periodic wake-ups to process tasks
2. **Background Processing** - Longer running tasks
3. **Silent Audio Playback** - Keep-alive using audio session (optional)
4. **Background URL Sessions** - Network transfers continue in background
5. **State Persistence** - Save/restore server state across app lifecycle

## Background Modes

The app uses three iOS background modes (configured in `Info.plist`):

### 1. Audio Background Mode

```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
    ...
</array>
```

**Purpose**: Plays silent audio to keep the app active in background

**How it works**:
- When "Keep Running in Background" is enabled, the app plays a looped silent audio file
- Audio session is configured with `.playback` category and `.mixWithOthers` option
- Volume is set very low (0.01) but not zero to avoid system optimization
- This technique is legitimate when the user explicitly enables it for server functionality

**Limitations**:
- App will appear in Control Center as playing audio
- Uses more battery than normal background suspension
- May be paused if user starts other audio playback

**Implementation**: `KeepAliveManager.swift`

### 2. Background Fetch

```xml
<array>
    <string>fetch</string>
</array>
```

**Purpose**: Periodic wake-ups to refresh content

**How it works**:
- App registers a `BGAppRefreshTask` with identifier `com.usememos.ios.refresh`
- iOS wakes the app approximately every 15 minutes (not guaranteed)
- App gets ~30 seconds to complete refresh tasks
- Ensures server stays initialized even if audio is interrupted

**Limitations**:
- Timing is controlled by iOS and varies based on usage patterns
- Only gets 30 seconds of execution time
- Disabled if user turns off Background App Refresh in Settings

**Implementation**: `BackgroundTaskManager.swift`

### 3. Background Processing

```xml
<array>
    <string>processing</string>
</array>
```

**Purpose**: Longer-running background tasks

**How it works**:
- App registers a `BGProcessingTask` with identifier `com.usememos.ios.processing`
- Scheduled to run approximately every 30 minutes
- Can run for several minutes (exact duration determined by iOS)
- Used for database maintenance, log cleanup, etc.

**Limitations**:
- Only runs when device is idle and charging (by default)
- Can be configured to run on battery with `requiresExternalPower = false`
- iOS may defer or cancel tasks based on system state

**Implementation**: `BackgroundTaskManager.swift`

## User Experience

### Settings UI

Users can control background execution from Settings:

**Toggle**: "Keep Running in Background"
- **OFF** (default): Server stops when app is backgrounded
- **ON**: Server attempts to stay running using background techniques

**Status Indicators**:
- **Background Status**: Shows if Background App Refresh is available/denied/restricted
- **Background Time**: Real-time countdown showing remaining background execution time
- **Last Refresh**: Timestamp of last background task execution

### Behavior by Mode

#### Default Mode (Keep Running OFF)

```
App Foreground → Server Running
App Background → Server Stops
App Foreground → Server Restarts Automatically
```

- Lowest battery usage
- Server not accessible when app backgrounded
- Best for casual use

#### Background Mode (Keep Running ON)

```
App Foreground → Server Running + Silent Audio
App Background → Server Running (with limitations)
App Foreground → Server Still Running
```

- Higher battery usage
- Server accessible most of the time in background
- Best for active server use

## iOS Limitations & Reality

Despite our best efforts, iOS has hard limits on background execution:

### What iOS Allows

✅ **Short bursts**: 30 seconds every 15+ minutes via Background App Refresh
✅ **Audio playback**: Continuous if actively playing audio (our silent audio trick)
✅ **Network transfers**: Background URL sessions can continue
✅ **Location updates**: If app is a navigation app (not applicable)
✅ **VoIP**: If app provides VoIP services (not applicable)

### What iOS Does NOT Allow

❌ **Indefinite background execution**: No way to run HTTP server 24/7 in background
❌ **Guaranteed wake-ups**: Background refresh is "best effort", not guaranteed
❌ **Full CPU access**: Background tasks are heavily throttled
❌ **Long processing**: Even BGProcessingTask gets killed eventually

### Expected Behavior

**Realistic expectations**:

1. **First 3-5 minutes**: Server runs normally via silent audio
2. **5-15 minutes**: Audio may be paused, background tasks take over
3. **15+ minutes**: Only periodic wake-ups every 15-30 minutes
4. **Hours later**: App likely fully suspended, server stopped

**Network requests**:
- While audio is active: Requests work normally
- During background tasks: 30-second window to respond
- When suspended: Requests time out

## Implementation Details

### Architecture

```
┌─────────────────────────────────────────────┐
│           ServerManager                     │
│  - Manages server lifecycle                 │
│  - Observes app state changes               │
│  - Persists/restores state                  │
└─────────┬───────────────────────────────────┘
          │
          ├─────────────────┬──────────────────┐
          │                 │                  │
┌─────────▼───────┐ ┌───────▼────────┐ ┌──────▼─────────┐
│KeepAliveManager │ │BackgroundTask  │ │BackgroundURL   │
│                 │ │Manager         │ │SessionManager  │
│- Silent audio   │ │- BGAppRefresh  │ │- Transfers     │
│- Background task│ │- BGProcessing  │ │- Downloads     │
└─────────────────┘ └────────────────┘ └────────────────┘
```

### App Lifecycle Handling

**ServerManager** observes these notifications:

1. **UIApplication.didEnterBackgroundNotification**
   - If keep-alive enabled: Start background tasks + silent audio
   - If disabled: Stop server
   - Always: Save server state

2. **UIApplication.willEnterForegroundNotification**
   - Restore server if it was running before
   - Stop background tasks (foreground doesn't need them)

3. **UIApplication.willTerminateNotification**
   - Stop server gracefully
   - Stop all background tasks
   - Clean up resources

### State Persistence

Server state is saved to `UserDefaults`:

```swift
{
    "isRunning": true,
    "allowNetworkAccess": false,
    "keepRunningInBackground": true
}
```

On foreground, if `isRunning` was true, server restarts automatically.

### Silent Audio Implementation

`KeepAliveManager` creates a 1-second silent audio buffer:

```swift
// Create 1-second silent PCM buffer
let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)
let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 44100)
buffer.frameLength = 44100
// Fill with zeros (silence)
memset(buffer.floatChannelData[0], 0, ...)

// Play in loop
audioPlayer = AVAudioPlayer(contentsOf: silenceURL)
audioPlayer.numberOfLoops = -1  // Infinite loop
audioPlayer.volume = 0.01       // Very quiet
audioPlayer.play()
```

### Background Task Scheduling

`BackgroundTaskManager` registers tasks on app launch:

```swift
// Register refresh task (every ~15 min)
BGTaskScheduler.shared.register(
    forTaskWithIdentifier: "com.usememos.ios.refresh",
    using: nil
) { task in
    self.handleBackgroundRefresh(task: task as! BGAppRefreshTask)
}

// Schedule next execution
let request = BGAppRefreshTaskRequest(identifier: "com.usememos.ios.refresh")
request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
BGTaskScheduler.shared.submit(request)
```

## Testing Background Execution

### Testing in Simulator

1. **Enable Background App Refresh**:
   - Settings > Developer > Background Fetch > Choose App
   - Set to "On"

2. **Trigger Background Tasks**:
   ```bash
   # In Terminal, while app is running
   xcrun simctl spawn booted process com.apple.BTServer e -l objc -- \
     (void)[[BGTaskScheduler sharedScheduler] \
     _simulateLaunchForTaskWithIdentifier:@"com.usememos.ios.refresh"]
   ```

3. **Monitor Console**:
   - Watch for "Background refresh task started" logs
   - Check background time remaining

### Testing on Device

1. **Build and run on physical device**
2. **Enable Background App Refresh**:
   - Settings > General > Background App Refresh > Enable for Memos
3. **Enable in app**:
   - Open Memos > Settings > Toggle "Keep Running in Background"
4. **Background app**:
   - Press home button (or swipe up)
   - Wait 5-10 minutes
5. **Test accessibility**:
   - From another device on same network
   - Try accessing server URL
   - May work for first few minutes, then become intermittent

### Debug Output

Enable verbose logging in `ServerManager`:

```swift
// Change mode to "dev" for more logs
let url = MobileNewServer(dataDir, port, addr, "dev", &serverError)
```

Look for these log messages:
- "App entering background"
- "Keep running in background is enabled"
- "Background refresh task started"
- "Silent audio started"
- "Background time remaining: XX:XX"

## Battery Impact

Background execution significantly impacts battery life:

**Default Mode** (keep-alive OFF):
- Minimal battery usage
- App fully suspended in background
- Same as any normal app

**Background Mode** (keep-alive ON):
- **Silent Audio**: ~1-5% battery per hour
- **Background Tasks**: Negligible (only 30s every 15min)
- **Network Activity**: Depends on traffic
- **Total**: ~5-10% per hour of background runtime

**Recommendations**:
- Only enable when actively using server features
- Disable before overnight/long periods
- Monitor battery in Settings > Battery

## App Store Considerations

### Allowed Use Cases

The audio background mode is acceptable if:
- User explicitly enables it (not default)
- Described clearly in app description
- Necessary for core functionality
- Can be toggled off

### App Store Description

Include in App Store description:

> **Background Server Mode**: Enable "Keep Running in Background" to maintain server access when the app is not in foreground. This feature uses audio playback to keep the app active and will increase battery usage. Background execution is subject to iOS limitations and the server may pause during extended background periods.

### Rejection Risk

**Low Risk** - because:
- Feature is optional (off by default)
- Clearly labeled and documented
- Serves legitimate use case (local server)
- User has full control

**If rejected**:
- Remove silent audio technique
- Keep only BGTaskScheduler approaches
- Update description to reflect limitations

## Performance Optimization

### Reducing Battery Drain

1. **Stop server when not needed**:
   ```swift
   if !serverManager.hasActiveConnections {
       serverManager.stopServer()
   }
   ```

2. **Reduce background refresh frequency**:
   ```swift
   request.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60) // 30 min instead of 15
   ```

3. **Pause non-essential background work**:
   ```swift
   if UIApplication.shared.applicationState == .background {
       // Skip heavy operations
   }
   ```

### Monitoring Resource Usage

```swift
// Check background time remaining
let timeRemaining = UIApplication.shared.backgroundTimeRemaining
if timeRemaining < 10 {
    // Wrap up quickly
}

// Monitor memory
let memoryUsage = ProcessInfo.processInfo.physicalMemory
```

## Future Improvements

Potential enhancements:

- [ ] Adaptive strategy based on usage patterns
- [ ] Bonjour/mDNS for automatic discovery
- [ ] Push notifications for server events
- [ ] Smart suspension (stop server when no clients connected)
- [ ] Battery-aware modes (disable on low battery)
- [ ] Foreground service indicator (iOS 16+)

## References

- [Apple: Background Execution](https://developer.apple.com/documentation/backgroundtasks)
- [Apple: Audio Session Programming Guide](https://developer.apple.com/library/archive/documentation/Audio/Conceptual/AudioSessionProgrammingGuide/)
- [BGTaskScheduler Documentation](https://developer.apple.com/documentation/backgroundtasks/bgtaskscheduler)
- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/#performance)

## Summary

The Memos iOS app uses multiple legitimate iOS background execution techniques to maintain server uptime:

✅ **Works well for**: Short background periods (< 15 minutes)
⚠️ **Works partially for**: Medium background periods (15-60 minutes)
❌ **Limited for**: Extended background periods (hours)

Users should understand that iOS is designed to suspend background apps, and true 24/7 background server operation is not supported by the platform. The implementation provides the best possible experience within iOS constraints.
