# Architecture Overview

## System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                          Sleep Health App                            │
│                        (iOS 17+ SwiftUI App)                         │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                           VIEW LAYER (SwiftUI)                       │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌────────────┐   │
│  │  Tonight   │  │  History   │  │   Trends   │  │  Settings  │   │
│  │   View     │  │   View     │  │    View    │  │    View    │   │
│  └────────────┘  └────────────┘  └────────────┘  └────────────┘   │
│        │               │                │               │            │
│        └───────────────┴────────────────┴───────────────┘            │
│                             │                                         │
│                    ┌────────▼─────────┐                              │
│                    │  ContentView     │                              │
│                    │  (Tab Bar Root)  │                              │
│                    └────────┬─────────┘                              │
└─────────────────────────────┼─────────────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────────────┐
│                     CONTROLLER LAYER (MVC)                           │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│               ┌──────────────────────────────────┐                  │
│               │  SleepTrackingController         │                  │
│               │  (@MainActor, ObservableObject)  │                  │
│               │                                   │                  │
│               │  • Coordinates all services       │                  │
│               │  • Manages app state             │                  │
│               │  • Handles data persistence      │                  │
│               │  • Triggers sync operations      │                  │
│               └───────────┬──────────────────────┘                  │
│                           │                                           │
└───────────────────────────┼───────────────────────────────────────┘
                             │
          ┌──────────────────┼──────────────────┐
          │                  │                  │
┌─────────▼─────────┐ ┌──────▼──────┐ ┌────────▼────────┐
│  SERVICE LAYER     │ │  SERVICE    │ │   SERVICE       │
├────────────────────┤ ├─────────────┤ ├─────────────────┤
│                    │ │             │ │                 │
│  ┌──────────────┐ │ │ ┌─────────┐ │ │ ┌─────────────┐│
│  │Sleep         │ │ │ │Sleep    │ │ │ │Smart        ││
│  │Monitoring    │ │ │ │Analysis │ │ │ │Alarm        ││
│  │Service       │ │ │ │Service  │ │ │ │Service      ││
│  └──────────────┘ │ │ └─────────┘ │ │ └─────────────┘│
│                    │ │             │ │                 │
│  ┌──────────────┐ │ │             │ │ ┌─────────────┐│
│  │HealthKit     │ │ │             │ │ │Cloud        ││
│  │Service       │ │ │             │ │ │Sync         ││
│  └──────────────┘ │ │             │ │ │Service      ││
│                    │ │             │ │ └─────────────┘│
└────────────────────┘ └─────────────┘ └─────────────────┘
          │                  │                  │
          └──────────────────┼──────────────────┘
                             │
┌────────────────────────────▼─────────────────────────────────────────┐
│                         DATA LAYER                                    │
├──────────────────────────────────────────────────────────────────────┤
│                                                                        │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │                      SwiftData Models                        │    │
│  │                                                               │    │
│  │  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐ │    │
│  │  │SleepSession  │───▶│MovementSample│    │SoundSample   │ │    │
│  │  │              │    │              │    │              │ │    │
│  │  │• id          │    │• timestamp   │    │• timestamp   │ │    │
│  │  │• startTime   │    │• intensity   │    │• decibelLevel│ │    │
│  │  │• endTime     │    └──────────────┘    └──────────────┘ │    │
│  │  │• metrics     │                                          │    │
│  │  └──────┬───────┘                                          │    │
│  │         │                                                   │    │
│  │         │           ┌──────────────┐                       │    │
│  │         └──────────▶│SleepStage    │                       │    │
│  │                     │              │                       │    │
│  │                     │• startTime   │                       │    │
│  │                     │• endTime     │                       │    │
│  │                     │• stage       │                       │    │
│  │                     └──────────────┘                       │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                        │
└────────────────────────────────────────────────────────────────────┘
          │
          │
┌─────────▼──────────────────────────────────────────────────────────┐
│                    INTEGRATION LAYER                                 │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐         │
│  │  CoreMotion  │    │ AVFoundation │    │UserNotif.    │         │
│  │              │    │              │    │              │         │
│  │• Accelero-   │    │• Audio       │    │• Alarms      │         │
│  │  meter       │    │  Engine      │    │• Smart       │         │
│  │• Movement    │    │• Sound       │    │  Timing      │         │
│  └──────────────┘    └──────────────┘    └──────────────┘         │
│                                                                       │
│  ┌──────────────┐    ┌──────────────┐                               │
│  │  HealthKit   │    │   CloudKit   │                               │
│  │              │    │              │                               │
│  │• Sleep       │    │• Private DB  │                               │
│  │  Analysis    │    │• Sync        │                               │
│  │• Write Data  │    │• Backup      │                               │
│  └──────────────┘    └──────────────┘                               │
│                                                                       │
└─────────────────────────────────────────────────────────────────────┘
```

## Data Flow Sequence

### 1. Starting Sleep Tracking

```
User Interaction:
    ↓
TonightView.startTracking()
    ↓
SleepTrackingController.startSleepTracking()
    ↓
┌──────────────────────────────────┐
│ Create SleepSession              │
│ Insert into SwiftData            │
└──────────────────────────────────┘
    ↓
SleepMonitoringService.startMonitoring()
    ↓
┌──────────────────────────────────┐
│ Start CoreMotion                 │
│ Start AVAudioEngine              │
│ Begin sampling loop              │
└──────────────────────────────────┘
    ↓
SmartAlarmService.scheduleSmartAlarm()
    ↓
┌──────────────────────────────────┐
│ Schedule notification            │
│ Start monitoring window          │
└──────────────────────────────────┘
```

### 2. During Sleep Monitoring

```
Every 30 seconds:
    ↓
┌──────────────────────────────────┐
│ SleepMonitoringService           │
│   • Read accelerometer           │
│   • Calculate movement intensity │
│   • Measure sound level          │
└──────────────────────────────────┘
    ↓
Callback to Controller
    ↓
┌──────────────────────────────────┐
│ Create MovementSample            │
│ Create SoundSample               │
│ Append to SleepSession           │
│ Save to SwiftData                │
└──────────────────────────────────┘
    ↓
Update UI (Published properties)
    ↓
TonightView shows real-time metrics
```

### 3. Smart Alarm Triggering

```
Every minute during alarm window:
    ↓
SmartAlarmService checks sleep stage
    ↓
SleepAnalysisService.findOptimalWakeTime()
    ↓
┌──────────────────────────────────┐
│ Analyze recent sleep stages      │
│ Look for light sleep or awake    │
│ Return optimal time              │
└──────────────────────────────────┘
    ↓
If optimal time found:
    ↓
SmartAlarmService.triggerAlarm()
    ↓
┌──────────────────────────────────┐
│ Send notification                │
│ Play alarm sound                 │
│ Fade in volume                   │
└──────────────────────────────────┘
    ↓
Controller.stopSleepTracking()
```

### 4. Stopping & Analysis

```
User stops tracking OR alarm triggers:
    ↓
SleepTrackingController.stopSleepTracking()
    ↓
┌──────────────────────────────────┐
│ Stop SleepMonitoringService      │
│ Set session.endTime              │
└──────────────────────────────────┘
    ↓
SleepAnalysisService.estimateSleepStages()
    ↓
┌──────────────────────────────────┐
│ Group samples into 5-min windows │
│ Classify each window:            │
│   • Awake                        │
│   • Light                        │
│   • Deep                         │
│   • REM                          │
│ Smooth transitions               │
└──────────────────────────────────┘
    ↓
SleepAnalysisService.calculateSleepMetrics()
    ↓
┌──────────────────────────────────┐
│ Calculate:                       │
│   • Total sleep duration         │
│   • Sleep efficiency             │
│   • Number of awakenings         │
│   • Restlessness score           │
│   • Quality score                │
└──────────────────────────────────┘
    ↓
Update SleepSession with metrics
    ↓
Parallel sync operations:
    ├─→ HealthKitService.writeSleepSession()
    │      └─→ Apple Health
    │
    └─→ CloudSyncService.syncSession()
           └─→ iCloud CloudKit
```

### 5. Viewing Results

```
User opens History:
    ↓
HistoryView loads
    ↓
Controller.loadRecentSessions()
    ↓
┌──────────────────────────────────┐
│ Fetch from SwiftData             │
│ Sort by date descending          │
│ Populate @Published array        │
└──────────────────────────────────┘
    ↓
List displays session rows
    ↓
User taps session
    ↓
SleepSessionDetailView presents
    ↓
┌──────────────────────────────────┐
│ Display:                         │
│   • Summary metrics              │
│   • Sleep stages chart           │
│   • Movement graph               │
│   • Sound graph                  │
│   • Quality assessment           │
└──────────────────────────────────┘
```

## Class Responsibilities

### View Layer
| Class | Responsibility |
|-------|---------------|
| `ContentView` | Root navigation, tab bar management |
| `TonightView` | Start/stop tracking UI, real-time metrics |
| `HistoryView` | List sessions, show summaries |
| `SleepSessionDetailView` | Detailed charts and metrics |
| `TrendsView` | Long-term analytics and charts |
| `SettingsView` | App configuration, permissions |

### Controller Layer
| Class | Responsibility |
|-------|---------------|
| `SleepTrackingController` | Main coordinator, state management, orchestrates services |

### Service Layer
| Class | Responsibility |
|-------|---------------|
| `SleepMonitoringService` | Sensor data collection (motion, sound) |
| `SleepAnalysisService` | Algorithm for stage estimation and metrics |
| `HealthKitService` | HealthKit read/write operations |
| `SmartAlarmService` | Alarm scheduling and triggering |
| `CloudSyncService` | CloudKit sync operations |

### Model Layer
| Class | Responsibility |
|-------|---------------|
| `SleepSession` | Main session entity with relationships |
| `MovementSample` | Individual movement data point |
| `SoundSample` | Individual sound data point |
| `SleepStage` | Sleep stage period with classification |

## Technology Stack

```
┌─────────────────────────────────────────┐
│           Application Layer              │
│                                          │
│  SwiftUI + Swift Concurrency             │
│  (async/await, @MainActor, Task)        │
└─────────────────────────────────────────┘
                   │
┌─────────────────▼────────────────────────┐
│           Framework Layer                │
│                                          │
│  • SwiftData (Persistence)              │
│  • Swift Charts (Visualization)         │
│  • Combine (Reactive Updates)           │
└─────────────────────────────────────────┘
                   │
┌─────────────────▼────────────────────────┐
│           System Layer                   │
│                                          │
│  • HealthKit (Health Integration)       │
│  • CloudKit (Cloud Sync)                │
│  • CoreMotion (Accelerometer)           │
│  • AVFoundation (Audio)                 │
│  • UserNotifications (Alarms)           │
└─────────────────────────────────────────┘
```

## Design Patterns

### 1. MVC (Model-View-Controller)
- **Model**: SwiftData entities
- **View**: SwiftUI views
- **Controller**: `SleepTrackingController` coordinates everything

### 2. Service Layer Pattern
- Specialized services handle specific domains
- Controller delegates to services
- Services are independent and testable

### 3. Observer Pattern
- Controller is `ObservableObject`
- Views observe controller via `@ObservedObject`
- UI updates automatically via `@Published` properties

### 4. Repository Pattern
- SwiftData `ModelContext` acts as repository
- Controller manages data persistence
- Clean separation from business logic

### 5. Strategy Pattern
- `SleepAnalysisService` encapsulates algorithm
- Can swap algorithms without changing controller
- Easy to add ML-based stage detection later

## Concurrency Model

```
┌─────────────────────────────────────────┐
│           @MainActor                     │
│                                          │
│  • SleepTrackingController              │
│  • SleepMonitoringService               │
│  • SmartAlarmService                    │
│  • All SwiftUI Views                    │
│                                          │
│  Ensures thread-safe UI updates         │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│           Background Tasks               │
│                                          │
│  • SleepAnalysisService (CPU-bound)     │
│  • CloudSyncService (async network)     │
│  • HealthKitService (async I/O)         │
│                                          │
│  Uses async/await for clean code        │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│           Task Management                │
│                                          │
│  • Monitoring loop (Task.sleep)         │
│  • Timer-based checks                   │
│  • Async callbacks via closures         │
│                                          │
│  Proper cancellation on stop            │
└─────────────────────────────────────────┘
```

## Error Handling Strategy

```
┌─────────────────────────────────────────┐
│           User-Facing Errors             │
│                                          │
│  • Display in UI via @Published property│
│  • Use alerts for critical issues       │
│  • Toast messages for info              │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│           Recoverable Errors             │
│                                          │
│  • HealthKit sync failures: retry later │
│  • CloudKit errors: queue for later     │
│  • Permission denials: show settings    │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│           Logging & Debug                │
│                                          │
│  • Print statements with emojis         │
│  • Structured error types               │
│  • Detailed error descriptions          │
└─────────────────────────────────────────┘
```

## Performance Characteristics

| Component | Performance | Notes |
|-----------|-------------|-------|
| Sensor Sampling | 10 Hz (motion) | Efficient, low CPU |
| Data Aggregation | Every 30s | Batch saves reduce I/O |
| Stage Analysis | < 1s | Heuristic is fast |
| SwiftData Queries | < 50ms | Indexed by date |
| Chart Rendering | < 100ms | Sampled for large datasets |
| Cloud Sync | 1-5s | Depends on network |

## Scalability Considerations

### Data Volume
- 8-hour session: ~960 samples
- 30 days: ~28,800 samples
- SwiftData handles efficiently with pagination

### Memory Usage
- Active session: < 10 MB
- Historical data: Lazy-loaded
- Charts: Sample 100-200 points max

### Battery Impact
- Typical: 15-25% overnight
- Optimized sampling intervals
- Audio engine efficient in measurement mode

## Security & Privacy

```
┌─────────────────────────────────────────┐
│           Local Processing               │
│                                          │
│  All analysis done on device            │
│  No external servers or APIs            │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│           Secure Storage                 │
│                                          │
│  SwiftData encrypted at rest            │
│  HealthKit governed by iOS              │
│  CloudKit private container             │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│           User Control                   │
│                                          │
│  Explicit permission requests           │
│  Can delete data anytime                │
│  Export functionality available         │
└─────────────────────────────────────────┘
```

---

This architecture provides:
- ✅ Clean separation of concerns
- ✅ Testable components
- ✅ Scalable design
- ✅ Maintainable code
- ✅ Performance optimized
- ✅ Privacy-first approach
