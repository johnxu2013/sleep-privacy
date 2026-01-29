//
//  HistoryView.swift
//  sleep-health
//
//  Created by John Xu on 1/27/26.
//

import SwiftUI
import SwiftData
import Charts

// Extension to make UUID work with sheet(item:)
extension UUID: @retroactive Identifiable {
    public var id: UUID { self }
}

struct HistoryView: View {
    @ObservedObject var controller: SleepTrackingController
    @State private var selectedSessionID: UUID?
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        NavigationStack {
            List {
                if controller.recentSessions.isEmpty {
                    emptyStateView
                } else {
                    ForEach(controller.recentSessions, id: \.id) { session in
                        Button {
                            selectedSessionID = session.id
                        } label: {
                            SleepSessionRow(session: session)
                        }
                    }
                }
            }
            .navigationTitle("Sleep History")
            .refreshable {
                controller.loadRecentSessions()
            }
            .sheet(item: $selectedSessionID) { sessionID in
                // Create a new detail view that fetches its own session
                SleepSessionDetailWrapper(sessionID: sessionID)
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "moon.zzz")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("No Sleep Data Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Start tracking your sleep to see your history here")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}

// MARK: - Session Row

struct SleepSessionRow: View {
    let session: SleepSession
    
    var body: some View {
        HStack(spacing: 16) {
            // Date badge
            VStack(spacing: 4) {
                Text(session.startTime.formatted(.dateTime.month(.abbreviated)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text(session.startTime.formatted(.dateTime.day()))
                    .font(.title2)
                    .fontWeight(.bold)
            }
            .frame(width: 50)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(session.startTime.formatted(.dateTime.weekday(.wide)))
                        .font(.headline)
                    
                    Spacer()
                    
                    if session.syncedToHealthKit {
                        Image(systemName: "heart.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    
                    if session.lastSyncedToCloud != nil {
                        Image(systemName: "icloud.fill")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }
                
                HStack(spacing: 16) {
                    Label(formatDuration(session.totalSleepDuration), systemImage: "bed.double.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    if session.sleepEfficiency > 0 {
                        Label("\(Int(session.sleepEfficiency))%", systemImage: "chart.bar.fill")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Quality indicator
                if session.sleepEfficiency > 0 {
                    HStack(spacing: 4) {
                        ForEach(0..<5) { index in
                            Image(systemName: index < qualityStars ? "star.fill" : "star")
                                .font(.caption2)
                                .foregroundStyle(.yellow)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private var qualityStars: Int {
        let efficiency = session.sleepEfficiency
        if efficiency >= 90 { return 5 }
        if efficiency >= 80 { return 4 }
        if efficiency >= 70 { return 3 }
        if efficiency >= 60 { return 2 }
        return 1
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
}

// MARK: - Session Detail Wrapper

/// Wrapper that fetches the session in its own context to avoid concurrency issues
struct SleepSessionDetailWrapper: View {
    let sessionID: UUID
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: SessionDetailViewModel?
    
    var body: some View {
        Group {
            if let viewModel = viewModel {
                SleepSessionDetailView(viewModel: viewModel)
            } else {
                ProgressView("Loading...")
                    .onAppear {
                        loadSession()
                    }
            }
        }
    }
    
    private func loadSession() {
        // Fetch the session from this view's model context
        let descriptor = FetchDescriptor<SleepSession>(
            predicate: #Predicate { $0.id == sessionID }
        )
        
        do {
            let sessions = try modelContext.fetch(descriptor)
            if let session = sessions.first {
                // Convert to value type immediately to avoid concurrency issues
                viewModel = SessionDetailViewModel(from: session)
            }
        } catch {
            print("⚠️ Failed to fetch session: \(error)")
        }
    }
}

// MARK: - View Model (Value Type)

struct SessionDetailViewModel {
    let id: UUID
    let startTime: Date
    let endTime: Date?
    let targetWakeTime: Date?
    let actualWakeTime: Date?
    let totalSleepDuration: TimeInterval
    let sleepEfficiency: Double
    let numberOfAwakenings: Int
    let restlessnessScore: Double
    let syncedToHealthKit: Bool
    let lastSyncedToCloud: Date?
    
    // Snoring data
    let totalSnores: Int
    let totalSnoreDuration: TimeInterval
    let snoresPerHour: Double
    
    // Copy relationship data as value types
    let sleepStages: [SleepStageData]
    let movementSamples: [MovementSampleData]
    let soundSamples: [SoundSampleData]
    
    init(from session: SleepSession) {
        self.id = session.id
        self.startTime = session.startTime
        self.endTime = session.endTime
        self.targetWakeTime = session.targetWakeTime
        self.actualWakeTime = session.actualWakeTime
        self.totalSleepDuration = session.totalSleepDuration
        self.sleepEfficiency = session.sleepEfficiency
        self.numberOfAwakenings = session.numberOfAwakenings
        self.restlessnessScore = session.restlessnessScore
        self.syncedToHealthKit = session.syncedToHealthKit
        self.lastSyncedToCloud = session.lastSyncedToCloud
        
        // Snoring metrics
        self.totalSnores = session.totalSnores
        self.totalSnoreDuration = session.totalSnoreDuration
        self.snoresPerHour = session.snoresPerHour
        
        // ⚠️ TEMPORARY FIX: Don't access relationships (causes freeze due to SwiftData bidirectional refs)
        // TODO: Fix by loading relationships on background thread or removing bidirectional relationships
        print("⚠️ Skipping relationship loading to prevent freeze")
        self.sleepStages = []
        self.movementSamples = []
        self.soundSamples = []
        
        /* COMMENTED OUT - CAUSES FREEZE ON DEVICES:
        // Copy relationships to value types
        self.sleepStages = (session.sleepStages ?? []).map { stage in
            SleepStageData(
                id: stage.id,
                startTime: stage.startTime,
                endTime: stage.endTime,
                stage: stage.stage.rawValue
            )
        }
        
        self.movementSamples = (session.movementSamples ?? []).map { sample in
            MovementSampleData(
                id: sample.id,
                timestamp: sample.timestamp,
                intensity: sample.intensity
            )
        }
        
        self.soundSamples = (session.soundSamples ?? []).map { sample in
            SoundSampleData(
                id: sample.id,
                timestamp: sample.timestamp,
                decibelLevel: sample.decibelLevel
            )
        }
        */
    }
}

// Value types for chart data
struct SleepStageData: Identifiable {
    let id: UUID
    let startTime: Date
    let endTime: Date
    let stage: String
    
    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }
}

struct MovementSampleData: Identifiable {
    let id: UUID
    let timestamp: Date
    let intensity: Double
}

struct SoundSampleData: Identifiable {
    let id: UUID
    let timestamp: Date
    let decibelLevel: Double
}

// MARK: - Session Detail View

struct SleepSessionDetailView: View {
    let viewModel: SessionDetailViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header summary
                    summarySection
                    
                    // Key metrics
                    metricsGrid
                    
                    // Temporary message about charts
                    VStack(spacing: 12) {
                        Image(systemName: "chart.xyaxis.line")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        
                        Text("Detailed Charts Temporarily Unavailable")
                            .font(.headline)
                        
                        Text("Sleep stage, movement, and sound charts are temporarily disabled while we fix a technical issue. Your sleep quality metrics (including snore detection) are still accurate!")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    
                    /* TEMPORARILY DISABLED - Charts cause freeze:
                    // Sleep stages chart
                    if !viewModel.sleepStages.isEmpty {
                        sleepStagesChart
                    }
                    
                    // Movement and sound charts
                    if !viewModel.movementSamples.isEmpty {
                        movementChart
                    }
                    
                    if !viewModel.soundSamples.isEmpty {
                        soundChart
                    }
                    */
                }
                .padding()
            }
            .navigationTitle("Sleep Details")
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
    
    // MARK: - Summary Section
    
    private var summarySection: some View {
        VStack(spacing: 16) {
            Text(viewModel.startTime.formatted(date: .long, time: .omitted))
                .font(.headline)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 40) {
                VStack(spacing: 8) {
                    Text(formatTime(viewModel.startTime))
                        .font(.title)
                        .fontWeight(.bold)
                    Text("Bedtime")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)
                
                VStack(spacing: 8) {
                    Text(viewModel.endTime.map(formatTime) ?? "--:--")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("Wake Time")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            if viewModel.sleepEfficiency > 0 {
                SleepQualityBadge(efficiency: viewModel.sleepEfficiency)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Sleep Stages Chart
    
    private var sleepStagesChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sleep Stages")
                .font(.headline)
            
            Chart(viewModel.sleepStages, id: \.id) { stage in
                RectangleMark(
                    xStart: .value("Start", stage.startTime),
                    xEnd: .value("End", stage.endTime),
                    y: .value("Stage", stage.stage)
                )
                .foregroundStyle(by: .value("Stage", stage.stage))
            }
            .chartYAxis {
                AxisMarks(values: ["awake", "light", "deep", "rem"]) { value in
                    AxisValueLabel {
                        if let stage = value.as(String.self) {
                            Text(stage.capitalized)
                                .font(.caption)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour)) { _ in
                    AxisValueLabel(format: .dateTime.hour())
                }
            }
            .chartForegroundStyleScale([
                "awake": .red,
                "light": .blue,
                "deep": .purple,
                "rem": .green
            ])
            .frame(height: 200)
            
            // Legend
            HStack(spacing: 20) {
                LegendItem(color: .red, label: "Awake")
                LegendItem(color: .blue, label: "Light")
                LegendItem(color: .purple, label: "Deep")
                LegendItem(color: .green, label: "REM")
            }
            .font(.caption)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Metrics Grid
    
    private var metricsGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Key Metrics")
                .font(.headline)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                MetricBox(
                    icon: "bed.double.fill",
                    title: "Total Sleep",
                    value: formatDuration(viewModel.totalSleepDuration),
                    color: .blue
                )
                
                MetricBox(
                    icon: "chart.bar.fill",
                    title: "Efficiency",
                    value: "\(Int(viewModel.sleepEfficiency))%",
                    color: .green
                )
                
                MetricBox(
                    icon: "moon.stars.fill",
                    title: "Deep Sleep",
                    value: formatDuration(viewModel.sleepStages.filter { $0.stage == "deep" }.map(\.duration).reduce(0, +)),
                    color: .purple
                )
                
                MetricBox(
                    icon: "brain.head.profile",
                    title: "REM Sleep",
                    value: formatDuration(viewModel.sleepStages.filter { $0.stage == "rem" }.map(\.duration).reduce(0, +)),
                    color: .orange
                )
                
                MetricBox(
                    icon: "exclamationmark.circle.fill",
                    title: "Awakenings",
                    value: "\(viewModel.numberOfAwakenings)",
                    color: .red
                )
                
                MetricBox(
                    icon: "figure.walk",
                    title: "Restlessness",
                    value: "\(Int(viewModel.restlessnessScore))/100",
                    color: .yellow
                )
                
                // Snoring metrics
                if viewModel.totalSnores > 0 {
                    MetricBox(
                        icon: "waveform",
                        title: "Snores",
                        value: "\(viewModel.totalSnores)",
                        color: .pink
                    )
                    
                    MetricBox(
                        icon: "clock.badge.exclamationmark",
                        title: "Snore Duration",
                        value: formatDuration(viewModel.totalSnoreDuration),
                        color: .pink
                    )
                }
            }
            
            // Snore severity badge (if snoring detected)
            if viewModel.totalSnores > 0 {
                snoreSeverityBadge
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var snoreSeverityBadge: some View {
        let severity = getSnoreSeverity(snoresPerHour: viewModel.snoresPerHour)
        
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "speaker.wave.3.fill")
                    .foregroundStyle(severity.color)
                Text("Snoring Analysis")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            
            Text(severity.level)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(severity.color)
            
            Text(severity.recommendation)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(severity.color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func getSnoreSeverity(snoresPerHour: Double) -> (level: String, color: Color, recommendation: String) {
        if snoresPerHour < 5 {
            return ("No Snoring", .green, "Great! No significant snoring detected.")
        } else if snoresPerHour < 15 {
            return ("Mild Snoring", .yellow, "Some snoring detected. Try sleeping on your side.")
        } else if snoresPerHour < 30 {
            return ("Moderate Snoring", .orange, "Moderate snoring. Consider nasal strips or consulting a doctor.")
        } else {
            return ("Severe Snoring", .red, "Severe snoring detected. Consult a healthcare provider about sleep apnea.")
        }
    }
    
    // MARK: - Movement Chart
    
    private var movementChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Movement Activity")
                .font(.headline)
            
            Chart(viewModel.movementSamples.prefix(100), id: \.id) { sample in
                LineMark(
                    x: .value("Time", sample.timestamp),
                    y: .value("Intensity", sample.intensity)
                )
                .foregroundStyle(.blue.gradient)
            }
            .chartYScale(domain: 0...1)
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour)) { _ in
                    AxisValueLabel(format: .dateTime.hour())
                }
            }
            .frame(height: 150)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Sound Chart
    
    private var soundChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ambient Sound")
                .font(.headline)
            
            Chart(viewModel.soundSamples.prefix(100), id: \.id) { sample in
                LineMark(
                    x: .value("Time", sample.timestamp),
                    y: .value("Level", sample.decibelLevel)
                )
                .foregroundStyle(.green.gradient)
            }
            .chartYScale(domain: 0...100)
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour)) { _ in
                    AxisValueLabel(format: .dateTime.hour())
                }
            }
            .frame(height: 150)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Helpers
    
    private func formatTime(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
}

// MARK: - Supporting Views

struct SleepQualityBadge: View {
    let efficiency: Double
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: qualityIcon)
                .foregroundStyle(qualityColor)
            
            Text(qualityText)
                .font(.headline)
                .foregroundStyle(qualityColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(qualityColor.opacity(0.2))
        .clipShape(Capsule())
    }
    
    private var qualityText: String {
        if efficiency >= 85 { return "Excellent Sleep" }
        if efficiency >= 75 { return "Good Sleep" }
        if efficiency >= 65 { return "Fair Sleep" }
        return "Poor Sleep"
    }
    
    private var qualityIcon: String {
        if efficiency >= 85 { return "star.fill" }
        if efficiency >= 75 { return "hand.thumbsup.fill" }
        if efficiency >= 65 { return "checkmark.circle.fill" }
        return "exclamationmark.triangle.fill"
    }
    
    private var qualityColor: Color {
        if efficiency >= 85 { return .green }
        if efficiency >= 75 { return .blue }
        if efficiency >= 65 { return .orange }
        return .red
    }
}

struct MetricBox: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct LegendItem: View {
    let color: Color
    let label: String
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
        }
    }
}
