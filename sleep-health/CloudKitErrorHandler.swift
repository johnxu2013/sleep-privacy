//
//  CloudKitErrorHandler.swift
//  sleep-health
//
//  Created by Assistant on 1/28/26.
//

import Foundation
import CloudKit
import SwiftUI

/// Handles CloudKit errors and provides user-friendly messaging
struct CloudKitErrorHandler {
    
    enum CloudKitErrorType {
        case quotaExceeded
        case networkUnavailable
        case accountNotAvailable
        case serverError
        case unknownError
        
        var userMessage: String {
            switch self {
            case .quotaExceeded:
                return "Your iCloud storage is full. Please free up space in Settings > [Your Name] > iCloud > Manage Storage to continue syncing."
            case .networkUnavailable:
                return "Unable to connect to iCloud. Please check your internet connection."
            case .accountNotAvailable:
                return "iCloud is not available. Please sign in to iCloud in Settings."
            case .serverError:
                return "iCloud servers are experiencing issues. Please try again later."
            case .unknownError:
                return "An unknown error occurred with iCloud sync."
            }
        }
        
        var systemImage: String {
            switch self {
            case .quotaExceeded:
                return "externaldrive.fill.badge.exclamationmark"
            case .networkUnavailable:
                return "wifi.slash"
            case .accountNotAvailable:
                return "icloud.slash"
            case .serverError:
                return "exclamationmark.icloud"
            case .unknownError:
                return "exclamationmark.triangle"
            }
        }
        
        var isRecoverable: Bool {
            switch self {
            case .quotaExceeded, .accountNotAvailable:
                return false // Requires user action outside app
            case .networkUnavailable, .serverError:
                return true // May resolve on its own
            case .unknownError:
                return true
            }
        }
    }
    
    /// Analyzes a CloudKit error and returns a categorized error type
    static func categorize(_ error: Error) -> CloudKitErrorType {
        guard let ckError = error as? CKError else {
            return .unknownError
        }
        
        switch ckError.code {
        case .quotaExceeded:
            return .quotaExceeded
            
        case .networkUnavailable, .networkFailure:
            return .networkUnavailable
            
        case .notAuthenticated:
            return .accountNotAvailable
            
        case .serverResponseLost, .serviceUnavailable, .serverRejectedRequest:
            return .serverError
            
        case .partialFailure:
            // Check if any partial errors are quota exceeded
            if let partialErrors = ckError.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: Error] {
                for (_, partialError) in partialErrors {
                    if let partialCKError = partialError as? CKError,
                       partialCKError.code == .quotaExceeded {
                        return .quotaExceeded
                    }
                }
            }
            return .unknownError
            
        default:
            return .unknownError
        }
    }
    
    /// Extracts retry delay from CloudKit error, if available
    static func retryDelay(from error: Error) -> TimeInterval? {
        guard let ckError = error as? CKError else { return nil }
        
        if let retryAfter = ckError.userInfo[CKErrorRetryAfterKey] as? TimeInterval {
            return retryAfter
        }
        
        // Check partial errors for retry delays
        if let partialErrors = ckError.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: Error] {
            for (_, partialError) in partialErrors {
                if let partialCKError = partialError as? CKError,
                   let partialRetryAfter = partialCKError.userInfo[CKErrorRetryAfterKey] as? TimeInterval {
                    return partialRetryAfter
                }
            }
        }
        
        return nil
    }
}

// MARK: - SwiftUI Alert Extension

extension View {
    /// Shows an alert for CloudKit errors with appropriate messaging
    func cloudKitErrorAlert(
        error: Binding<Error?>,
        onDismiss: (() -> Void)? = nil
    ) -> some View {
        alert(
            "iCloud Sync Issue",
            isPresented: Binding(
                get: { error.wrappedValue != nil },
                set: { if !$0 { error.wrappedValue = nil } }
            ),
            presenting: error.wrappedValue
        ) { presentedError in
            let errorType = CloudKitErrorHandler.categorize(presentedError)
            
            Button("OK") {
                onDismiss?()
            }
            
            if case .quotaExceeded = errorType {
                Button("Open Settings") {
                    if let url = URL(string: "App-prefs:root=CASTLE") {
                        UIApplication.shared.open(url)
                    }
                    onDismiss?()
                }
            }
        } message: { presentedError in
            let errorType = CloudKitErrorHandler.categorize(presentedError)
            Text(errorType.userMessage)
        }
    }
}

// MARK: - Cloud Sync Status Model

@MainActor
@Observable
class CloudSyncStatus {
    var isSyncing: Bool = false
    var lastSyncDate: Date?
    var currentError: Error?
    var retryAfter: Date?
    
    var errorType: CloudKitErrorHandler.CloudKitErrorType? {
        guard let error = currentError else { return nil }
        return CloudKitErrorHandler.categorize(error)
    }
    
    var statusMessage: String {
        if let error = currentError {
            let errorType = CloudKitErrorHandler.categorize(error)
            
            if case .quotaExceeded = errorType {
                return "iCloud storage full"
            } else if let retryDate = retryAfter {
                let formatter = RelativeDateTimeFormatter()
                formatter.unitsStyle = .full
                let relativeTime = formatter.localizedString(for: retryDate, relativeTo: Date())
                return "Retry \(relativeTime)"
            } else {
                return "Sync error"
            }
        } else if isSyncing {
            return "Syncing..."
        } else if let lastSync = lastSyncDate {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            let relativeTime = formatter.localizedString(for: lastSync, relativeTo: Date())
            return "Last synced \(relativeTime)"
        } else {
            return "Not synced"
        }
    }
    
    var statusColor: Color {
        if currentError != nil {
            return .red
        } else if isSyncing {
            return .blue
        } else {
            return .green
        }
    }
    
    func handleError(_ error: Error) {
        self.currentError = error
        
        if let delay = CloudKitErrorHandler.retryDelay(from: error) {
            self.retryAfter = Date().addingTimeInterval(delay)
        }
        
        // Log for debugging
        let errorType = CloudKitErrorHandler.categorize(error)
        print("⚠️ CloudKit Error: \(errorType) - \(error.localizedDescription)")
    }
    
    func clearError() {
        self.currentError = nil
        self.retryAfter = nil
    }
}
