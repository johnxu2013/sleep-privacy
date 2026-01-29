//
//  TonightView.swift
//  sleep-health
//
//  Created by John Xu on 1/27/26.
//

import SwiftUI

struct TonightView: View {
    @ObservedObject var controller: SleepTrackingController
    @State private var showingAlarmSheet = false
    @State private var selectedWakeTime = Date()
    @State private var smartAlarmWindow: Double = 30 // minutes
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [.indigo.opacity(0.8), .purple.opacity(0.6), .black],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 8) {
                        if controller.isTracking {
                            trackingActiveView
                        } else {
                            trackingReadyView
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Tonight")
            .sheet(isPresented: $showingAlarmSheet) {
                AlarmSettingsSheet(
                    selectedTime: $selectedWakeTime,
                    windowMinutes: $smartAlarmWindow,
                    onStart: startTracking
                )
            }
        }
    }
    
    // MARK: - Tracking Ready View
    
    private var trackingReadyView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            // Moon icon
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 100))
                .foregroundStyle(.white)
                .symbolEffect(.breathe, options: .repeating)
            
            VStack(spacing: 12) {
                Text("Ready to Sleep?")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                
                Text("Tap below to start tracking your sleep")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            VStack(spacing: 16) {
                // Start tracking button
                Button {
                    Task {
                        await controller.startSleepTracking(targetWakeTime: nil)
                    }
                } label: {
                    HStack {
                        Image(systemName: "moon.zzz.fill")
                        Text("Start Sleep Tracking")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.white.opacity(0.9))
                    .foregroundStyle(.indigo)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                
                // Set alarm button
                Button {
                    showingAlarmSheet = true
                } label: {
                    HStack {
                        Image(systemName: "alarm.fill")
                        Text("Set Smart Alarm")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.white.opacity(0.2))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding(.horizontal)
            
            Spacer()
        }
    }
    
    // MARK: - Tracking Active View
    
    private var trackingActiveView: some View {
        VStack(spacing: 16) {
            // Status indicator
            VStack(spacing: 8) {
                Image(systemName: "waveform.path")
                    .font(.system(size: 62))
                    .foregroundStyle(.green)
                    .symbolEffect(.variableColor.iterative, options: .repeating)
                
                Text("Sleep Tracking Active")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                
                if let session = controller.currentSession {
                    Text("Started at \(session.startTime.formatted(date: .omitted, time: .shortened))")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            
            // Real-time metrics
            if let session = controller.currentSession {
                realTimeMetricsView(session: session)
            }
            
            // Alarm info
            if let targetWake = controller.currentSession?.targetWakeTime {
                alarmInfoView(wakeTime: targetWake)
            }
            
//            Spacer()
            
            // Stop button
            Button {
                Task {
                    await controller.stopSleepTracking()
                }
            } label: {
                HStack {
                    Image(systemName: "stop.fill")
                    Text("Stop Tracking")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(.red.opacity(0.8))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal)
        }
    }
    
    private func realTimeMetricsView(session: SleepSession) -> some View {
        VStack(spacing: 20) {
            Text("Current Metrics")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 20) {
                MetricCard(
                    icon: "figure.walk.motion",
                    title: "Movement",
                    value: "\(Int(controller.monitoringService.currentMovementIntensity * 100))%",
                    color: .blue
                )
                
                MetricCard(
                    icon: "waveform",
                    title: "Sound",
                    value: "\(Int(controller.monitoringService.currentSoundLevel)) dB",
                    color: .green
                )
            }
            
            HStack(spacing: 20) {
                MetricCard(
                    icon: "clock.fill",
                    title: "Duration",
                    value: formatDuration(session.timeInBed),
                    color: .purple
                )
                
                MetricCard(
                    icon: "chart.bar.fill",
                    title: "Samples",
                    value: "\((session.movementSamples ?? []).count + (session.soundSamples ?? []).count)",
                    color: .orange
                )
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    private func alarmInfoView(wakeTime: Date) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "alarm.fill")
                    .foregroundStyle(.yellow)
                Text("Smart Alarm Set")
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
            }
            
            Text("Target: \(wakeTime.formatted(date: .omitted, time: .shortened))")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
            
            if let window = controller.currentSession?.smartAlarmWindow {
                Text("Window: \(Int(window / 60)) minutes before")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.yellow.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Actions
    
    private func startTracking() {
        Task {
            let targetTime = selectedWakeTime
            let windowSeconds = smartAlarmWindow * 60
            await controller.startSleepTracking(
                targetWakeTime: targetTime,
                smartAlarmWindow: windowSeconds
            )
        }
    }
    
    // MARK: - Helpers
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
}

// MARK: - Supporting Views

struct MetricCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
            
            Text(value)
                .font(.headline)
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct AlarmSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedTime: Date
    @Binding var windowMinutes: Double
    let onStart: () -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Wake Time") {
                    DatePicker(
                        "Target Wake Time",
                        selection: $selectedTime,
                        in: Date()...,  // Only allow future times
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.automatic)
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Smart Alarm Window: \(Int(windowMinutes)) minutes")
                            .font(.headline)
                        
                        Slider(value: $windowMinutes, in: 15...60, step: 5)
                        
                        Text("The alarm will trigger during light sleep within this window before your target wake time.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Smart Alarm Settings")
                }
                
                Section {
                    Button {
                        onStart()
                        dismiss()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Start Sleep Tracking")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(selectedTime <= Date()) // Disable if time is in the past
                }
            }
            .navigationTitle("Set Smart Alarm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                // Ensure initial time is in the future (tomorrow morning)
                if selectedTime <= Date() {
                    let calendar = Calendar.current
                    let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
                    var components = calendar.dateComponents([.year, .month, .day], from: tomorrow)
                    components.hour = 7
                    components.minute = 0
                    selectedTime = calendar.date(from: components) ?? tomorrow
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
