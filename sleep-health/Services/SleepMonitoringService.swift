//
//  SleepMonitoringService.swift
//  sleep-health
//
//  Created by John Xu on 1/27/26.
//

import Foundation
import CoreMotion
import AVFoundation
import Combine

/// Manages sensor data collection during sleep tracking
@MainActor
class SleepMonitoringService: ObservableObject {
    @Published var isMonitoring = false
    @Published var currentMovementIntensity: Double = 0
    @Published var currentSoundLevel: Double = 0
    
    private let motionManager = CMMotionManager()
    private let audioEngine = AVAudioEngine()
    private var monitoringTask: Task<Void, Never>?
    
    // Callbacks for data collection
    var onMovementSample: ((Date, Double) -> Void)?
    var onSoundSample: ((Date, Double) -> Void)?
    
    // Configuration
    private let sampleInterval: TimeInterval = 30 // Sample every 30 seconds
    private let movementSensitivity: Double = 0.05
    
    init() {
        configureAudioSession()
    }
    
    deinit {
        // Clean up resources directly without going through main actor
        monitoringTask?.cancel()
        motionManager.stopAccelerometerUpdates()
        audioEngine.stop()
    }
    
    // MARK: - Public Interface
    
    func startMonitoring() {
        print("------ isMonitoring \(isMonitoring) -----")
        guard !isMonitoring else { return }
        
        print("------ 5a -----")
        
        isMonitoring = true
        startMotionTracking()
        
        print("------ 5b -----")
        startSoundTracking()
        
        print("------ 5c -----")
        
        monitoringTask = Task {
            await monitorSleepContinuously()
        }
    }
    
    func stopMonitoring() {
        isMonitoring = false
        monitoringTask?.cancel()
        monitoringTask = nil
        
        motionManager.stopAccelerometerUpdates()
        audioEngine.stop()
    }
    
    // MARK: - Motion Tracking
    
    private func startMotionTracking() {
        guard motionManager.isAccelerometerAvailable else {
            print("⚠️ Accelerometer not available")
            return
        }
        
        motionManager.accelerometerUpdateInterval = 1.0 / 10.0 // 10 Hz
        
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, error in
            guard let self = self, let data = data else { return }
            
            // Calculate movement intensity from acceleration
            let magnitude = sqrt(
                pow(data.acceleration.x, 2) +
                pow(data.acceleration.y, 2) +
                pow(data.acceleration.z, 2)
            )
            
            // Remove gravity (1g) and normalize
            let movement = abs(magnitude - 1.0)
            self.currentMovementIntensity = min(movement / self.movementSensitivity, 1.0)
        }
    }
    
    // MARK: - Sound Tracking
    
    private func configureAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement)
            try audioSession.setActive(true)
        } catch {
            print("⚠️ Failed to configure audio session: \(error)")
        }
    }
    
    private func startSoundTracking() {
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            guard let self = self else { return }
            let level = self.calculateSoundLevel(from: buffer)
            
            Task { @MainActor in
                self.currentSoundLevel = level
            }
        }
        
        print("---------5ab---------")
        
        print("---------5ab audioEngine : \(audioEngine) ---------")
        
        if !audioEngine.isRunning {
            do {
                try audioEngine.start()
                print("---------5ac---------")
            } catch {
                print("⚠️ Failed to start audio engine: \(error)")
            }
        }
    }
    
    private func calculateSoundLevel(from buffer: AVAudioPCMBuffer) -> Double {
        guard let channelData = buffer.floatChannelData?[0] else { return 0 }
        
        let frames = buffer.frameLength
        var sum: Float = 0
        
        for i in 0..<Int(frames) {
            sum += abs(channelData[i])
        }
        
        let average = sum / Float(frames)
        // Convert to approximate decibel level (simplified)
        let db = 20 * log10(average + 0.0001) + 160
        return max(0, min(Double(db), 100))
    }
    
    // MARK: - Continuous Monitoring Loop
    
    private func monitorSleepContinuously() async {
        while isMonitoring && !Task.isCancelled {
            // Record samples at regular intervals
            let timestamp = Date()
            
            await recordMovementSample(timestamp: timestamp)
            await recordSoundSample(timestamp: timestamp)
            
            // Wait for next sample interval
            try? await Task.sleep(for: .seconds(sampleInterval))
        }
    }
    
    private func recordMovementSample(timestamp: Date) async {
        let intensity = currentMovementIntensity
        onMovementSample?(timestamp, intensity)
    }
    
    private func recordSoundSample(timestamp: Date) async {
        let level = currentSoundLevel
        onSoundSample?(timestamp, level)
    }
    
    // MARK: - Permissions
    
    func requestPermissions() async -> Bool {
        // Request microphone permission
        let audioStatus = await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        
        // Motion data doesn't require explicit permission on iOS
        // but we should check availability
        let motionAvailable = motionManager.isAccelerometerAvailable
        
        return audioStatus && motionAvailable
    }
}
