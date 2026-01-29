//
//  CloudKitMonitor.swift
//  sleep-health
//
//  Created by Assistant on 1/28/26.
//

import Foundation
import SwiftUI
import Combine
import CloudKit

/// Monitors CloudKit sync events and updates status
@MainActor
class CloudKitMonitor: ObservableObject {
    @Published var syncStatus = CloudSyncStatus()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupMonitoring()
    }
    
    private func setupMonitoring() {
        // Listen for CloudKit error notifications
        NotificationCenter.default.publisher(
            for: NSNotification.Name("NSPersistentStoreRemoteChangeNotification")
        )
        .sink { [weak self] notification in
            guard let self = self else { return }
            
            // Check for errors in the notification
            if let error = notification.userInfo?["NSPersistentCloudKitContainer.event"] as? Error {
                self.syncStatus.handleError(error)
            }
        }
        .store(in: &cancellables)
        
        // Monitor import/export events
        NotificationCenter.default.publisher(
            for: NSNotification.Name("NSPersistentCloudKitContainer.eventChangedNotification")
        )
        .sink { [weak self] notification in
            guard let self = self else { return }
            
            // Parse the event if available
            if let error = notification.userInfo?["error"] as? Error {
                self.syncStatus.handleError(error)
                print("⚠️ CloudKit error: \(error.localizedDescription)")
            }
        }
        .store(in: &cancellables)
    }
}
