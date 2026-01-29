//
//  SmartAlarmService.swift
//  sleep-health
//
//  Created by John Xu on 1/27/26.
//

import Foundation
import UserNotifications
import AVFoundation
import Combine

/// Manages smart alarm functionality and notifications
@MainActor
class SmartAlarmService: NSObject, ObservableObject {
    @Published var isAlarmSet = false
    @Published var nextAlarmTime: Date?
    
    private var audioPlayer: AVAudioPlayer?
    private var alarmCheckTimer: Timer?
    
    private let notificationCenter = UNUserNotificationCenter.current()
    
    override init() {
        super.init()
        notificationCenter.delegate = self
    }
    
    // MARK: - Public Interface
    
    func requestNotificationPermission() async -> Bool {
        do {
            return try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            print("⚠️ Failed to request notification permission: \(error)")
            return false
        }
    }
    
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
        
        // Schedule notification at the start of the smart alarm window
        let content = UNMutableNotificationContent()
        content.title = "Smart Alarm Active"
        content.body = "Monitoring for optimal wake time..."
        content.sound = nil
        content.categoryIdentifier = "SMART_ALARM"
        
        let triggerDate = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: windowStart
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        
        try await notificationCenter.add(request)
        
        isAlarmSet = true
        nextAlarmTime = targetWakeTime
    }
    
    func triggerAlarm(at time: Date) {
        guard isAlarmSet else { return }
        
        // Schedule immediate notification
        let content = UNMutableNotificationContent()
        content.title = "Good Morning! ☀️"
        content.body = "Time to wake up refreshed"
        content.sound = .default
        content.categoryIdentifier = "ALARM_TRIGGER"
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "alarm_trigger_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        Task {
            try? await notificationCenter.add(request)
        }
        
        // Play alarm sound
        playAlarmSound()
        
        isAlarmSet = false
        nextAlarmTime = nil
    }
    
    func cancelAlarm() {
        notificationCenter.removeAllPendingNotificationRequests()
        audioPlayer?.stop()
        audioPlayer = nil
        alarmCheckTimer?.invalidate()
        alarmCheckTimer = nil
        
        isAlarmSet = false
        nextAlarmTime = nil
    }
    
    // MARK: - Smart Alarm Monitoring
    
    func startMonitoringForOptimalWake(
        session: SleepSession,
        analysisService: SleepAnalysisService,
        onOptimalTimeFound: @escaping (Date) -> Void
    ) {
        guard let windowRange = session.smartAlarmWindowRange else { return }
        
        // Capture values we need before the closure to avoid capturing non-Sendable session
        let sleepStages = session.sleepStages ?? []
        let targetWakeTime = session.targetWakeTime
        
        // Check every minute during the smart alarm window
        alarmCheckTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            let now = Date()
            
            // Check if we're in the window
            if windowRange.contains(now) {
                // Analyze current sleep stage
                let optimalTime = analysisService.findOptimalWakeTime(
                    stages: sleepStages,
                    windowStart: windowRange.lowerBound,
                    windowEnd: windowRange.upperBound
                )
                
                if let optimal = optimalTime, optimal <= now {
                    onOptimalTimeFound(optimal)
                    self.alarmCheckTimer?.invalidate()
                }
            } else if now > windowRange.upperBound {
                // Window passed, trigger alarm at target time
                onOptimalTimeFound(targetWakeTime ?? now)
                self.alarmCheckTimer?.invalidate()
            }
        }
        
        alarmCheckTimer?.fire()
    }
    
    // MARK: - Audio Playback
    
    private func playAlarmSound() {
        // Use a gentle alarm sound
        // In production, you'd include a custom sound file
        guard let url = Bundle.main.url(forResource: "alarm_sound", withExtension: "mp3") else {
            // Fallback to system sound if custom sound not available
            playSystemSound()
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.numberOfLoops = 3 // Play 3 times
            audioPlayer?.volume = 0.3 // Start at 30% volume
            audioPlayer?.play()
            
            // Gradually increase volume
            fadeInVolume()
        } catch {
            print("⚠️ Failed to play alarm sound: \(error)")
            playSystemSound()
        }
    }
    
    private func playSystemSound() {
        // Use system sound as fallback
        AudioServicesPlaySystemSound(1304) // Long vibration
    }
    
    private func fadeInVolume() {
        guard let player = audioPlayer else { return }
        
        let fadeDuration: TimeInterval = 30 // 30 seconds
        let steps = 30
        let stepDuration = fadeDuration / Double(steps)
        let volumeIncrement = Float(0.7) / Float(steps) // Increase to 100%
        
        var currentStep = 0
        
        Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { timer in
            currentStep += 1
            player.volume = min(player.volume + volumeIncrement, 1.0)
            
            if currentStep >= steps {
                timer.invalidate()
            }
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension SmartAlarmService: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Handle notification tap
        completionHandler()
    }
}
// MARK: - Errors

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

