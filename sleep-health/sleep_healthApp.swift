//
//  sleep_healthApp.swift
//  sleep-health
//
//  Created by John Xu on 1/27/26.
//

import SwiftUI
import SwiftData

@main
struct sleep_healthApp: App {
    @State private var container: ModelContainer?
    @State private var error: Error?
    @StateObject private var cloudKitMonitor = CloudKitMonitor()
    
    init() {
        do {
            // Configure SwiftData model container
            let schema = Schema([
                SleepSession.self,
                MovementSample.self,
                SoundSample.self,
                SleepStage.self,
                SnoreSample.self
            ])
            
            // Use in-memory storage for simulator to avoid CloudKit issues
            #if targetEnvironment(simulator)
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            #else
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .private("iCloud.com.sleephealth")
            )
            #endif
            
            let tempContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
            _container = State(initialValue: tempContainer)
        } catch {
            print("❌ Failed to create ModelContainer: \(error)")
            _error = State(initialValue: error)
        }
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if let container = container {
                    ContentView(modelContext: container.mainContext)
                        .modelContainer(container)
                        .environmentObject(cloudKitMonitor)
                        .environment(\.cloudSyncStatus, cloudKitMonitor.syncStatus)
                } else if let error = error {
                    ErrorView(error: error)
                } else {
                    ProgressView("Loading...")
                }
            }
        }
    }
}
// MARK: - Error View

struct ErrorView: View {
    let error: Error
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.red)
            
            Text("Initialization Error")
                .font(.title)
                .fontWeight(.bold)
            
            Text(error.localizedDescription)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding()
            
            Button("Restart App") {
                exit(0)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

