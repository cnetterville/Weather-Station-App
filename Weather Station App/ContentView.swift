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
    @StateObject private var appStateManager = AppStateManager.shared
    // Use the shared instance directly instead of creating a new StateObject
    private var menuBarManager = MenuBarManager.shared
    @State private var selectedTab = 0
    @State private var showingSettings = false
    
    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Weather Stations")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    // Updated refresh indicator showing current refresh mode
                    if appStateManager.mainAppRefreshEnabled && !weatherService.weatherStations.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption)
                                .foregroundColor(.blue)
                            Text(getRefreshStatusText())
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
                    StationListItem(station: station, refreshInterval: 300) // Use a fixed display value
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
                        appStateManager.forceRefresh()
                    }
                    .disabled(weatherService.isLoading || weatherService.weatherStations.isEmpty)
                    
                    Spacer()
                    
                    // Updated auto-refresh toggle for main app
                    Toggle("Always refresh when open", isOn: $appStateManager.mainAppRefreshEnabled)
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .font(.caption2)
                        .disabled(weatherService.weatherStations.isEmpty)
                        .help("Keep refreshing weather data while the main app window is visible, regardless of whether the app is idle or active")
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
            }
            .frame(minWidth: 280, idealWidth: calculateIdealSidebarWidth(), maxWidth: 400)
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
            print("📱 ContentView appeared - AppStateManager will handle refresh coordination")
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToStation)) { notification in
            // Handle navigation to specific station from menu bar
            if let stationMAC = notification.userInfo?["stationMAC"] as? String,
               let stationIndex = weatherService.weatherStations.firstIndex(where: { $0.macAddress == stationMAC }) {
                withAnimation(.none) { // Disable animation for menu bar navigation
                    selectedTab = stationIndex
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showMainWindow)) { _ in
            // Handle request to show main window from menubar
            print("📱 Received showMainWindow notification")
            
            // The window should already be visible since this ContentView is displayed
            // Just ensure the app is activated
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
                
                if let window = NSApp.mainWindow {
                    window.makeKeyAndOrderFront(nil)
                    print("✅ Activated main window from ContentView")
                } else {
                    print("⚠️ No main window found in ContentView")
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(
                autoRefreshEnabled: $appStateManager.mainAppRefreshEnabled,
                refreshInterval: .constant(300) // Show a fixed value, actual interval managed by AppStateManager
            ) {
                // Settings changed callback - AppStateManager handles the refresh logic now
                print("🔄 Settings changed - AppStateManager will update refresh behavior")
            }
        }
        .task {
            // Initial data load - AppStateManager will handle ongoing refresh
            if !weatherService.weatherStations.isEmpty {
                await weatherService.fetchAllWeatherData(forceRefresh: false)
            }
        }
        .onChange(of: weatherService.weatherStations) { _, newStations in
            // Adjust selectedTab if it's out of bounds after stations are removed
            withAnimation(.none) { // Disable animation for data-driven changes
                if selectedTab >= newStations.count {
                    selectedTab = max(0, newStations.count - 1)
                }
                
                if newStations.isEmpty {
                    selectedTab = 0 // Reset to 0 when no stations
                }
            }
        }
    }
    
    private func getRefreshStatusText() -> String {
        let (_, isMenuBarRefreshing, _) = appStateManager.getRefreshStatus()
        
        if appStateManager.isMainAppVisible {
            return "Always Active"
        } else if isMenuBarRefreshing {
            return "MenuBar Mode"
        } else {
            return "Inactive"
        }
    }
    
    private func calculateIdealSidebarWidth() -> CGFloat {
        let stationCount = weatherService.weatherStations.count
        let baseWidth: CGFloat = 280
        let maxWidth: CGFloat = 400
        
        // If no stations, use minimum width
        guard stationCount > 0 else { return baseWidth }
        
        // Calculate content-based width
        let longestStationName = weatherService.weatherStations
            .map { $0.name.count }
            .max() ?? 0
        
        // Estimate width needed based on content
        let contentBasedWidth = baseWidth + min(CGFloat(longestStationName - 15) * 8, 120)
        
        // Factor in number of stations for better proportions
        let stationCountFactor = min(CGFloat(stationCount) * 5, 40)
        
        let idealWidth = contentBasedWidth + stationCountFactor
        
        return min(idealWidth, maxWidth)
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
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                // Status indicator - replaced small circle with descriptive badge
                HStack(spacing: 4) {
                    Circle()
                        .fill(station.isActive ? (weatherService.isDataFresh(for: station) ? Color.green : Color.orange) : Color.red)
                        .frame(width: 6, height: 6)
                    
                    Text(getStatusText())
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(getStatusColor())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(getStatusColor().opacity(0.15))
                        .cornerRadius(8)
                }
                
                Text(station.name)
                    .font(.headline)
                
                Spacer()
                
                // Weather preview section
                if let weatherData = weatherService.weatherData[station.macAddress] {
                    VStack(alignment: .trailing, spacing: 2) {
                        // Current temperature using proper formatting
                        if let tempValue = Double(weatherData.outdoor.temperature.value), tempValue > -999 {
                            Text(formatTemperature(tempValue, unit: weatherData.outdoor.temperature.unit))
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(.primary)
                        }
                        
                        // Weather condition icon (same as forecast cards)
                        Image(systemName: getWeatherIcon(for: weatherData, station: station))
                            .font(.system(size: 14))
                            .foregroundColor(getWeatherIconColor(for: weatherData))
                    }
                } else {
                    // Data age indicator when no weather data
                    Text(weatherService.getDataAge(for: station))
                        .font(.caption2)
                        .foregroundColor(weatherService.isDataFresh(for: station) ? .green : .orange)
                        .id(currentTime) // Force refresh when currentTime changes
                }
            }
            
            HStack {
                // Additional info row - only model now
                VStack(alignment: .leading, spacing: 2) {
                    // Station type
                    if let stationType = station.stationType {
                        Text("Model: \(stationType.replacingOccurrences(of: "_", with: " "))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Data age indicator only (removed device type badge)
                Text(weatherService.getDataAge(for: station))
                    .font(.caption2)
                    .foregroundColor(weatherService.isDataFresh(for: station) ? .green : .orange)
                    .id(currentTime) // Force refresh when currentTime changes
            }
        }
        .padding(.vertical, 4)
        .onReceive(timer) { time in
            withAnimation(.none) { // Disable animation for timer updates
                currentTime = time // This will trigger UI refresh every 30 seconds
            }
        }
        .animation(.none, value: currentTime) // Disable animations for time updates
    }
    
    private func getStatusText() -> String {
        if !station.isActive {
            return "Offline"
        } else if weatherService.isDataFresh(for: station) {
            return "Online"
        } else {
            return "Stale Data"
        }
    }
    
    private func getStatusColor() -> Color {
        if !station.isActive {
            return .red
        } else if weatherService.isDataFresh(for: station) {
            return .green
        } else {
            return .orange
        }
    }
    
    private func formatTemperature(_ temp: Double, unit: String) -> String {
        // Use the same temperature formatting as the rest of the app
        return MeasurementConverter.formatTemperature(String(temp), originalUnit: unit)
    }
    
    private func getWeatherIcon(for data: WeatherStationData, station: WeatherStation) -> String {
        // Use the same logic as OutdoorTemperatureCard - get today's forecast icon
        guard let forecast = WeatherForecastService.shared.getForecast(for: station) else {
            // Fallback to simple temperature-based icon if no forecast available
            let temp = Double(data.outdoor.temperature.value) ?? -999
            let humidity = Double(data.outdoor.humidity.value) ?? 0
            
            // Check for precipitation data if available
            if let rainfallData = data.rainfall, let rainValue = Double(rainfallData.rainRate.value), rainValue > 0.1 {
                return "cloud.rain.fill"
            }
            
            // Check piezo rainfall
            if let piezoRain = Double(data.rainfallPiezo.rainRate.value), piezoRain > 0.1 {
                return "cloud.rain.fill"
            }
            
            // Weather based on temperature and humidity as fallback
            if temp > -999 {
                if temp >= 25 {
                    return humidity > 80 ? "cloud.sun.fill" : "sun.max.fill"
                } else if temp >= 15 {
                    return humidity > 70 ? "cloud.sun.fill" : "sun.max.circle.fill"
                } else if temp >= 5 {
                    return humidity > 80 ? "cloud.fill" : "cloud.sun.fill"
                } else if temp >= 0 {
                    return "cloud.fill"
                } else {
                    return "snow"
                }
            }
            
            return "sun.max.fill" // Default fallback
        }
        
        // Find today's forecast
        if let todaysForecast = forecast.dailyForecasts.first(where: { $0.isToday }) {
            return todaysForecast.weatherIcon
        }
        
        // Fallback to first available forecast
        return forecast.dailyForecasts.first?.weatherIcon ?? "sun.max.fill"
    }
    
    private func getWeatherIconColor(for data: WeatherStationData) -> Color {
        // Always use blue for weather forecast icons to match the forecast cards
        return .blue
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