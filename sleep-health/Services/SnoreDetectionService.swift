//
//  SnoreDetectionService.swift
//  sleep-health
//
//  Created by Assistant on 1/28/26.
//

import Foundation
import AVFoundation
import Accelerate
import Combine

/// Detects and records snoring events during sleep
class SnoreDetectionService: NSObject, ObservableObject {
    @Published var isDetecting = false
    @Published var snoreCount = 0
    
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    
    // Detection parameters
    private let sampleRate: Double = 44100
    private let snoreFrequencyRange: ClosedRange<Float> = 50...500 // Hz, typical snore frequency
    private let snoreVolumeThreshold: Float = -30.0 // dB threshold for snoring
    private let snoreDurationMin: TimeInterval = 0.3 // Minimum duration for snore (seconds)
    
    // Tracking
    private var currentSnoreStart: Date?
    private var lastSnoreEnd: Date?
    private var detectedSnores: [SnoreEvent] = []
    
    // Callback for when snore is detected
    var onSnoreDetected: ((Date, TimeInterval) -> Void)?
    
    // MARK: - Public Interface
    
    func startDetection() {
        print("------isDetecting: \(isDetecting) --------")
        guard !isDetecting else { return }
        
        do {
            try setupAudioEngine()
            audioEngine?.prepare()
            try audioEngine?.start()
            
            isDetecting = true
            snoreCount = 0
            detectedSnores.removeAll()
            
            print("🎤 Snore detection started")
        } catch {
            print("⚠️ Failed to start snore detection: \(error)")
        }
    }
    
    func stopDetection() {
        guard isDetecting else { return }
        
        audioEngine?.stop()
        inputNode?.removeTap(onBus: 0)
        
        isDetecting = false
        
        print("🛑 Snore detection stopped")
        print("📊 Total snores detected: \(snoreCount)")
    }
    
    func getDetectedSnores() -> [SnoreEvent] {
        return detectedSnores
    }
    
    func calculateSnoreMetrics() -> SnoreMetrics {
        print("--------!detectedSnores.isEmpty: \(!detectedSnores.isEmpty) -- detectedSnores.count :\(detectedSnores.count) ---------")
        guard !detectedSnores.isEmpty else {
            return SnoreMetrics(
                totalSnores: 0,
                totalSnoreDuration: 0,
                averageSnoreDuration: 0,
                longestSnore: 0,
                snoresPerHour: 0
            )
        }
        
        print("--------- 0 ----------")
        
        let totalDuration = detectedSnores.reduce(0) { $0 + $1.duration }
        let averageDuration = totalDuration / Double(detectedSnores.count)
        let longestSnore = detectedSnores.map(\.duration).max() ?? 0
        
        print("--------- totalDuration : \(totalDuration) ----------")
        
        // Calculate snores per hour
        guard let firstSnore = detectedSnores.first?.timestamp,
              let lastSnore = detectedSnores.last?.timestamp else {
            return SnoreMetrics(
                totalSnores: detectedSnores.count,
                totalSnoreDuration: totalDuration,
                averageSnoreDuration: averageDuration,
                longestSnore: longestSnore,
                snoresPerHour: 0
            )
        }
        
        let sessionDuration = lastSnore.timeIntervalSince(firstSnore) / 3600 // hours
        let snoresPerHour = sessionDuration > 0 ? Double(detectedSnores.count) / sessionDuration : 0
        
        return SnoreMetrics(
            totalSnores: detectedSnores.count,
            totalSnoreDuration: totalDuration,
            averageSnoreDuration: averageDuration,
            longestSnore: longestSnore,
            snoresPerHour: snoresPerHour
        )
    }
    
    // MARK: - Audio Engine Setup
    
    private func setupAudioEngine() throws {
        // Clean up any existing audio engine first
        if let existingNode = inputNode {
            existingNode.removeTap(onBus: 0)
        }
        audioEngine?.stop()
        audioEngine = nil
        inputNode = nil
        
        // Set up audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: [])
        try audioSession.setActive(true)
        
        // Create new audio engine
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            throw SnoreDetectionError.audioEngineSetupFailed
        }
        
        // Get input node
        inputNode = audioEngine.inputNode
        guard let inputNode = inputNode else {
            throw SnoreDetectionError.inputNodeNotAvailable
        }
        
        let format = inputNode.outputFormat(forBus: 0)
        
        // Install tap (should work now since we cleaned up first)
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer)
        }
    }
    
    // MARK: - Audio Processing
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        
        let frameLength = Int(buffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: channelData[0], count: frameLength))
        
        // Calculate volume (RMS)
        let rms = calculateRMS(samples: samples)
        let db = 20 * log10(rms)
        
        // Check if sound is loud enough to be a potential snore
        if db > snoreVolumeThreshold {
            // Perform frequency analysis
            if isLikelySnore(samples: samples, sampleRate: Float(sampleRate)) {
                handlePotentialSnore()
            }
        } else {
            // Volume too low, end any ongoing snore
            endCurrentSnore()
        }
    }
    
    private func calculateRMS(samples: [Float]) -> Float {
        var sumOfSquares: Float = 0
        vDSP_svesq(samples, 1, &sumOfSquares, vDSP_Length(samples.count))
        let rms = sqrt(sumOfSquares / Float(samples.count))
        return max(rms, 1e-10) // Avoid log(0)
    }
    
    private func isLikelySnore(samples: [Float], sampleRate: Float) -> Bool {
        // Perform FFT to analyze frequency content
        let fftSize = samples.count
        guard fftSize > 0 else { return false }
        
        // Simple frequency analysis
        // In a real implementation, you'd perform FFT here
        // For now, we'll use a simplified heuristic
        
        // Check for sustained volume (snoring is typically sustained)
        let sustainedFrames = samples.filter { abs($0) > 0.1 }.count
        let sustainedRatio = Float(sustainedFrames) / Float(samples.count)
        
        return sustainedRatio > 0.3 // At least 30% of frames are loud enough
    }
    
    private func handlePotentialSnore() {
        let now = Date()
        
        if currentSnoreStart == nil {
            // New snore detected
            currentSnoreStart = now
        }
        
        // Update last activity time
        lastSnoreEnd = now
    }
    
    private func endCurrentSnore() {
        guard let snoreStart = currentSnoreStart,
              let snoreEnd = lastSnoreEnd else {
            return
        }
        
        let duration = snoreEnd.timeIntervalSince(snoreStart)
        
        // Only count if duration is long enough
        if duration >= snoreDurationMin {
            let snore = SnoreEvent(timestamp: snoreStart, duration: duration)
            detectedSnores.append(snore)
            snoreCount += 1
            
            // Notify callback
            onSnoreDetected?(snoreStart, duration)
            
            print("😴 Snore detected: \(String(format: "%.1f", duration))s")
        }
        
        // Reset
        currentSnoreStart = nil
        lastSnoreEnd = nil
    }
}

// MARK: - Supporting Types

struct SnoreEvent: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let duration: TimeInterval // seconds
    
    init(id: UUID = UUID(), timestamp: Date, duration: TimeInterval) {
        self.id = id
        self.timestamp = timestamp
        self.duration = duration
    }
}

struct SnoreMetrics {
    let totalSnores: Int
    let totalSnoreDuration: TimeInterval
    let averageSnoreDuration: TimeInterval
    let longestSnore: TimeInterval
    let snoresPerHour: Double
    
    var severityLevel: SnoreSeverity {
        if snoresPerHour < 5 {
            return .none
        } else if snoresPerHour < 15 {
            return .mild
        } else if snoresPerHour < 30 {
            return .moderate
        } else {
            return .severe
        }
    }
}

enum SnoreSeverity: String {
    case none = "No Snoring"
    case mild = "Mild Snoring"
    case moderate = "Moderate Snoring"
    case severe = "Severe Snoring"
    
    var color: String {
        switch self {
        case .none: return "green"
        case .mild: return "yellow"
        case .moderate: return "orange"
        case .severe: return "red"
        }
    }
    
    var recommendation: String {
        switch self {
        case .none:
            return "Great! No significant snoring detected."
        case .mild:
            return "Some snoring detected. Try sleeping on your side."
        case .moderate:
            return "Moderate snoring. Consider nasal strips or consulting a doctor."
        case .severe:
            return "Severe snoring detected. Consult a healthcare provider about sleep apnea."
        }
    }
}

enum SnoreDetectionError: LocalizedError {
    case audioEngineSetupFailed
    case inputNodeNotAvailable
    case microphonePermissionDenied
    
    var errorDescription: String? {
        switch self {
        case .audioEngineSetupFailed:
            return "Failed to set up audio engine for snore detection"
        case .inputNodeNotAvailable:
            return "Microphone input not available"
        case .microphonePermissionDenied:
            return "Microphone permission is required for snore detection"
        }
    }
}
