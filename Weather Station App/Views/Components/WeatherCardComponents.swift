//
//  WeatherCardComponents.swift
//  Weather Station App
//
//  Created by Curtis Netterville on 10/25/25.
//

import SwiftUI

struct WeatherCard<Content: View>: View {
    let title: String
    let systemImage: String
    let content: Content
    
    init(title: String, systemImage: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Spacer()
                Image(systemName: systemImage)
                    .foregroundColor(.blue)
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                Spacer()
            }
            
            content
            
            Spacer(minLength: 0)
        }
        .padding()
        .frame(minHeight: 200, maxHeight: 220)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

struct EditableWeatherCard<Content: View>: View {
    @Binding var title: String
    let systemImage: String
    let onTitleChange: (String) -> Void
    let content: Content
    
    @State private var isEditing = false
    @State private var editedTitle = ""
    
    init(title: Binding<String>, systemImage: String, onTitleChange: @escaping (String) -> Void, @ViewBuilder content: () -> Content) {
        self._title = title
        self.systemImage = systemImage
        self.onTitleChange = onTitleChange
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with icon and title
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .foregroundColor(.blue)
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 20, height: 20)
                
                if isEditing {
                    TextField("Card title", text: $editedTitle)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.headline)
                        .fontWeight(.semibold)
                        .onSubmit {
                            onTitleChange(editedTitle)
                            title = editedTitle
                            isEditing = false
                        }
                        .onAppear {
                            editedTitle = title
                        }
                } else {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .onTapGesture {
                            editedTitle = title
                            isEditing = true
                        }
                }
                
                Spacer()
            }
            
            // Content - now adaptive to content size
            content
        }
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading) // Fixed parameter order
        .padding(16) // Slightly reduced padding
        .background {
            // Modern multi-layer background effect
            ZStack {
                // Base background with subtle transparency
                Color(NSColor.controlBackgroundColor)
                    .opacity(0.8)
                
                // Subtle gradient overlay for depth
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(0.1),
                        Color.clear,
                        Color.black.opacity(0.05)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
        .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.linearGradient(
                    colors: [
                        Color.white.opacity(0.3),
                        Color.white.opacity(0.1),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ), lineWidth: 0.5)
        )
        .scaleEffect(1.0)
        .animation(.easeInOut(duration: 0.2), value: isEditing)
    }
}

struct StationInfoCard: View {
    let station: WeatherStation
    @StateObject private var weatherService = WeatherStationService.shared
    @State private var timer: Timer?
    @State private var currentDataAge: String = ""
    @State private var lastKnownUpdate: Date?
    
    private var creationDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }
    
    var body: some View {
        WeatherCard(title: "Station Information", systemImage: "info.circle.fill") {
            VStack(alignment: .leading, spacing: 8) {
                // MAC Address
                HStack {
                    Text("MAC Address:")
                        .fontWeight(.medium)
                    Spacer()
                    Text(station.macAddress)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                }
                
                // Station Model
                if let stationType = station.stationType {
                    HStack {
                        Text("Model:")
                            .fontWeight(.medium)
                        Spacer()
                        Text(stationType)
                            .font(.system(.body, design: .monospaced))
                    }
                }
                
                Divider()
                
                // Creation Date
                if let creationDate = station.creationDate {
                    HStack {
                        Text("Device Created:")
                            .fontWeight(.medium)
                        Spacer()
                        Text(creationDate, formatter: creationDateFormatter)
                    }
                }
                
                // Last Updated - Use enhanced TimestampExtractor formatting
                if let formattedTime = weatherService.getDataRecordingTime(for: station) {
                    HStack {
                        Text("Last Data Update:")
                            .fontWeight(.medium)
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text(formattedTime)
                            Text(currentDataAge)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(weatherService.isDataFresh(for: station) ? .green : .orange)
                        }
                    }
                } else if station.lastUpdated != nil {
                    HStack {
                        Text("Last Data Update:")
                            .fontWeight(.medium)
                        Spacer()
                        Text("Data available but timestamp unavailable")
                            .foregroundColor(.orange)
                    }
                } else {
                    HStack {
                        Text("Last Data Update:")
                            .fontWeight(.medium)
                        Spacer()
                        Text("Never")
                            .foregroundColor(.red)
                    }
                }
                
                // Status
                HStack {
                    Text("Status:")
                        .fontWeight(.medium)
                    Spacer()
                    HStack(spacing: 4) {
                        Circle()
                            .fill(station.isActive ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        Text(station.isActive ? "Active" : "Inactive")
                            .foregroundColor(station.isActive ? .green : .red)
                    }
                }
            }
            .font(.subheadline)
        }
        .onAppear {
            setupDataAgeTracking()
        }
        .onDisappear {
            stopTimer()
        }
        .onReceive(NotificationCenter.default.publisher(for: .weatherDataUpdated)) { _ in
            // Reset timer when data is updated
            if hasDataBeenUpdated() {
                setupDataAgeTracking()
            }
        }
        .onChange(of: station.lastUpdated) { oldValue, newValue in
            // Reset timer when station data changes
            if newValue != oldValue {
                setupDataAgeTracking()
            }
        }
    }
    
    private func setupDataAgeTracking() {
        stopTimer() // Stop existing timer
        updateDataAge() // Update immediately
        startTimer() // Start new timer
        lastKnownUpdate = station.lastUpdated
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            updateDataAge()
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateDataAge() {
        if let lastUpdated = station.lastUpdated {
            currentDataAge = formatDataAgeWithSeconds(from: lastUpdated)
        } else {
            currentDataAge = "Never"
        }
    }
    
    private func hasDataBeenUpdated() -> Bool {
        return station.lastUpdated != lastKnownUpdate
    }
    
    private func formatDataAgeWithSeconds(from recordedTime: Date, relativeTo currentTime: Date = Date()) -> String {
        let age = currentTime.timeIntervalSince(recordedTime)
        
        if age < 0 {
            return "0s ago" // Handle future timestamps
        } else if age < 60 {
            return "\(Int(age))s ago"
        } else if age < 3600 {
            let minutes = Int(age / 60)
            let seconds = Int(age.truncatingRemainder(dividingBy: 60))
            return "\(minutes)m \(seconds)s ago"
        } else if age < 86400 {
            let hours = Int(age / 3600)
            let minutes = Int((age.truncatingRemainder(dividingBy: 3600)) / 60)
            return "\(hours)h \(minutes)m ago"
        } else {
            let days = Int(age / 86400)
            let hours = Int((age.truncatingRemainder(dividingBy: 86400)) / 3600)
            return "\(days)d \(hours)h ago"
        }
    }
}