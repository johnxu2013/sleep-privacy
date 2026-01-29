//
//  HealthKitService.swift
//  sleep-health
//
//  Created by John Xu on 1/27/26.
//

import Foundation
import HealthKit

/// Manages integration with Apple Health for sleep data
class HealthKitService {
    private let healthStore = HKHealthStore()
    
    // MARK: - Authorization
    
    func requestAuthorization() async throws -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.notAvailable
        }
        
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)
        
        var readTypes = Set<HKObjectType>()
        readTypes.insert(sleepType)
        if let heartRate = heartRateType {
            readTypes.insert(heartRate)
        }
        
        let writeTypes = Set<HKSampleType>([sleepType])
        
        try await healthStore.requestAuthorization(toShare: writeTypes, read: readTypes)
        
        return true
    }
    
    // MARK: - Writing Sleep Data
    
    func writeSleepSession(_ session: SleepSession) async throws {
        guard let endTime = session.endTime else {
            throw HealthKitError.sessionNotComplete
        }
        
        // Write overall sleep analysis
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        
        var samples: [HKCategorySample] = []
        
        // Add sleep stage samples
        for stage in session.sleepStages ?? [] {
            let value: Int
            
            switch stage.stage {
            case .awake:
                value = HKCategoryValueSleepAnalysis.awake.rawValue
            case .light:
                value = HKCategoryValueSleepAnalysis.asleepCore.rawValue
            case .deep:
                value = HKCategoryValueSleepAnalysis.asleepDeep.rawValue
            case .rem:
                value = HKCategoryValueSleepAnalysis.asleepREM.rawValue
            }
            
            let sample = HKCategorySample(
                type: sleepType,
                value: value,
                start: stage.startTime,
                end: stage.endTime
            )
            samples.append(sample)
        }
        
        // Add in-bed period
        let inBedSample = HKCategorySample(
            type: sleepType,
            value: HKCategoryValueSleepAnalysis.inBed.rawValue,
            start: session.startTime,
            end: endTime
        )
        samples.append(inBedSample)
        
        try await healthStore.save(samples)
    }
    
    // MARK: - Reading Sleep Data
    
    func fetchRecentSleepData(days: Int = 30) async throws -> [HKCategorySample] {
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictStartDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let sleepSamples = samples as? [HKCategorySample] ?? []
                continuation.resume(returning: sleepSamples)
            }
            
            healthStore.execute(query)
        }
    }
}

// MARK: - Errors

enum HealthKitError: LocalizedError {
    case notAvailable
    case sessionNotComplete
    case authorizationFailed
    
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Health data is not available on this device"
        case .sessionNotComplete:
            return "Sleep session must be complete before syncing"
        case .authorizationFailed:
            return "Failed to authorize HealthKit access"
        }
    }
}
