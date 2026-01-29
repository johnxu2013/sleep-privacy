//
//  ContentView.swift
//  sleep-health
//
//  Created by John Xu on 1/27/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @StateObject private var controller: SleepTrackingController
    @State private var selectedTab = 0
    @EnvironmentObject private var cloudKitMonitor: CloudKitMonitor
    
    init(modelContext: ModelContext) {
        _controller = StateObject(wrappedValue: SleepTrackingController(modelContext: modelContext))
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Tonight Tab - Main tracking interface
            TonightView(controller: controller)
                .tabItem {
                    Label("Tonight", systemImage: "moon.stars.fill")
                }
                .tag(0)
            
            // History Tab - Browse past sessions
            HistoryView(controller: controller)
                .tabItem {
                    Label("History", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(1)
            
            // Trends Tab - Long-term analysis
            TrendsView(controller: controller)
                .tabItem {
                    Label("Trends", systemImage: "chart.bar.fill")
                }
                .tag(2)
            
            // Settings Tab
            SettingsView(controller: controller)
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(3)
        }
        .safeAreaInset(edge: .bottom) {
            if cloudKitMonitor.syncStatus.currentError != nil {
                CloudSyncStatusView(syncStatus: cloudKitMonitor.syncStatus)
                    .padding(8)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal)
                    .padding(.bottom, 4)
            }
        }
        .task {
            // Request permissions on first launch
            await controller.requestAllPermissions()
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: SleepSession.self, configurations: config)
    
    ContentView(modelContext: container.mainContext)
        .environmentObject(CloudKitMonitor())
}
