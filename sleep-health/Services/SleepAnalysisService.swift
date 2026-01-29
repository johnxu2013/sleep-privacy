//
//  SleepAnalysisService.swift
//  sleep-health
//
//  Created by John Xu on 1/27/26.
//

import Foundation

/// Analyzes sleep data to estimate sleep stages and calculate metrics
class SleepAnalysisService {
    
    // MARK: - Sleep Stage Estimation
    
    /// Estimates sleep stages based on movement and sound data
    func estimateSleepStages(
        movementSamples: [MovementSample],
        soundSamples: [SoundSample],
        sessionStart: Date,
        sessionEnd: Date
    ) -> [SleepStage] {
        var stages: [SleepStage] = []
        
        // Group samples into time windows (5-minute intervals)
        let windowDuration: TimeInterval = 300 // 5 minutes
        var currentTime = sessionStart
        
        while currentTime < sessionEnd {
            let windowEnd = min(currentTime.addingTimeInterval(windowDuration), sessionEnd)
            
            let windowMovement = movementSamples.filter { sample in
                sample.timestamp >= currentTime && sample.timestamp < windowEnd
            }
            
            let windowSound = soundSamples.filter { sample in
                sample.timestamp >= currentTime && sample.timestamp < windowEnd
            }
            
            let stage = classifySleepStage(
                movementSamples: windowMovement,
                soundSamples: windowSound
            )
            
            stages.append(SleepStage(
                startTime: currentTime,
                endTime: windowEnd,
                stage: stage
            ))
            
            currentTime = windowEnd
        }
        
        // Smooth out rapid stage transitions
        return smoothStageTransitions(stages)
    }
    
    private func classifySleepStage(
        movementSamples: [MovementSample],
        soundSamples: [SoundSample]
    ) -> SleepStage.Stage {
        let avgMovement = movementSamples.map(\.intensity).reduce(0, +) / Double(max(movementSamples.count, 1))
        let avgSound = soundSamples.map(\.decibelLevel).reduce(0, +) / Double(max(soundSamples.count, 1))
        
        // Simple heuristic-based classification
        // In a production app, you'd use ML models trained on polysomnography data
        
        if avgMovement > 0.3 || avgSound > 50 {
            return .awake
        } else if avgMovement > 0.15 || avgSound > 40 {
            return .light
        } else if avgMovement < 0.05 && avgSound < 35 {
            return .deep
        } else {
            // REM sleep typically has low movement but some eye movement
            // This is a simplified estimation
            return .rem
        }
    }
    
    private func smoothStageTransitions(_ stages: [SleepStage]) -> [SleepStage] {
        guard stages.count > 2 else { return stages }
        
        var smoothed = stages
        
        // Remove single-window anomalies
        for i in 1..<(smoothed.count - 1) {
            if smoothed[i].stage != smoothed[i-1].stage &&
               smoothed[i].stage != smoothed[i+1].stage &&
               smoothed[i-1].stage == smoothed[i+1].stage {
                smoothed[i].stage = smoothed[i-1].stage
            }
        }
        
        return smoothed
    }
    
    // MARK: - Sleep Metrics Calculation
    
    func calculateSleepMetrics(
        session: SleepSession
    ) -> SleepMetrics {
        let stages = session.sleepStages ?? []
        
        let deepSleep = stages.filter { $0.stage == .deep }.map(\.duration).reduce(0, +)
        let remSleep = stages.filter { $0.stage == .rem }.map(\.duration).reduce(0, +)
        let lightSleep = stages.filter { $0.stage == .light }.map(\.duration).reduce(0, +)
        let awakeTime = stages.filter { $0.stage == .awake }.map(\.duration).reduce(0, +)
        
        let totalSleep = deepSleep + remSleep + lightSleep
        let timeInBed = session.timeInBed
        
        let efficiency = timeInBed > 0 ? (totalSleep / timeInBed) * 100 : 0
        
        let awakenings = countAwakenings(stages: stages)
        let restlessness = calculateRestlessness(movements: session.movementSamples ?? [])
        
        return SleepMetrics(
            totalSleepDuration: totalSleep,
            deepSleepDuration: deepSleep,
            remSleepDuration: remSleep,
            lightSleepDuration: lightSleep,
            awakeTime: awakeTime,
            sleepEfficiency: efficiency,
            numberOfAwakenings: awakenings,
            restlessnessScore: restlessness,
            timeToFallAsleep: calculateTimeToFallAsleep(stages: stages, sessionStart: session.startTime)
        )
    }
    
    private func countAwakenings(stages: [SleepStage]) -> Int {
        var count = 0
        var wasAsleep = false
        
        for stage in stages {
            if stage.stage == .awake && wasAsleep {
                count += 1
                wasAsleep = false
            } else if stage.stage != .awake {
                wasAsleep = true
            }
        }
        
        return count
    }
    
    private func calculateRestlessness(movements: [MovementSample]) -> Double {
        guard !movements.isEmpty else { return 0 }
        
        let totalIntensity = movements.map(\.intensity).reduce(0, +)
        let avgIntensity = totalIntensity / Double(movements.count)
        
        // Convert to 0-100 scale
        return min(avgIntensity * 100, 100)
    }
    
    private func calculateTimeToFallAsleep(stages: [SleepStage], sessionStart: Date) -> TimeInterval {
        // Find first non-awake stage
        guard let firstSleep = stages.first(where: { $0.stage != .awake }) else {
            return 0
        }
        return firstSleep.startTime.timeIntervalSince(sessionStart)
    }
    
    // MARK: - Smart Alarm Logic
    
    /// Finds the optimal wake time within the smart alarm window
    func findOptimalWakeTime(
        stages: [SleepStage],
        windowStart: Date,
        windowEnd: Date
    ) -> Date? {
        // Filter stages within the window
        let windowStages = stages.filter { stage in
            stage.startTime >= windowStart && stage.startTime <= windowEnd
        }
        
        // Look for light sleep or awake periods (best time to wake)
        for stage in windowStages {
            if stage.stage == .light || stage.stage == .awake {
                return stage.startTime
            }
        }
        
        // If no light sleep found, return the end of window
        return windowEnd
    }
}

// MARK: - Supporting Types

struct SleepMetrics {
    let totalSleepDuration: TimeInterval
    let deepSleepDuration: TimeInterval
    let remSleepDuration: TimeInterval
    let lightSleepDuration: TimeInterval
    let awakeTime: TimeInterval
    let sleepEfficiency: Double
    let numberOfAwakenings: Int
    let restlessnessScore: Double
    let timeToFallAsleep: TimeInterval
    
    var sleepQualityScore: Double {
        // Calculate overall quality score (0-100)
        let efficiencyScore = sleepEfficiency
        let deepSleepRatio = (deepSleepDuration / max(totalSleepDuration, 1)) * 100
        let awakeningPenalty = Double(max(0, 10 - numberOfAwakenings)) * 10
        let restfulnessScore = 100 - restlessnessScore
        
        return (efficiencyScore * 0.3 + deepSleepRatio * 0.3 + awakeningPenalty * 0.2 + restfulnessScore * 0.2)
    }
}
