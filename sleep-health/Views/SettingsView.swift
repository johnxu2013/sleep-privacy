//
//  SettingsView.swift
//  sleep-health
//
//  Created by John Xu on 1/27/26.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var controller: SleepTrackingController
    @State private var showingHealthKitAuth = false
    @State private var showingSyncStatus = false
    
    var body: some View {
        NavigationStack {
            Form {
                // Integrations section
                Section {
                    Button {
                        Task {
                            await requestHealthKitPermission()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "heart.fill")
                                .foregroundStyle(.red)
                            Text("Apple Health Integration")
                            
                            Spacer()
                            
                            Image(systemName: "arrow.right")
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Button {
                        showingSyncStatus = true
                    } label: {
                        HStack {
                            Image(systemName: "icloud.fill")
                                .foregroundStyle(.blue)
                            Text("iCloud Sync")
                            
                            Spacer()
                            
                            if let lastSync = controller.cloudSyncService.lastSyncDate {
                                Text(lastSync.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Image(systemName: "arrow.right")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Integrations")
                }
                
                // Data management section
                Section {
                    NavigationLink {
                        DataManagementView(controller: controller)
                    } label: {
                        HStack {
                            Image(systemName: "chart.bar.doc.horizontal")
                            Text("Data Management")
                        }
                    }
                    
                    Button {
                        controller.loadRecentSessions()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Refresh Data")
                        }
                    }
                } header: {
                    Text("Data")
                }
                
                // About section
                Section {
                    HStack {
                        Text("App Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                    
                    Link(destination: URL(string: "https://support.apple.com/health")!) {
                        HStack {
                            Text("Health Privacy")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingSyncStatus) {
                SyncStatusView(controller: controller)
            }
        }
    }
    
    private func requestHealthKitPermission() async {
        _ = await controller.requestAllPermissions()
    }
}

// MARK: - Sync Status View

struct SyncStatusView: View {
    @ObservedObject var controller: SleepTrackingController
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    if controller.cloudSyncService.isSyncing {
                        HStack {
                            ProgressView()
                            Text("Syncing...")
                                .padding(.leading)
                        }
                    } else {
                        Button {
                            Task {
                                await controller.syncAllToCloud()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "icloud.and.arrow.up")
                                Text("Sync Now")
                            }
                        }
                    }
                } header: {
                    Text("Cloud Sync")
                }
                
                Section {
                    if let lastSync = controller.cloudSyncService.lastSyncDate {
                        HStack {
                            Text("Last Sync")
                            Spacer()
                            Text(lastSync.formatted(date: .abbreviated, time: .shortened))
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Never synced")
                            .foregroundStyle(.secondary)
                    }
                    
                    if let error = controller.cloudSyncService.syncError {
                        Text("Error: \(error.localizedDescription)")
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                } header: {
                    Text("Status")
                }
                
                Section {
                    let syncedCount = controller.recentSessions.filter { $0.lastSyncedToCloud != nil }.count
                    let totalCount = controller.recentSessions.count
                    
                    HStack {
                        Text("Synced Sessions")
                        Spacer()
                        Text("\(syncedCount) / \(totalCount)")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Statistics")
                }
            }
            .navigationTitle("iCloud Sync")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Data Management View

struct DataManagementView: View {
    @ObservedObject var controller: SleepTrackingController
    @State private var showingDeleteAlert = false
    
    var body: some View {
        List {
            Section {
                HStack {
                    Text("Total Sessions")
                    Spacer()
                    Text("\(controller.recentSessions.count)")
                        .foregroundStyle(.secondary)
                }
                
                HStack {
                    Text("Synced to Health")
                    Spacer()
                    Text("\(controller.recentSessions.filter { $0.syncedToHealthKit }.count)")
                        .foregroundStyle(.secondary)
                }
                
                HStack {
                    Text("Synced to iCloud")
                    Spacer()
                    Text("\(controller.recentSessions.filter { $0.lastSyncedToCloud != nil }.count)")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Statistics")
            }
            
            Section {
                Button(role: .destructive) {
                    showingDeleteAlert = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete All Sleep Data")
                    }
                }
            } header: {
                Text("Data Management")
            } footer: {
                Text("This will permanently delete all sleep sessions from this device. Data synced to iCloud and Apple Health will not be affected.")
            }
        }
        .navigationTitle("Data Management")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Delete All Sleep Data?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                controller.deleteAllSessions()
            }
        } message: {
            Text("This action cannot be undone. Your local sleep data will be permanently deleted.")
        }
    }
}
