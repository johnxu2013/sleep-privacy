# Fatal Error Fix: Range Requires lowerBound <= upperBound

## Problem Summary

The app crashed with:
```
Swift/ClosedRange.swift:409: Fatal error: Range requires lowerBound <= upperBound
```

This occurred when creating a smart alarm window with invalid date ranges.

## Root Causes

### 1. **Date Picker Only Selected Time, Not Date**
The `AlarmSettingsSheet` used:
```swift
DatePicker("Target Wake Time", selection: $selectedTime, displayedComponents: .hourAndMinute)
```

This meant if you selected "8:00 AM" at 10:00 AM, the target time would be in the **past**, creating an invalid range.

### 2. **No Validation of Smart Alarm Window**
When calculating the window:
```swift
let windowStart = targetWake.addingTimeInterval(-smartAlarmWindow)
return windowStart...targetWake  // Could be invalid if windowStart >= targetWake
```

If `smartAlarmWindow` was 0, negative, or too large, this would crash.

### 3. **Simulator Limitations**
The logs showed:
- `⚠️ iCloud not available` - iCloud doesn't work in Simulator
- `⚠️ Accelerometer not available` - Motion tracking unavailable
- `CKAccountStatusNoAccount` - No iCloud account in Simulator

These issues made testing harder but didn't cause the crash.

## Fixes Applied

### Fix 1: Updated `SleepSession.swift` - Smart Alarm Window Validation

**Before:**
```swift
var smartAlarmWindowRange: ClosedRange<Date>? {
    guard let targetWake = targetWakeTime else { return nil }
    let windowStart = targetWake.addingTimeInterval(-smartAlarmWindow)
    return windowStart...targetWake  // CRASH if windowStart >= targetWake
}
```

**After:**
```swift
var smartAlarmWindowRange: ClosedRange<Date>? {
    guard let targetWake = targetWakeTime else { return nil }
    
    // Ensure smartAlarmWindow is positive and reasonable
    let window = max(300, min(smartAlarmWindow, 3600)) // Between 5 min and 1 hour
    let windowStart = targetWake.addingTimeInterval(-window)
    
    // Ensure windowStart is before targetWake
    guard windowStart < targetWake else { return nil }
    
    return windowStart...targetWake
}
```

### Fix 2: Updated `TonightView.swift` - Date Picker with Date and Time

**Before:**
```swift
DatePicker(
    "Target Wake Time",
    selection: $selectedTime,
    displayedComponents: .hourAndMinute  // Only time, date could be today (past)
)
```

**After:**
```swift
DatePicker(
    "Target Wake Time",
    selection: $selectedTime,
    in: Date()...,  // Only allow future times
    displayedComponents: [.date, .hourAndMinute]  // Include date
)
.onAppear {
    // Ensure initial time is in the future (tomorrow morning)
    if selectedTime <= Date() {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
        var components = calendar.dateComponents([.year, .month, .day], from: tomorrow)
        components.hour = 7
        components.minute = 0
        selectedTime = calendar.date(from: components) ?? tomorrow
    }
}
```

Added button validation:
```swift
.disabled(selectedTime <= Date()) // Disable if time is in the past
```

### Fix 3: Updated `SleepTrackingController.swift` - Input Validation

Added validation before creating session:
```swift
func startSleepTracking(targetWakeTime: Date?, smartAlarmWindow: TimeInterval = 1800) async {
    guard !isTracking else { return }
    
    // Validate target wake time is in the future
    if let targetWake = targetWakeTime, targetWake <= Date() {
        errorMessage = "Target wake time must be in the future"
        return
    }
    
    // Ensure alarm window is reasonable (5 minutes to 1 hour)
    let validatedWindow = max(300, min(smartAlarmWindow, 3600))
    
    // Create new session with validated values
    let session = SleepSession(
        startTime: Date(),
        targetWakeTime: targetWakeTime,
        smartAlarmWindow: validatedWindow
    )
    // ...
}
```

### Fix 4: Updated `SmartAlarmService.swift` - Scheduling Validation

Added comprehensive validation:
```swift
func scheduleSmartAlarm(
    targetWakeTime: Date,
    windowDuration: TimeInterval,
    identifier: String = UUID().uuidString
) async throws {
    // Validate inputs
    guard targetWakeTime > Date() else {
        throw AlarmError.invalidWakeTime
    }
    
    guard windowDuration > 0 && windowDuration <= 3600 else {
        throw AlarmError.invalidWindow
    }
    
    let windowStart = targetWakeTime.addingTimeInterval(-windowDuration)
    
    // Ensure window start is in the future
    guard windowStart > Date() else {
        throw AlarmError.windowStartInPast
    }
    
    // ... rest of scheduling
}
```

Added error types:
```swift
enum AlarmError: LocalizedError {
    case invalidWakeTime
    case invalidWindow
    case windowStartInPast
    
    var errorDescription: String? {
        switch self {
        case .invalidWakeTime:
            return "Wake time must be in the future"
        case .invalidWindow:
            return "Alarm window must be between 0 and 60 minutes"
        case .windowStartInPast:
            return "Alarm window starts in the past. Please choose a later wake time."
        }
    }
}
```

## Testing the Fix

### Clean Build
1. Product → Clean Build Folder (⇧⌘K)
2. Rebuild: ⌘B

### Test Cases to Verify

✅ **Test 1: Set alarm for tomorrow morning**
- Open "Tonight" tab
- Tap "Set Smart Alarm"
- Select tomorrow's date with 7:00 AM time
- Set window to 30 minutes
- Should work without crashing

✅ **Test 2: Try to select past time (should be disabled)**
- The date picker should not allow selecting times in the past
- Button should be disabled if somehow a past time is selected

✅ **Test 3: Start tracking without alarm**
- Tap "Start Sleep Tracking" (no alarm)
- Should work fine

✅ **Test 4: Set alarm with various window sizes**
- Try 15, 30, 45, and 60 minute windows
- All should work without crashing

### Simulator Warnings (Expected, Safe to Ignore)

These are **normal** in the Simulator and won't affect the crash fix:

```
⚠️ iCloud not available                          → Normal, iCloud needs real device
⚠️ Accelerometer not available                   → Normal, motion tracking needs real device
⚠️ Failed to sync to HealthKit: Not authorized  → Normal in Simulator
⚠️ Failed to sync to iCloud: accountNotAvailable → Normal in Simulator
```

## Why This Happened

The crash occurred because of a sequence of events:

1. User opens alarm sheet
2. Selects a time like "8:00 AM" 
3. Current time is 10:00 AM, so `selectedTime` = today at 8:00 AM (in the past)
4. User taps "Start Sleep Tracking"
5. System tries to create: `windowStart...targetWake`
6. Since `targetWake` is in the past, and we subtract 30 minutes: `windowStart > targetWake`
7. **CRASH**: ClosedRange requires `lowerBound <= upperBound`

## Prevention

All four layers of validation now prevent this:

1. **UI Layer** (`TonightView`): Date picker restricts to future dates, button disabled for past times
2. **Controller Layer** (`SleepTrackingController`): Validates inputs before creating session
3. **Service Layer** (`SmartAlarmService`): Validates before scheduling notifications
4. **Model Layer** (`SleepSession`): Validates when computing range, returns nil if invalid

This defense-in-depth approach ensures the crash can't happen even if one validation is bypassed.

## Expected Behavior After Fix

✅ No more crashes when setting alarms
✅ Date picker starts with tomorrow morning by default
✅ Can't select times in the past
✅ Invalid alarm windows are clamped to valid ranges (5-60 minutes)
✅ Clear error messages if something goes wrong

## Real Device Testing

To fully test the app (especially iCloud sync, HealthKit, and motion tracking), you should test on a **real iOS device**:

1. Connect iPhone/iPad via USB or WiFi
2. Select device in Xcode
3. Build and run on device
4. Sign in to iCloud on the device
5. Grant all permissions (HealthKit, Motion, Notifications)
6. Test full sleep tracking workflow

The Simulator is fine for UI testing but has limitations for hardware features.
