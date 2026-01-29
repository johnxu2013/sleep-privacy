//
//  CloudSyncStatusView.swift
//  sleep-health
//
//  Created by Assistant on 1/28/26.
//

import SwiftUI
import CloudKit

// MARK: - Environment Key

private struct CloudSyncStatusKey: EnvironmentKey {
    static let defaultValue = CloudSyncStatus()
}

extension EnvironmentValues {
    var cloudSyncStatus: CloudSyncStatus {
        get { self[CloudSyncStatusKey.self] }
        set { self[CloudSyncStatusKey.self] = newValue }
    }
}

// MARK: - Views

/// Displays current iCloud sync status with visual indicators
struct CloudSyncStatusView: View {
    @Bindable var syncStatus: CloudSyncStatus
    @State private var showingErrorDetails = false
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: statusIcon)
                .foregroundStyle(syncStatus.statusColor)
                .imageScale(.small)
                .symbolEffect(.variableColor.iterative, isActive: syncStatus.isSyncing)
            
            Text(syncStatus.statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            if syncStatus.currentError != nil {
                Button {
                    showingErrorDetails = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .cloudKitErrorAlert(error: Binding(
            get: { showingErrorDetails ? syncStatus.currentError : nil },
            set: { _ in showingErrorDetails = false }
        )) {
            if syncStatus.errorType?.isRecoverable == true {
                syncStatus.clearError()
            }
        }
    }
    
    private var statusIcon: String {
        if let errorType = syncStatus.errorType {
            return errorType.systemImage
        } else if syncStatus.isSyncing {
            return "arrow.triangle.2.circlepath"
        } else {
            return "icloud"
        }
    }
}

/// Compact badge showing only sync status icon
struct CloudSyncBadge: View {
    @Bindable var syncStatus: CloudSyncStatus
    
    var body: some View {
        Image(systemName: statusIcon)
            .foregroundStyle(syncStatus.statusColor)
            .symbolEffect(.variableColor.iterative, isActive: syncStatus.isSyncing)
    }
    
    private var statusIcon: String {
        if let errorType = syncStatus.errorType {
            return errorType.systemImage
        } else if syncStatus.isSyncing {
            return "arrow.triangle.2.circlepath.icloud"
        } else {
            return "icloud.and.arrow.up"
        }
    }
}

// MARK: - Previews

#Preview("Normal Status") {
    CloudSyncStatusView(syncStatus: CloudSyncStatus())
        .padding()
}

#Preview("Syncing") {
    let status = CloudSyncStatus()
    status.isSyncing = true
    return CloudSyncStatusView(syncStatus: status)
        .padding()
}

#Preview("Quota Error") {
    let status = CloudSyncStatus()
    status.handleError(NSError(domain: CKErrorDomain, code: CKError.quotaExceeded.rawValue))
    return CloudSyncStatusView(syncStatus: status)
        .padding()
}

