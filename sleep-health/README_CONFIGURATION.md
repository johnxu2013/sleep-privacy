# Required Info.plist Entries and Entitlements

## Info.plist Required Keys

Add these keys to your Info.plist file:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>We need access to the microphone to monitor ambient sound levels during sleep tracking.</string>

<key>NSMotionUsageDescription</key>
<string>We use motion data to track your movement patterns during sleep.</string>

<key>NSHealthShareUsageDescription</key>
<string>We'd like to read your health data to provide better sleep insights.</string>

<key>NSHealthUpdateUsageDescription</key>
<string>We write your sleep data to Apple Health so you can track it alongside other health metrics.</string>

<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
    <string>processing</string>
</array>
```

## Required Entitlements

Create a file named `sleep-health.entitlements` with:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.healthkit</key>
    <true/>
    <key>com.apple.developer.healthkit.access</key>
    <array>
        <string>health-records</string>
    </array>
    <key>com.apple.developer.icloud-container-identifiers</key>
    <array>
        <string>iCloud.com.sleephealth</string>
    </array>
    <key>com.apple.developer.icloud-services</key>
    <array>
        <string>CloudKit</string>
    </array>
    <key>com.apple.developer.ubiquity-kvstore-identifier</key>
    <string>$(TeamIdentifierPrefix)com.sleephealth</string>
</dict>
</plist>
```

## Xcode Project Configuration

### 1. Capabilities to Enable:
- HealthKit
- iCloud (with CloudKit)
- Background Modes (Audio)

### 2. CloudKit Setup:
- Go to Signing & Capabilities
- Add iCloud capability
- Enable CloudKit
- Use container: `iCloud.com.sleephealth` (or your custom identifier)

### 3. HealthKit Setup:
- Add HealthKit capability
- Enable "Clinical Health Records" if needed
- The app will request specific permissions at runtime

## Build Settings

Ensure your deployment target is set to iOS 17.0 or later to use SwiftData and modern concurrency features.

## Testing on Device

Note: Many features (HealthKit, motion sensors, microphone) require testing on a physical device. The simulator has limited support for these features.
