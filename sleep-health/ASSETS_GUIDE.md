# Assets and Resources Guide

## Required Assets

### App Icon
Create an app icon set in `Assets.xcassets/AppIcon.appiconset/` with these sizes:
- 1024×1024 (App Store)
- 180×180 (iPhone 3x)
- 120×120 (iPhone 2x)
- 167×167 (iPad Pro)
- 152×152 (iPad 2x)
- 76×76 (iPad)

**Recommended design**: Moon or sleep-related imagery with calming blue/purple colors

### Alarm Sound (Optional)
If you want a custom alarm sound:
1. Create an audio file: `alarm_sound.mp3`
2. Add to project bundle
3. Duration: 30-60 seconds
4. Format: MP3 or M4A
5. Gentle, gradually increasing intensity

**Note**: The app falls back to system sounds if custom sound is not provided.

## Color Scheme

The app uses a sleep-focused color palette:

### Primary Colors
- **Indigo** (`Color.indigo`): Main background gradients
- **Purple** (`Color.purple`): Deep sleep indicators
- **Blue** (`Color.blue`): Light sleep, movement metrics
- **Green** (`Color.green`): REM sleep, sound metrics

### Semantic Colors
- **Yellow** (`Color.yellow`): Alarm indicators
- **Red** (`Color.red`): Awake state, warnings
- **Orange** (`Color.orange`): Awakenings, restlessness

### System Colors
Uses SwiftUI's built-in colors for consistency:
- `.secondary` for labels
- `.ultraThinMaterial` for cards
- `.primary` for main text

## SF Symbols Used

The app relies on SF Symbols (built into iOS):

### Main Navigation
- `moon.stars.fill` - Tonight tab
- `chart.line.uptrend.xyaxis` - History tab
- `chart.bar.fill` - Trends tab
- `gear` - Settings tab

### Sleep Tracking
- `moon.zzz.fill` - Start tracking
- `alarm.fill` - Smart alarm
- `waveform.path` - Active tracking
- `stop.fill` - Stop tracking

### Metrics
- `bed.double.fill` - Sleep duration
- `figure.walk.motion` - Movement
- `waveform` - Sound
- `clock.fill` - Time
- `brain.head.profile` - REM sleep

### Status Indicators
- `star.fill` - Quality rating
- `heart.fill` - HealthKit
- `icloud.fill` - Cloud sync
- `checkmark.circle.fill` - Success
- `exclamationmark.triangle.fill` - Warning

## Launch Screen

Create a simple launch screen in `LaunchScreen.storyboard`:
1. Black or dark blue background
2. App icon or moon symbol centered
3. App name in clean sans-serif font
4. "Sleep Health" or your custom name

## Accessibility

### VoiceOver Support
All views use proper labels:
```swift
.accessibilityLabel("Sleep duration: 7 hours 30 minutes")
.accessibilityHint("Double tap to view details")
```

### Dynamic Type
All text uses system fonts that scale with user preferences:
```swift
.font(.headline)
.font(.body)
.font(.caption)
```

### Color Contrast
- Text: White on dark backgrounds for night-time use
- Minimum contrast ratio: 4.5:1
- Important elements: 7:1 contrast

## Localization (Future)

To add localization:
1. Create `Localizable.strings` files
2. Wrap user-facing strings:
   ```swift
   Text(NSLocalizedString("start_tracking", comment: "Start tracking button"))
   ```
3. Export for translation
4. Add language variants

## App Store Screenshots

Recommended screenshots (6.7" and 5.5" displays):

1. **Tonight View** - Tracking active with real-time metrics
2. **Morning Summary** - Beautiful sleep stage chart
3. **History List** - Multiple sessions with quality indicators  
4. **Session Detail** - Comprehensive charts and metrics
5. **Trends View** - Long-term analytics with graphs
6. **Smart Alarm** - Alarm settings sheet

### Screenshot Tips
- Use dark mode for sleep theme
- Show realistic data
- Include time stamps for context
- Highlight key features
- Add captions if needed

## Marketing Materials

### App Store Description Keywords
- Sleep tracking
- Smart alarm
- Sleep cycles
- Sleep stages
- Health integration
- Movement monitoring
- Sound detection
- Sleep quality
- Bedtime routine
- Wake up refreshed

### App Preview Video (Optional)
30-second video showing:
1. Starting sleep tracking (3s)
2. Real-time monitoring (5s)
3. Smart alarm triggering (5s)
4. Morning summary (7s)
5. Trends and insights (7s)
6. Health integration (3s)

## Privacy Nutrition Labels

For App Store Connect, declare:

### Data Collected
- **Health & Fitness**: Sleep data (linked to user)
- **Usage Data**: App interactions (not linked to user)

### Data Usage
- **App Functionality**: Sleep tracking and analysis
- **Product Personalization**: Smart alarm optimization

### Data Sharing
- **None**: All data stays on device or in user's iCloud

## Required Screenshots for Review

Apple may request:
1. Permission dialogs (microphone, health, notifications)
2. Settings showing data management
3. HealthKit integration
4. CloudKit dashboard showing container

## File Naming Conventions

Organize assets consistently:
```
Assets.xcassets/
├── AppIcon.appiconset/
├── Colors/
│   ├── SleepBlue.colorset
│   ├── SleepPurple.colorset
│   └── DeepSleep.colorset
├── Images/
│   └── (any additional graphics)
└── Sounds/
    └── alarm_sound.dataset (if used)
```

## Tips for Visual Design

### Consistency
- Use 16pt corner radius for cards
- 12pt spacing between elements
- 20pt padding for major sections

### Animations
- `.symbolEffect()` for SF Symbols
- Smooth transitions between views
- Loading states for async operations

### Dark Mode
- Already optimized for nighttime use
- Use `.preferredColorScheme(.dark)` if forcing dark mode
- System materials adapt automatically

## Accessibility Assets

### Alternative Text
All images should have accessibility labels:
```swift
Image(systemName: "moon.stars.fill")
    .accessibilityLabel("Sleep tracking")
```

### Reduced Motion
Respect user preferences:
```swift
@Environment(\.accessibilityReduceMotion) var reduceMotion

if !reduceMotion {
    // Animate
}
```

---

**Note**: Most assets are handled by SF Symbols and SwiftUI system colors. The app is designed to work immediately without custom assets. Add custom elements only if needed for branding.
