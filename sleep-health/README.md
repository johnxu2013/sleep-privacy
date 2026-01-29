# Sleep Health Tracker

A comprehensive iOS sleep tracking app that monitors movement and ambient sound to help you wake up refreshed with smart alarm functionality.

## Features

### 🌙 Smart Sleep Tracking
- **Movement Monitoring**: Uses device accelerometer to track movement intensity throughout the night
- **Ambient Sound Detection**: Monitors sound levels to understand your sleep environment
- **Sleep Stage Estimation**: Analyzes data to estimate sleep stages (Deep, REM, Light, Awake)
- **Real-time Metrics**: View current movement and sound levels while tracking

### ⏰ Smart Alarm
- **Intelligent Wake-up**: Triggers alarm during light sleep within your specified window
- **Customizable Window**: Set your preferred smart alarm window (15-60 minutes)
- **Gentle Notifications**: Progressive alarm volume to wake you naturally
- **Optimal Timing**: Wakes you at the best time based on your sleep cycle

### 📊 Comprehensive Analytics
- **Morning Summary**: Easy-to-read summary with key metrics after each session
- **Sleep Cycle Graphs**: Visual representation of sleep stages throughout the night
- **Movement & Sound Charts**: Detailed charts showing activity patterns
- **Quality Scoring**: Overall sleep quality assessment based on multiple factors

### 📈 Long-term Trends
- **Historical Analysis**: View trends over 7, 14, or 30 days
- **Average Metrics**: Track average sleep duration, efficiency, and quality
- **Stage Distribution**: See how your sleep stages distribute over time
- **Awakening Patterns**: Identify trends in nighttime awakenings

### 🔄 Health Integration
- **Apple Health Sync**: Automatically writes sleep data to HealthKit
- **Sleep Analysis**: Compatible with Apple's sleep analysis categories
- **Health Dashboard**: View sleep alongside other health metrics

### ☁️ Cloud Sync
- **iCloud Backup**: All sleep sessions synced to your iCloud account
- **Multi-device**: Access your sleep history across all your devices
- **Automatic Sync**: Background syncing keeps data up-to-date
- **Privacy-first**: All data stays in your private iCloud container

## Architecture

### MVC Pattern
The app follows a clean Model-View-Controller architecture:

- **Models**: SwiftData models for sleep sessions, samples, and stages
- **Views**: SwiftUI views for all user interfaces
- **Controllers**: `SleepTrackingController` coordinates all functionality

### Services Layer
Specialized services handle specific functionality:

- `SleepMonitoringService`: Manages sensor data collection
- `SleepAnalysisService`: Analyzes data and estimates sleep stages
- `HealthKitService`: Handles Apple Health integration
- `SmartAlarmService`: Manages alarm functionality and notifications
- `CloudSyncService`: Syncs data to iCloud using CloudKit

### Data Persistence
- **SwiftData**: Local storage with automatic CloudKit sync
- **HealthKit**: Sleep data written to Apple Health
- **CloudKit**: Private database for cross-device sync

## Requirements

- iOS 17.0 or later
- Xcode 15.0 or later
- Swift 5.9 or later
- Physical device recommended (simulator has limited sensor support)

## Setup Instructions

### 1. Clone the Repository
```bash
git clone <repository-url>
cd sleep-health
```

### 2. Configure Xcode Project

#### Enable Required Capabilities:
1. Open the project in Xcode
2. Select your target
3. Go to "Signing & Capabilities"
4. Add the following capabilities:
   - HealthKit
   - iCloud (with CloudKit)
   - Background Modes (Audio)

#### Configure Info.plist:
See `README_CONFIGURATION.md` for required Info.plist entries.

#### Add Entitlements:
Create `sleep-health.entitlements` with required permissions (see configuration guide).

### 3. CloudKit Setup
1. Sign in with your Apple Developer account
2. In Capabilities → iCloud, click the "CloudKit Dashboard" button
3. Create a container named `iCloud.com.sleephealth` (or use your custom identifier)
4. Update the identifier in `sleep_healthApp.swift` if you use a different name

### 4. Build and Run
1. Select a physical iOS device (recommended)
2. Build and run (Cmd+R)
3. Grant permissions when prompted:
   - Microphone access
   - Motion & Fitness
   - Health access
   - Notifications

## Usage

### Starting Sleep Tracking

1. **Simple Tracking**:
   - Open the "Tonight" tab
   - Tap "Start Sleep Tracking"
   - Place your device on the nightstand

2. **With Smart Alarm**:
   - Tap "Set Smart Alarm"
   - Choose your target wake time
   - Adjust the smart alarm window
   - Tap "Start Sleep Tracking"
   - The alarm will trigger during light sleep within your window

### Viewing Results

1. **Morning Summary**:
   - Stop tracking when you wake up
   - View immediate summary with key metrics
   - See sleep stage breakdown and charts

2. **History**:
   - Browse all past sleep sessions
   - Tap any session for detailed analysis
   - View movement and sound patterns

3. **Trends**:
   - Switch between 7, 14, or 30-day views
   - See average metrics and trends
   - Analyze long-term sleep patterns

## Key Metrics Explained

### Sleep Efficiency
Percentage of time in bed actually spent sleeping. 85%+ is considered excellent.

### Sleep Stages
- **Deep Sleep**: Most restorative stage, important for physical recovery
- **REM Sleep**: Important for cognitive function and memory
- **Light Sleep**: Transitional stage, easier to wake from
- **Awake**: Time spent awake during the night

### Restlessness Score
0-100 scale measuring movement intensity. Lower scores indicate more restful sleep.

### Sleep Quality Score
Overall assessment combining efficiency, deep sleep, awakenings, and restlessness.

## Technical Details

### Sensor Sampling
- **Movement**: Accelerometer sampled at 10 Hz, aggregated every 30 seconds
- **Sound**: Microphone sampled continuously, averaged every 30 seconds
- **Battery Optimization**: Efficient sampling reduces battery impact

### Sleep Stage Algorithm
The app uses a heuristic-based approach combining:
- Movement intensity patterns
- Sound level variations
- Time-based analysis windows (5 minutes)
- Transition smoothing

**Note**: This is a simplified estimation. For clinical-grade sleep analysis, consult a healthcare provider.

### Smart Alarm Algorithm
1. Monitors sleep stages during the alarm window
2. Looks for light sleep or awake periods
3. Triggers alarm at the first optimal opportunity
4. Falls back to target time if no optimal window found

## Privacy & Data

- All sensor data processed locally on device
- No data sent to external servers
- HealthKit data governed by Apple's privacy policies
- iCloud sync uses your private container
- You can export or delete data anytime

## Limitations

- Sleep stage estimation is approximate, not clinical-grade
- Requires device to be placed near you during sleep
- Background monitoring may impact battery life
- Single-sensor tracking less accurate than multi-sensor devices

## Future Enhancements

Potential improvements for future versions:
- Machine learning models for better stage detection
- Apple Watch integration for heart rate monitoring
- Sleep environment recommendations
- Sleep goal setting and tracking
- Bedtime routines and reminders
- Integration with sleep research studies

## Troubleshooting

### Alarm Not Triggering
- Ensure notifications are enabled
- Check that device is not in Do Not Disturb mode
- Verify alarm window settings

### Data Not Syncing to Health
- Check HealthKit permissions in Settings
- Ensure app has write permissions for sleep data
- Try re-authorizing in Settings view

### iCloud Sync Issues
- Verify iCloud is enabled in device Settings
- Check internet connection
- Ensure sufficient iCloud storage

### High Battery Usage
- Reduce sampling frequency if needed
- Ensure device is plugged in overnight
- Check for other background apps

## Contributing

This is a personal project, but suggestions are welcome! Please open an issue to discuss potential changes.

## License

[Your License Here]

## Acknowledgments

- Built with SwiftUI and SwiftData
- Uses Apple's HealthKit and CloudKit frameworks
- Inspired by sleep research and polysomnography techniques

---

**Disclaimer**: This app is for informational purposes only and is not intended to diagnose or treat any medical conditions. Consult with a healthcare provider for sleep disorders or medical advice.
