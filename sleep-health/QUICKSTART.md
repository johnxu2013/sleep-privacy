# Quick Start Guide

## Project Structure

```
sleep-health/
├── Models/
│   └── SleepSession.swift          # SwiftData models for sleep tracking
├── Services/
│   ├── SleepMonitoringService.swift    # Sensor data collection
│   ├── SleepAnalysisService.swift      # Sleep stage estimation
│   ├── HealthKitService.swift          # Apple Health integration
│   ├── SmartAlarmService.swift         # Smart alarm functionality
│   └── CloudSyncService.swift          # iCloud sync
├── Controllers/
│   └── SleepTrackingController.swift   # Main MVC controller
├── Views/
│   ├── TonightView.swift              # Main tracking interface
│   ├── HistoryView.swift              # Past sessions viewer
│   ├── TrendsView.swift               # Long-term analytics
│   └── SettingsView.swift             # App settings
├── ContentView.swift                   # Root tab view
├── sleep_healthApp.swift              # App entry point
├── Tests/
│   └── SleepTrackingTests.swift       # Unit tests
└── README.md                          # Full documentation
```

## First-Time Setup Checklist

### 1. Xcode Configuration
- [ ] Open project in Xcode 15+
- [ ] Set deployment target to iOS 17.0+
- [ ] Add your development team in Signing & Capabilities

### 2. Enable Capabilities
- [ ] HealthKit
- [ ] iCloud with CloudKit
- [ ] Background Modes (Audio)

### 3. Configure Info.plist
Add these permission descriptions:
```
NSMicrophoneUsageDescription
NSMotionUsageDescription  
NSHealthShareUsageDescription
NSHealthUpdateUsageDescription
```

### 4. Create Entitlements File
Create `sleep-health.entitlements` with:
- HealthKit access
- CloudKit container
- iCloud services

### 5. CloudKit Setup
- [ ] Sign in to iCloud in Xcode
- [ ] Create CloudKit container: `iCloud.com.sleephealth`
- [ ] Update identifier in code if using different name

### 6. Build and Test
- [ ] Connect physical iOS device (required for sensors)
- [ ] Build and run (⌘R)
- [ ] Grant all permissions when prompted

## How It Works

### Data Flow

1. **Tracking Start**:
   - User taps "Start Sleep Tracking"
   - `SleepTrackingController` creates new `SleepSession`
   - `SleepMonitoringService` begins sensor monitoring
   - Movement and sound samples collected every 30 seconds

2. **During Sleep**:
   - Real-time metrics displayed on TonightView
   - Samples saved to SwiftData periodically
   - Smart alarm monitors for optimal wake window

3. **Wake Up**:
   - Smart alarm triggers during light sleep (if enabled)
   - Or user manually stops tracking
   - `SleepAnalysisService` processes all samples

4. **Post-Processing**:
   - Sleep stages estimated from sensor data
   - Metrics calculated (efficiency, quality, etc.)
   - Data synced to HealthKit
   - Session uploaded to iCloud

5. **Viewing Results**:
   - Morning summary shows key metrics
   - History tab lists all sessions
   - Trends tab shows long-term patterns

## Key Classes

### SleepTrackingController
Main coordinator that:
- Manages sleep tracking lifecycle
- Coordinates between services
- Handles data persistence
- Triggers sync operations

### SleepMonitoringService
Handles sensor data:
- Accelerometer for movement
- Microphone for sound levels
- Samples at configurable intervals
- Callbacks for real-time data

### SleepAnalysisService
Analyzes sleep data:
- Estimates sleep stages
- Calculates quality metrics
- Finds optimal wake times
- Generates insights

### HealthKitService
Apple Health integration:
- Requests authorization
- Writes sleep analysis data
- Maps stages to HealthKit categories
- Handles errors gracefully

### SmartAlarmService
Alarm functionality:
- Schedules notifications
- Monitors for light sleep
- Triggers wake-up alarm
- Handles audio playback

### CloudSyncService
iCloud synchronization:
- Checks account status
- Syncs sessions to CloudKit
- Batch uploads for efficiency
- Handles conflicts

## Testing

Run tests with ⌘U or:
```bash
xcodebuild test -scheme sleep-health -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

Tests cover:
- Model creation and relationships
- Sleep stage estimation
- Metrics calculation
- Smart alarm logic

## Common Customizations

### Change Sampling Frequency
In `SleepMonitoringService.swift`:
```swift
private let sampleInterval: TimeInterval = 30 // seconds
```

### Adjust Smart Alarm Window
In `TonightView.swift`:
```swift
@State private var smartAlarmWindow: Double = 30 // minutes
```

### Modify Sleep Stage Algorithm
In `SleepAnalysisService.swift`, update `classifySleepStage()` method with your logic.

### Change CloudKit Container
In `sleep_healthApp.swift`:
```swift
cloudKitDatabase: .private("iCloud.YOUR_IDENTIFIER")
```

## Deployment

### App Store Submission
1. Add privacy policy URL
2. Explain HealthKit usage in App Review notes
3. Provide demo account if needed
4. Test on multiple devices
5. Ensure background modes work correctly

### Beta Testing (TestFlight)
1. Archive app (Product → Archive)
2. Upload to App Store Connect
3. Add testers
4. Collect feedback on:
   - Battery usage
   - Alarm reliability
   - Data accuracy
   - UI/UX

## Performance Tips

### Battery Optimization
- Keep device plugged in overnight
- Reduce sampling frequency if needed
- Use airplane mode if data sync not needed immediately

### Accuracy Improvements
- Place device on stable surface (nightstand)
- Keep microphone unobstructed
- Minimize interference from fans/AC

### Storage Management
- Old sessions auto-archived to iCloud
- Local storage uses SwiftData efficiently
- Can manually delete old sessions

## Troubleshooting

### "HealthKit not available"
- Check device supports HealthKit
- Verify capability is enabled
- Request authorization at runtime

### "CloudKit error"
- Ensure signed into iCloud
- Check internet connection
- Verify container identifier matches

### Sensors not working
- Test on physical device (not simulator)
- Check permissions granted
- Restart app if needed

### Alarm not triggering
- Disable Do Not Disturb
- Check notification permissions
- Verify alarm window settings

## Next Steps

1. **Test basic tracking**: Start/stop a session
2. **Review data**: Check History tab for session details
3. **Try smart alarm**: Set wake time and test overnight
4. **View trends**: Track for a week and check Trends tab
5. **Customize**: Adjust algorithms and UI to your preferences

## Support & Resources

- Apple Documentation: HealthKit, CloudKit, SwiftData
- WWDC Videos: Sleep tracking, background modes
- Community: Stack Overflow, Apple Developer Forums

---

**Ready to start?** Build the project and grant permissions when prompted. Your first sleep tracking session awaits! 🌙
