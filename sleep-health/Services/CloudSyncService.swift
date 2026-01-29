//
//  CloudSyncService.swift
//  sleep-health
//
//  Created by John Xu on 1/27/26.
//

import Foundation
import CloudKit
import Combine

/// Manages syncing sleep data to iCloud
class CloudSyncService: ObservableObject {
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: Error?
    
    private let container: CKContainer
    private let database: CKDatabase
    
    init() {
        // Match the container identifier used in SwiftData configuration
        container = CKContainer(identifier: "iCloud.com.sleephealth")
        database = container.privateCloudDatabase
    }
    
    // MARK: - Public Interface
    
    func checkAccountStatus() async -> Bool {
        do {
            let status = try await container.accountStatus()
            return status == .available
        } catch {
            print("⚠️ Failed to check iCloud status: \(error)")
            return false
        }
    }
    
    func syncSession(_ session: SleepSession) async throws {
        guard await checkAccountStatus() else {
            throw CloudSyncError.accountNotAvailable
        }
        
        isSyncing = true
        defer { isSyncing = false }
        
        do {
            let record = try convertToCloudKitRecord(session)
            let _ = try await database.save(record)
            
            lastSyncDate = Date()
            syncError = nil
        } catch {
            syncError = error
            throw error
        }
    }
    
    func syncMultipleSessions(_ sessions: [SleepSession]) async throws {
        guard await checkAccountStatus() else {
            throw CloudSyncError.accountNotAvailable
        }
        
        isSyncing = true
        defer { isSyncing = false }
        
        do {
            let records = try sessions.map { try convertToCloudKitRecord($0) }
            
            // Batch save for efficiency
            let operation = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
            operation.savePolicy = .changedKeys
            
            let result = try await database.modifyRecords(
                saving: records,
                deleting: [],
                savePolicy: .changedKeys
            )
            
            lastSyncDate = Date()
            syncError = nil
            
            print("✅ Synced \(result.saveResults.count) sessions to iCloud")
        } catch {
            syncError = error
            throw error
        }
    }
    
    func fetchSessions(from startDate: Date) async throws -> [SleepSession] {
        guard await checkAccountStatus() else {
            throw CloudSyncError.accountNotAvailable
        }
        
        let predicate = NSPredicate(format: "startTime >= %@", startDate as NSDate)
        let query = CKQuery(recordType: "SleepSession", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: false)]
        
        let results = try await database.records(matching: query)
        
        return try results.matchResults.compactMap { _, result in
            switch result {
            case .success(let record):
                return try convertFromCloudKitRecord(record)
            case .failure(let error):
                print("⚠️ Failed to fetch record: \(error)")
                return nil
            }
        }
    }
    
    // MARK: - CloudKit Conversion
    
    private func convertToCloudKitRecord(_ session: SleepSession) throws -> CKRecord {
        let recordID = CKRecord.ID(recordName: session.id.uuidString)
        let record = CKRecord(recordType: "SleepSession", recordID: recordID)
        
        record["startTime"] = session.startTime
        record["endTime"] = session.endTime
        record["targetWakeTime"] = session.targetWakeTime
        record["smartAlarmWindow"] = session.smartAlarmWindow
        record["actualWakeTime"] = session.actualWakeTime
        record["isAlarmTriggered"] = session.isAlarmTriggered ? 1 : 0
        record["totalSleepDuration"] = session.totalSleepDuration
        record["sleepEfficiency"] = session.sleepEfficiency
        record["numberOfAwakenings"] = session.numberOfAwakenings
        record["restlessnessScore"] = session.restlessnessScore
        
        // Encode complex data as JSON
        let stagesData = try JSONEncoder().encode((session.sleepStages ?? []).map { stage in
            CloudKitSleepStageData(
                id: stage.id.uuidString,
                startTime: stage.startTime,
                endTime: stage.endTime,
                stage: stage.stage.rawValue
            )
        })
        record["sleepStages"] = String(data: stagesData, encoding: .utf8)
        
        return record
    }
    
    private func convertFromCloudKitRecord(_ record: CKRecord) throws -> SleepSession {
        guard let startTime = record["startTime"] as? Date else {
            throw CloudSyncError.invalidRecord
        }
        
        // Extract ID from record name
        let idString = record.recordID.recordName
        let id = UUID(uuidString: idString) ?? UUID()
        
        let session = SleepSession(startTime: startTime)
        session.id = id
        session.endTime = record["endTime"] as? Date
        session.targetWakeTime = record["targetWakeTime"] as? Date
        session.smartAlarmWindow = record["smartAlarmWindow"] as? TimeInterval ?? 1800
        session.actualWakeTime = record["actualWakeTime"] as? Date
        session.isAlarmTriggered = (record["isAlarmTriggered"] as? Int ?? 0) == 1
        session.totalSleepDuration = record["totalSleepDuration"] as? TimeInterval ?? 0
        session.sleepEfficiency = record["sleepEfficiency"] as? Double ?? 0
        session.numberOfAwakenings = record["numberOfAwakenings"] as? Int ?? 0
        session.restlessnessScore = record["restlessnessScore"] as? Double ?? 0
        
        // Decode sleep stages
        if let stagesString = record["sleepStages"] as? String,
           let stagesData = stagesString.data(using: .utf8) {
            let stages = try JSONDecoder().decode([CloudKitSleepStageData].self, from: stagesData)
            session.sleepStages = stages.map { data in
                let stage = SleepStage(
                    startTime: data.startTime,
                    endTime: data.endTime,
                    stage: SleepStage.Stage(rawValue: data.stage) ?? .light
                )
                // Restore the ID if possible
                if let uuid = UUID(uuidString: data.id) {
                    stage.id = uuid
                }
                return stage
            }
        }
        
        return session
    }
}

// MARK: - Supporting Types

private struct CloudKitSleepStageData: Codable {
    let id: String
    let startTime: Date
    let endTime: Date
    let stage: String
}

enum CloudSyncError: LocalizedError {
    case accountNotAvailable
    case invalidRecord
    case syncFailed
    
    var errorDescription: String? {
        switch self {
        case .accountNotAvailable:
            return "iCloud account is not available. Please sign in to iCloud in Settings."
        case .invalidRecord:
            return "Invalid CloudKit record format"
        case .syncFailed:
            return "Failed to sync data to iCloud"
        }
    }
}
