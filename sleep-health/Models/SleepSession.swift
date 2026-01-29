//
//  SleepSession.swift
//  sleep-health
//
//  Created by John Xu on 1/27/26.
//

import Foundation
import SwiftData

/// Represents a complete sleep session with all tracked data
@Model
final class SleepSession {
    var id: UUID = UUID()
    var startTime: Date = Date()
    var endTime: Date?
    var targetWakeTime: Date?
    var smartAlarmWindow: TimeInterval = 1800 // in seconds, e.g., 1800 = 30 minutes
    var actualWakeTime: Date?
    var isAlarmTriggered: Bool = false
    
    // Sleep quality metrics
    var totalSleepDuration: TimeInterval = 0
    var sleepEfficiency: Double = 0 // percentage
    var numberOfAwakenings: Int = 0
    var restlessnessScore: Double = 0 // 0-100
    
    // Snoring metrics
    var totalSnores: Int = 0
    var totalSnoreDuration: TimeInterval = 0
    var snoresPerHour: Double = 0
    
    // Raw sensor data
    @Relationship(deleteRule: .cascade) var movementSamples: [MovementSample]?
    @Relationship(deleteRule: .cascade) var soundSamples: [SoundSample]?
    @Relationship(deleteRule: .cascade) var sleepStages: [SleepStage]?
    @Relationship(deleteRule: .cascade) var snoreEvents: [SnoreSample]?
    
    // Sync metadata
    var lastSyncedToCloud: Date?
    var syncedToHealthKit: Bool = false
    
    init(
        startTime: Date? = nil,
        targetWakeTime: Date? = nil,
        smartAlarmWindow: TimeInterval = 1800
    ) {
        self.id = UUID()
        self.startTime = startTime ?? Date()
        self.endTime = nil
        self.targetWakeTime = targetWakeTime
        self.smartAlarmWindow = smartAlarmWindow
        self.actualWakeTime = nil
        self.isAlarmTriggered = false
        self.totalSleepDuration = 0
        self.sleepEfficiency = 0
        self.numberOfAwakenings = 0
        self.restlessnessScore = 0
        self.movementSamples = []
        self.soundSamples = []
        self.sleepStages = []
        self.lastSyncedToCloud = nil
        self.syncedToHealthKit = false
    }
    
    /// Calculates the ideal wake time window for smart alarm
    var smartAlarmWindowRange: ClosedRange<Date>? {
        guard let targetWake = targetWakeTime else { return nil }
        
        // Ensure smartAlarmWindow is positive and reasonable
        let window = max(300, min(smartAlarmWindow, 3600)) // Between 5 min and 1 hour
        let windowStart = targetWake.addingTimeInterval(-window)
        
        // Ensure windowStart is before targetWake
        guard windowStart < targetWake else { return nil }
        
        return windowStart...targetWake
    }
    
    /// Total time in bed
    var timeInBed: TimeInterval {
        guard let end = endTime else {
            return Date().timeIntervalSince(startTime)
        }
        return end.timeIntervalSince(startTime)
    }
}

/// Represents a single movement sample from accelerometer
@Model
final class MovementSample {
    var id: UUID = UUID()
    var timestamp: Date = Date()
    var intensity: Double = 0 // 0-1 scale
    var session: SleepSession?
    
    init(timestamp: Date? = nil, intensity: Double = 0) {
        self.id = UUID()
        self.timestamp = timestamp ?? Date()
        self.intensity = intensity
    }
}

/// Represents ambient sound level sample
@Model
final class SoundSample {
    var id: UUID = UUID()
    var timestamp: Date = Date()
    var decibelLevel: Double = 0
    var session: SleepSession?
    
    init(timestamp: Date? = nil, decibelLevel: Double = 0) {
        self.id = UUID()
        self.timestamp = timestamp ?? Date()
        self.decibelLevel = decibelLevel
    }
}

/// Represents an estimated sleep stage period
@Model
final class SleepStage {
    var id: UUID = UUID()
    var startTime: Date = Date()
    var endTime: Date = Date()
    var stage: Stage = Stage.awake
    var session: SleepSession?
    
    enum Stage: String, Codable {
        case awake
        case light
        case deep
        case rem
    }
    
    init(startTime: Date? = nil, endTime: Date? = nil, stage: Stage = .awake) {
        self.id = UUID()
        self.startTime = startTime ?? Date()
        self.endTime = endTime ?? Date()
        self.stage = stage
    }
    
    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }
}

/// Represents a detected snoring event
@Model
final class SnoreSample {
    var id: UUID = UUID()
    var timestamp: Date = Date()
    var duration: TimeInterval = 0
    var session: SleepSession?
    
    init(timestamp: Date? = nil, duration: TimeInterval = 0) {
        self.id = UUID()
        self.timestamp = timestamp ?? Date()
        self.duration = duration
    }
}

