//
//  SleepTrackingController.swift
//  sleep-health
//
//  Created by John Xu on 1/27/26.
//

import Foundation
import SwiftData
import SwiftUI
import Combine

/// Main controller coordinating all sleep tracking functionality (MVC pattern)
@MainActor
class SleepTrackingController: ObservableObject {
    // Published state
    @Published var currentSession: SleepSession?
    @Published var isTracking = false
    @Published var recentSessions: [SleepSession] = []
    @Published var errorMessage: String?
    
    // Services
    let monitoringService: SleepMonitoringService
    private let analysisService: SleepAnalysisService
    private let healthKitService: HealthKitService
    private let alarmService: SmartAlarmService
    let cloudSyncService: CloudSyncService
    private let snoreDetectionService: SnoreDetectionService
    
    // Data persistence
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.monitoringService = SleepMonitoringService()
        self.analysisService = SleepAnalysisService()
        self.healthKitService = HealthKitService()
        self.alarmService = SmartAlarmService()
        self.cloudSyncService = CloudSyncService()
        self.snoreDetectionService = SnoreDetectionService()
        
        setupMonitoringCallbacks()
        loadRecentSessions()
    }
    
    // MARK: - Setup
    
    private func setupMonitoringCallbacks() {
        monitoringService.onMovementSample = { [weak self] timestamp, intensity in
            guard let self = self, let session = self.currentSession else { return }
            
            let sample = MovementSample(timestamp: timestamp, intensity: intensity)
            sample.session = session
            if session.movementSamples == nil {
                session.movementSamples = []
            }
            session.movementSamples?.append(sample)
            
            // Save periodically
            try? self.modelContext.save()
        }
        
        monitoringService.onSoundSample = { [weak self] timestamp, decibelLevel in
            guard let self = self, let session = self.currentSession else { return }
            
            let sample = SoundSample(timestamp: timestamp, decibelLevel: decibelLevel)
            sample.session = session
            if session.soundSamples == nil {
                session.soundSamples = []
            }
            session.soundSamples?.append(sample)
            
            // Save periodically
            try? self.modelContext.save()
        }
        
        // Snore detection callback
        snoreDetectionService.onSnoreDetected = { [weak self] timestamp, duration in
            guard let self = self, let session = self.currentSession else { return }
            
            let snoreSample = SnoreSample(timestamp: timestamp, duration: duration)
            snoreSample.session = session
            if session.snoreEvents == nil {
                session.snoreEvents = []
            }
            session.snoreEvents?.append(snoreSample)
            
            // Update snore count
            session.totalSnores += 1
            
            // Save periodically
            try? self.modelContext.save()
            
            print("😴 Snore recorded: \(String(format: "%.1f", duration))s")
        }
    }
    
    // MARK: - Permissions
    
    func requestAllPermissions() async -> Bool {
        // Request microphone and motion
        let monitoringPermission = await monitoringService.requestPermissions()
        
        // Request HealthKit
        var healthKitPermission = false
        do {
            healthKitPermission = try await healthKitService.requestAuthorization()
        } catch {
            print("⚠️ HealthKit authorization failed: \(error)")
        }
        
        // Request notifications
        let notificationPermission = await alarmService.requestNotificationPermission()
        
        // Check iCloud
        let cloudAvailable = await cloudSyncService.checkAccountStatus()
        if !cloudAvailable {
            print("⚠️ iCloud not available")
        }
        
        return monitoringPermission && notificationPermission
    }
    
    // MARK: - Sleep Tracking Control
    
    func startSleepTracking(targetWakeTime: Date?, smartAlarmWindow: TimeInterval = 1800) async {
        print("------isTracking: \(isTracking) -------")
        guard !isTracking else { return }
        
        // Validate target wake time is in the future
        if let targetWake = targetWakeTime, targetWake <= Date() {
            errorMessage = "Target wake time must be in the future"
            return
        }
        
        // Ensure alarm window is reasonable (5 minutes to 1 hour)
        let validatedWindow = max(300, min(smartAlarmWindow, 3600))
        
        // Create new session
        let session = SleepSession(
            startTime: Date(),
            targetWakeTime: targetWakeTime,
            smartAlarmWindow: validatedWindow
        )
        
        modelContext.insert(session)
        try? modelContext.save()
        
        currentSession = session
        isTracking = true
        
        // Start monitoring
        monitoringService.startMonitoring()
        
        print("------ 5 -------")
        
        // Start snore detection
        snoreDetectionService.startDetection()
        
        print("------ 6 -------")
        
        // Set up smart alarm if target wake time is provided
        if let targetWake = targetWakeTime {
            do {
                try await alarmService.scheduleSmartAlarm(
                    targetWakeTime: targetWake,
                    windowDuration: validatedWindow
                )
                
                // Start monitoring for optimal wake time
                alarmService.startMonitoringForOptimalWake(
                    session: session,
                    analysisService: analysisService
                ) { [weak self] optimalTime in
                    self?.triggerWakeUp(at: optimalTime)
                }
            } catch {
                errorMessage = "Failed to schedule alarm: \(error.localizedDescription)"
            }
        }
    }
    
    func stopSleepTracking() async {
        guard isTracking, let session = currentSession else { return }
        
        // Stop monitoring
        monitoringService.stopMonitoring()
        
        // Stop snore detection and calculate metrics
        snoreDetectionService.stopDetection()
        let snoreMetrics = snoreDetectionService.calculateSnoreMetrics()
        
        // Update session with snore metrics
        session.totalSnores = snoreMetrics.totalSnores
        session.totalSnoreDuration = snoreMetrics.totalSnoreDuration
        session.snoresPerHour = snoreMetrics.snoresPerHour
        
        isTracking = false
        
        // Finalize session
        session.endTime = Date()
        
        // Analyze sleep data
        await analyzeSleepSession(session)
        
        // Sync to HealthKit
        await syncToHealthKit(session)
        
        // Sync to iCloud
        await syncToCloud(session)
        
        // Clear current session
        currentSession = nil
        
        // Reload recent sessions
        loadRecentSessions()
    }
    
    private func triggerWakeUp(at time: Date) {
        guard let session = currentSession else { return }
        
        session.actualWakeTime = time
        session.isAlarmTriggered = true
        try? modelContext.save()
        
        alarmService.triggerAlarm(at: time)
        
        Task {
            await stopSleepTracking()
        }
    }
    
    // MARK: - Data Analysis
    
    private func analyzeSleepSession(_ session: SleepSession) async {
        guard let endTime = session.endTime else { return }
        
        // Estimate sleep stages
        let stages = analysisService.estimateSleepStages(
            movementSamples: session.movementSamples ?? [],
            soundSamples: session.soundSamples ?? [],
            sessionStart: session.startTime,
            sessionEnd: endTime
        )
        
        // Add stages to session
        if session.sleepStages == nil {
            session.sleepStages = []
        }
        for stage in stages {
            stage.session = session
            session.sleepStages?.append(stage)
        }
        
        // Calculate metrics
        let metrics = analysisService.calculateSleepMetrics(session: session)
        
        // Update session with metrics
        session.totalSleepDuration = metrics.totalSleepDuration
        session.sleepEfficiency = metrics.sleepEfficiency
        session.numberOfAwakenings = metrics.numberOfAwakenings
        session.restlessnessScore = metrics.restlessnessScore
        
        try? modelContext.save()
    }
    
    // MARK: - Data Syncing
    
    private func syncToHealthKit(_ session: SleepSession) async {
        do {
            try await healthKitService.writeSleepSession(session)
            session.syncedToHealthKit = true
            try? modelContext.save()
            print("✅ Synced to HealthKit")
        } catch {
            print("⚠️ Failed to sync to HealthKit: \(error)")
            errorMessage = "Failed to sync to HealthKit"
        }
    }
    
    private func syncToCloud(_ session: SleepSession) async {
        do {
            try await cloudSyncService.syncSession(session)
            session.lastSyncedToCloud = Date()
            try? modelContext.save()
            print("✅ Synced to iCloud")
        } catch {
            print("⚠️ Failed to sync to iCloud: \(error)")
            // Don't show error to user - cloud sync can happen in background
        }
    }
    
    func syncAllToCloud() async {
        let unsyncedSessions = recentSessions.filter { $0.lastSyncedToCloud == nil }
        
        guard !unsyncedSessions.isEmpty else { return }
        
        do {
            try await cloudSyncService.syncMultipleSessions(unsyncedSessions)
            
            for session in unsyncedSessions {
                session.lastSyncedToCloud = Date()
            }
            try? modelContext.save()
            
        } catch {
            errorMessage = "Failed to sync to cloud: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Data Loading
    
    func loadRecentSessions(limit: Int = 30) {
        let descriptor = FetchDescriptor<SleepSession>(
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        
        do {
            recentSessions = try modelContext.fetch(descriptor)
            print("📊 Loaded \(recentSessions.count) sessions from database")
            
            // Debug: Print details of each session
            for (index, session) in recentSessions.enumerated() {
                print("  Session \(index + 1): \(session.startTime.formatted()) - Duration: \(session.totalSleepDuration)s")
            }
        } catch {
            print("⚠️ Failed to load sessions: \(error)")
            errorMessage = "Failed to load sleep history"
        }
    }
    
    func deleteAllSessions() {
        do {
            // Fetch all sessions
            let descriptor = FetchDescriptor<SleepSession>()
            let sessions = try modelContext.fetch(descriptor)
            
            print("🗑️ Deleting \(sessions.count) sessions...")
            
            // Delete each session
            for session in sessions {
                modelContext.delete(session)
            }
            
            // Save changes
            try modelContext.save()
            
            // Reload
            recentSessions = []
            
            print("✅ All sessions deleted successfully")
        } catch {
            print("⚠️ Failed to delete sessions: \(error)")
            errorMessage = "Failed to delete sessions: \(error.localizedDescription)"
        }
    }
    
    func getSessionsForDateRange(from: Date, to: Date) -> [SleepSession] {
        recentSessions.filter { session in
            session.startTime >= from && session.startTime <= to
        }
    }
    
    // MARK: - Statistics
    
    func calculateAverageMetrics(days: Int = 7) -> AverageSleepMetrics? {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let recentSessions = getSessionsForDateRange(from: cutoffDate, to: Date())
        
        guard !recentSessions.isEmpty else { return nil }
        
        let avgDuration = recentSessions.map(\.totalSleepDuration).reduce(0, +) / Double(recentSessions.count)
        let avgEfficiency = recentSessions.map(\.sleepEfficiency).reduce(0, +) / Double(recentSessions.count)
        let avgAwakenings = Double(recentSessions.map(\.numberOfAwakenings).reduce(0, +)) / Double(recentSessions.count)
        let avgRestlessness = recentSessions.map(\.restlessnessScore).reduce(0, +) / Double(recentSessions.count)
        
        return AverageSleepMetrics(
            averageDuration: avgDuration,
            averageEfficiency: avgEfficiency,
            averageAwakenings: avgAwakenings,
            averageRestlessness: avgRestlessness,
            numberOfNights: recentSessions.count
        )
    }
}

// MARK: - Supporting Types

struct AverageSleepMetrics {
    let averageDuration: TimeInterval
    let averageEfficiency: Double
    let averageAwakenings: Double
    let averageRestlessness: Double
    let numberOfNights: Int
    
    var averageDurationFormatted: String {
        let hours = Int(averageDuration) / 3600
        let minutes = (Int(averageDuration) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
}
