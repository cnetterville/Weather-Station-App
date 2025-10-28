//
//  ContentView.swift
//  Weather Station App
//
//  Created by Curtis Netterville on 10/25/25.
//

import SwiftUI
import Combine

struct ContentView: View {
    @StateObject private var weatherService = WeatherStationService.shared
    // Use the shared instance directly instead of creating a new StateObject
    private var menuBarManager = MenuBarManager.shared
    @State private var selectedTab = 0
    @State private var showingSettings = false
    @State private var autoRefreshTimer: Timer?
    @State private var autoRefreshEnabled = true
    @State private var refreshInterval: TimeInterval = 300 // 5 minutes default
    
    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Weather Stations")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    // Auto refresh indicator
                    if autoRefreshEnabled && !weatherService.weatherStations.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption)
                                .foregroundColor(.blue)
                            Text("Auto")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Button(action: { 
                        showingSettings = true
                    }) {
                        Image(systemName: "gearshape")
                            .font(.title2)
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                
                Divider()
                
                // Station List
                List(weatherService.weatherStations, selection: Binding<WeatherStation.ID?>(
                    get: { 
                        guard selectedTab < weatherService.weatherStations.count && selectedTab >= 0 else { 
                            return nil 
                        }
                        return weatherService.weatherStations[selectedTab].id
                    },
                    set: { newValue in
                        if let newValue = newValue,
                           let index = weatherService.weatherStations.firstIndex(where: { $0.id == newValue }) {
                            selectedTab = index
                        } else if weatherService.weatherStations.isEmpty {
                            selectedTab = 0
                        }
                    }
                )) { station in
                    StationListItem(station: station, refreshInterval: refreshInterval)
                        .tag(station.id)
                }
                .listStyle(.sidebar)
                
                // Refresh Controls
                HStack(spacing: 12) {
                    if weatherService.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    
                    Button("Refresh Now") {
                        Task {
                            await weatherService.fetchAllWeatherData(forceRefresh: true) // Force refresh when manual
                        }
                    }
                    .disabled(weatherService.isLoading || weatherService.weatherStations.isEmpty)
                    
                    Spacer()
                    
                    // Auto-refresh toggle
                    Toggle("Auto-refresh", isOn: $autoRefreshEnabled)
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .disabled(weatherService.weatherStations.isEmpty)
                        .onChange(of: autoRefreshEnabled) { _, newValue in
                            saveAutoRefreshSettings()
                            if newValue {
                                startAutoRefresh()
                            } else {
                                stopAutoRefresh()
                            }
                        }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
            }
        } detail: {
            Group {
                if weatherService.weatherStations.isEmpty {
                    EmptyStateView(showingSettings: $showingSettings)
                } else if selectedTab < weatherService.weatherStations.count && selectedTab >= 0 {
                    let selectedStationBinding = Binding<WeatherStation>(
                        get: { 
                            guard selectedTab < weatherService.weatherStations.count && selectedTab >= 0 else {
                                return weatherService.weatherStations.first ?? WeatherStation(name: "Error", macAddress: "00:00:00:00:00:00")
                            }
                            return weatherService.weatherStations[selectedTab] 
                        },
                        set: { 
                            guard selectedTab < weatherService.weatherStations.count && selectedTab >= 0 else { return }
                            weatherService.weatherStations[selectedTab] = $0 
                        }
                    )
                    WeatherStationDetailView(
                        station: selectedStationBinding,
                        weatherData: weatherService.weatherData[selectedTab < weatherService.weatherStations.count && selectedTab >= 0 ? weatherService.weatherStations[selectedTab].macAddress : ""]
                    )
                } else {
                    // Fallback view when selectedTab is out of bounds
                    VStack {
                        Text("Please select a weather station")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .animation(.none, value: weatherService.weatherStations.count) // Disable animations on station count changes
            .animation(.none, value: selectedTab) // Disable animations on tab changes
        }
        .onAppear {
            print("📱 ContentView appeared - setting up notification listeners")
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToStation)) { notification in
            print("🧭 ContentView received navigateToStation notification")
            // Handle navigation to specific station from menu bar
            if let stationMAC = notification.userInfo?["stationMAC"] as? String,
               let stationIndex = weatherService.weatherStations.firstIndex(where: { $0.macAddress == stationMAC }) {
                withAnimation(.none) { // Disable animation for menu bar navigation
                    selectedTab = stationIndex
                }
                print("🎯 Navigated to station at index: \(stationIndex)")
            }
        }
        .onReceive(menuBarManager.$shouldActivateApp) { shouldActivate in
            print("🔄 Received shouldActivateApp: \(shouldActivate)")
            
            if shouldActivate {
                print("🖱️ MenuBar clicked - attempting to show window")
                
                // Reset the flag first
                menuBarManager.shouldActivateApp = false
                print("🔄 Reset shouldActivateApp flag to false")
                
                // Absolutely minimal approach - no system calls
                DispatchQueue.main.async {
                    print("🔍 Looking for windows...")
                    print("📊 Total windows: \(NSApp.windows.count)")
                    
                    // Find any visible window with content
                    if let window = NSApp.windows.first(where: { 
                        $0.isVisible && 
                        $0.contentViewController != nil && 
                        $0.frame.width > 500 
                    }) {
                        
                        print("🎯 Found window: '\(window.title)' - bringing to front")
                        
                        // Only use the most basic window operations
                        window.orderFront(nil)  // Simplest bring-to-front call
                        
                        print("✅ Window order changed")
                        
                    } else {
                        print("❌ No suitable window found")
                        // Debug: show all windows
                        for (i, window) in NSApp.windows.enumerated() {
                            print("  Window \(i): '\(window.title)' visible:\(window.isVisible) hasContent:\(window.contentViewController != nil) width:\(window.frame.width)")
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(
                autoRefreshEnabled: $autoRefreshEnabled,
                refreshInterval: $refreshInterval
            ) {
                // Callback when settings change
                saveAutoRefreshSettings()
                if autoRefreshEnabled {
                    startAutoRefresh()
                }
            }
        }
        .task {
            loadAutoRefreshSettings()
            if !weatherService.weatherStations.isEmpty {
                await weatherService.fetchAllWeatherData(forceRefresh: false) // Smart initial load
                if autoRefreshEnabled {
                    startAutoRefresh()
                }
            }
        }
        .onChange(of: weatherService.weatherStations) { _, newStations in
            // Adjust selectedTab if it's out of bounds after stations are removed
            withAnimation(.none) { // Disable animation for data-driven changes
                if selectedTab >= newStations.count {
                    selectedTab = max(0, newStations.count - 1)
                }
                
                // Start/stop auto-refresh based on whether we have stations
                if newStations.isEmpty {
                    selectedTab = 0 // Reset to 0 when no stations
                    stopAutoRefresh()
                } else if autoRefreshEnabled && autoRefreshTimer == nil {
                    startAutoRefresh()
                }
            }
        }
        .onChange(of: refreshInterval) { _, _ in
            // Restart timer with new interval
            if autoRefreshEnabled {
                startAutoRefresh()
            }
        }
        .onDisappear {
            stopAutoRefresh()
        }
        .alert("Error", isPresented: .constant(weatherService.errorMessage != nil)) {
            Button("OK") {
                weatherService.errorMessage = nil
            }
        } message: {
            Text(weatherService.errorMessage ?? "")
        }
    }
    
    private func startAutoRefresh() {
        stopAutoRefresh() // Stop any existing timer
        
        guard autoRefreshEnabled && !weatherService.weatherStations.isEmpty else { return }
        
        autoRefreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { timer in
            print("🔄 Auto-refresh timer fired at \(Date())")
            
            if !weatherService.isLoading {
                Task { @MainActor in
                    print("🔄 Starting smart auto-refresh for \(weatherService.weatherStations.count) stations")
                    
                    // Use smart refresh that only fetches stale data
                    let hasStaleData = weatherService.weatherStations.contains { station in
                        !weatherService.isDataFresh(for: station) && station.isActive
                    }
                    
                    if hasStaleData {
                        await weatherService.fetchAllWeatherData(forceRefresh: false)
                        print("🔄 Smart auto-refresh completed at \(Date())")
                    } else {
                        print("🔄 All data is fresh, skipping refresh")
                    }
                }
            } else {
                print("⚠️ Skipping auto-refresh - previous refresh still in progress")
            }
        }
        
        let minutes = Int(refreshInterval / 60)
        let seconds = Int(refreshInterval.truncatingRemainder(dividingBy: 60))
        if minutes > 0 {
            print("🔄 Smart auto-refresh started: every \(minutes) minute\(minutes == 1 ? "" : "s") at \(Date())")
        } else {
            print("🔄 Smart auto-refresh started: every \(seconds) second\(seconds == 1 ? "" : "s") at \(Date())")
        }
        
        // Add timer validation
        DispatchQueue.main.asyncAfter(deadline: .now() + refreshInterval + 30) {
            if let timer = autoRefreshTimer, timer.isValid {
                print("✅ Auto-refresh timer is still valid after first cycle")
            } else {
                print("❌ Auto-refresh timer became invalid - restarting")
                if autoRefreshEnabled {
                    startAutoRefresh()
                }
            }
        }
    }
    
    private func stopAutoRefresh() {
        autoRefreshTimer?.invalidate()
        autoRefreshTimer = nil
        print("🛑 Auto-refresh stopped")
    }
    
    private func loadAutoRefreshSettings() {
        autoRefreshEnabled = UserDefaults.standard.object(forKey: "AutoRefreshEnabled") as? Bool ?? true
        refreshInterval = UserDefaults.standard.object(forKey: "RefreshInterval") as? TimeInterval ?? 300
    }
    
    private func saveAutoRefreshSettings() {
        UserDefaults.standard.set(autoRefreshEnabled, forKey: "AutoRefreshEnabled")
        UserDefaults.standard.set(refreshInterval, forKey: "RefreshInterval")
    }
}

struct StationListItem: View {
    let station: WeatherStation
    let refreshInterval: TimeInterval
    @StateObject private var weatherService = WeatherStationService.shared
    
    // Add a timer to force UI refresh every few seconds for data age display
    @State private var currentTime = Date()
    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect() // Reduced from 5s to 30s
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle()
                    .fill(station.isActive ? (weatherService.isDataFresh(for: station) ? Color.green : Color.orange) : Color.red)
                    .frame(width: 8, height: 8)
                
                Text(station.name)
                    .font(.headline)
                
                Spacer()
                
                // Data age indicator - now refreshes every 30 seconds instead of 5
                Text(weatherService.getDataAge(for: station))
                    .font(.caption2)
                    .foregroundColor(weatherService.isDataFresh(for: station) ? .green : .orange)
                    .id(currentTime) // Force refresh when currentTime changes
                
                // Device type badge
                if let deviceType = station.deviceType {
                    Text(deviceTypeDescription(deviceType))
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                }
            }
            
            Text(station.macAddress)
                .font(.caption)
                .foregroundColor(.secondary)
                .font(.system(.caption, design: .monospaced))
            
            // Station type
            if let stationType = station.stationType {
                Text("Model: \(stationType)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            // Creation date
            if let creationDate = station.creationDate {
                Text("Created: \(creationDate, formatter: dateFormatter)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
        .onReceive(timer) { time in
            withAnimation(.none) { // Disable animation for timer updates
                currentTime = time // This will trigger UI refresh every 30 seconds
            }
        }
        .animation(.none, value: currentTime) // Disable animations for time updates
    }
    
    private func deviceTypeDescription(_ type: Int) -> String {
        switch type {
        case 1: return "Gateway"
        case 2: return "Camera"
        default: return "Type \(type)"
        }
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }
}

struct EmptyStateView: View {
    @Binding var showingSettings: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "cloud.rain")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            Text("No Weather Stations")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Add your first weather station to get started")
                .foregroundColor(.secondary)
            
            Button("Open Settings") {
                showingSettings = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ContentView()
}