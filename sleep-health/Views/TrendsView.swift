//
//  TrendsView.swift
//  sleep-health
//
//  Created by John Xu on 1/27/26.
//

import SwiftUI
import Charts

struct TrendsView: View {
    @ObservedObject var controller: SleepTrackingController
    @State private var selectedPeriod: TimePeriod = .week
    
    enum TimePeriod: String, CaseIterable {
        case week = "7 Days"
        case twoWeeks = "14 Days"
        case month = "30 Days"
        
        var days: Int {
            switch self {
            case .week: return 7
            case .twoWeeks: return 14
            case .month: return 30
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Period picker
                    Picker("Time Period", selection: $selectedPeriod) {
                        ForEach(TimePeriod.allCases, id: \.self) { period in
                            Text(period.rawValue).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    // Average metrics summary
                    if let averages = controller.calculateAverageMetrics(days: selectedPeriod.days) {
                        averageMetricsSection(averages)
                    }
                    
                    // Duration trend chart
                    durationTrendChart
                    
                    // Efficiency trend chart
                    efficiencyTrendChart
                    
                    // Sleep stages distribution
                    sleepStagesDistribution
                    
                    // Awakenings trend
                    awakeningsTrendChart
                }
                .padding()
            }
            .navigationTitle("Sleep Trends")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task {
                            await controller.syncAllToCloud()
                        }
                    } label: {
                        Label("Sync to Cloud", systemImage: "icloud.and.arrow.up")
                    }
                }
            }
        }
    }
    
    // MARK: - Average Metrics Section
    
    private func averageMetricsSection(_ metrics: AverageSleepMetrics) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Average Metrics")
                    .font(.headline)
                
                Spacer()
                
                Text("\(metrics.numberOfNights) nights")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                AveragMetricCard(
                    icon: "bed.double.fill",
                    title: "Sleep Duration",
                    value: metrics.averageDurationFormatted,
                    color: .blue
                )
                
                AveragMetricCard(
                    icon: "chart.bar.fill",
                    title: "Efficiency",
                    value: "\(Int(metrics.averageEfficiency))%",
                    color: .green
                )
                
                AveragMetricCard(
                    icon: "exclamationmark.circle",
                    title: "Awakenings",
                    value: String(format: "%.1f", metrics.averageAwakenings),
                    color: .orange
                )
                
                AveragMetricCard(
                    icon: "figure.walk",
                    title: "Restlessness",
                    value: "\(Int(metrics.averageRestlessness))/100",
                    color: .purple
                )
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Duration Trend Chart
    
    private var durationTrendChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sleep Duration Trend")
                .font(.headline)
            
            if !sessionsForPeriod.isEmpty {
                Chart(sessionsForPeriod, id: \.id) { session in
                    LineMark(
                        x: .value("Date", session.startTime),
                        y: .value("Duration", session.totalSleepDuration / 3600)
                    )
                    .foregroundStyle(.blue.gradient)
                    .interpolationMethod(.catmullRom)
                    
                    AreaMark(
                        x: .value("Date", session.startTime),
                        y: .value("Duration", session.totalSleepDuration / 3600)
                    )
                    .foregroundStyle(.blue.opacity(0.2).gradient)
                    .interpolationMethod(.catmullRom)
                }
                .chartYAxisLabel("Hours")
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: selectedPeriod == .week ? 1 : 3)) { _ in
                        AxisValueLabel(format: .dateTime.month().day())
                    }
                }
                .frame(height: 200)
            } else {
                noDataView
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Efficiency Trend Chart
    
    private var efficiencyTrendChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sleep Efficiency Trend")
                .font(.headline)
            
            if !sessionsForPeriod.isEmpty {
                Chart(sessionsForPeriod, id: \.id) { session in
                    LineMark(
                        x: .value("Date", session.startTime),
                        y: .value("Efficiency", session.sleepEfficiency)
                    )
                    .foregroundStyle(.green.gradient)
                    .interpolationMethod(.catmullRom)
                    
                    PointMark(
                        x: .value("Date", session.startTime),
                        y: .value("Efficiency", session.sleepEfficiency)
                    )
                    .foregroundStyle(.green)
                }
                .chartYScale(domain: 0...100)
                .chartYAxisLabel("Percentage")
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: selectedPeriod == .week ? 1 : 3)) { _ in
                        AxisValueLabel(format: .dateTime.month().day())
                    }
                }
                .frame(height: 200)
            } else {
                noDataView
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Sleep Stages Distribution
    
    private var sleepStagesDistribution: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sleep Stages Distribution")
                .font(.headline)
            
            if !sessionsForPeriod.isEmpty {
                let stageData = calculateStageDistribution()
                
                Chart(stageData, id: \.stage) { data in
                    SectorMark(
                        angle: .value("Duration", data.duration),
                        innerRadius: .ratio(0.5),
                        angularInset: 2
                    )
                    .foregroundStyle(by: .value("Stage", data.stage))
                    .cornerRadius(8)
                }
                .chartForegroundStyleScale([
                    "Deep": .purple,
                    "REM": .green,
                    "Light": .blue,
                    "Awake": .red
                ])
                .frame(height: 250)
                
                // Legend with percentages
                VStack(spacing: 8) {
                    ForEach(stageData, id: \.stage) { data in
                        HStack {
                            Circle()
                                .fill(data.color)
                                .frame(width: 12, height: 12)
                            
                            Text(data.stage)
                                .font(.subheadline)
                            
                            Spacer()
                            
                            Text(data.formattedDuration)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            Text("(\(data.percentage)%)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.top)
            } else {
                noDataView
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Awakenings Trend
    
    private var awakeningsTrendChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Awakenings Trend")
                .font(.headline)
            
            if !sessionsForPeriod.isEmpty {
                Chart(sessionsForPeriod, id: \.id) { session in
                    BarMark(
                        x: .value("Date", session.startTime),
                        y: .value("Awakenings", session.numberOfAwakenings)
                    )
                    .foregroundStyle(.orange.gradient)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: selectedPeriod == .week ? 1 : 3)) { _ in
                        AxisValueLabel(format: .dateTime.month().day())
                    }
                }
                .frame(height: 200)
            } else {
                noDataView
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - No Data View
    
    private var noDataView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            
            Text("No data for this period")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 150)
    }
    
    // MARK: - Computed Properties
    
    private var sessionsForPeriod: [SleepSession] {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -selectedPeriod.days, to: Date())!
        return controller.getSessionsForDateRange(from: cutoffDate, to: Date())
            .filter { $0.endTime != nil }
    }
    
    // MARK: - Helpers
    
    private func calculateStageDistribution() -> [StageData] {
        var deepTotal: TimeInterval = 0
        var remTotal: TimeInterval = 0
        var lightTotal: TimeInterval = 0
        var awakeTotal: TimeInterval = 0
        
        for session in sessionsForPeriod {
            for stage in session.sleepStages ?? [] {
                switch stage.stage {
                case .deep:
                    deepTotal += stage.duration
                case .rem:
                    remTotal += stage.duration
                case .light:
                    lightTotal += stage.duration
                case .awake:
                    awakeTotal += stage.duration
                }
            }
        }
        
        let total = deepTotal + remTotal + lightTotal + awakeTotal
        
        guard total > 0 else { return [] }
        
        return [
            StageData(
                stage: "Deep",
                duration: deepTotal,
                percentage: Int((deepTotal / total) * 100),
                color: .purple
            ),
            StageData(
                stage: "REM",
                duration: remTotal,
                percentage: Int((remTotal / total) * 100),
                color: .green
            ),
            StageData(
                stage: "Light",
                duration: lightTotal,
                percentage: Int((lightTotal / total) * 100),
                color: .blue
            ),
            StageData(
                stage: "Awake",
                duration: awakeTotal,
                percentage: Int((awakeTotal / total) * 100),
                color: .red
            )
        ].filter { $0.duration > 0 }
    }
}

// MARK: - Supporting Types

struct StageData {
    let stage: String
    let duration: TimeInterval
    let percentage: Int
    let color: Color
    
    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
}

struct AveragMetricCard: View {
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
                .font(.title2)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
