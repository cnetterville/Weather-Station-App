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
    private var menuBarManager = MenuBarManager.shared
    @State private var selectedStation: WeatherStation?
    @State private var showingSettings = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Compact toolbar with dropdown
            HStack(spacing: 16) {
                Text("Weather Station")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                // Compact dropdown picker
                if !weatherService.weatherStations.isEmpty {
                    Menu {
                        ForEach(weatherService.weatherStations) { station in
                            Button(action: { selectedStation = station }) {
                                HStack {
                                    Circle()
                                        .fill(getStatusColor(for: station))
                                        .frame(width: 8, height: 8)
                                    
                                    Text(station.name)
                                    
                                    if let temp = getTemperature(for: station) {
                                        Spacer()
                                        Text(temp)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    if selectedStation?.id == station.id {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if let selected = selectedStation {
                                Circle()
                                    .fill(getStatusColor(for: selected))
                                    .frame(width: 8, height: 8)
                                
                                Text(selected.name)
                                    .fontWeight(.semibold)
                                
                                if let temp = getTemperature(for: selected) {
                                    Text(temp)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                    }
                    .menuStyle(.borderlessButton)
                }
                
                // Other stations preview
                if weatherService.weatherStations.count > 1 {
                    HStack(spacing: 12) {
                        ForEach(weatherService.weatherStations.filter { $0.id != selectedStation?.id }) { station in
                            Button(action: {
                                selectedStation = station
                            }) {
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(getStatusColor(for: station))
                                        .frame(width: 6, height: 6)
                                    
                                    if let icon = getTodaysForecastIcon(for: station) {
                                        Image(systemName: icon)
                                            .font(.system(size: 13))
                                            .foregroundColor(.blue)
                                    }
                                    
                                    Text(station.name)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    if let temp = getTemperature(for: station) {
                                        Text(temp)
                                            .font(.system(size: 13, weight: .medium, design: .rounded))
                                            .foregroundColor(.primary)
                                    }
                                    
                                    if let rain = getTodaysRain(for: station) {
                                        HStack(spacing: 3) {
                                            Image(systemName: "drop.fill")
                                                .font(.system(size: 10))
                                                .foregroundColor(.blue)
                                            Text(rain)
                                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                                .foregroundColor(.blue)
                                        }
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                            .help("Switch to \(station.name)")
                        }
                    }
                }
                
                Spacer()
                
                // Refresh status
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
                
                // Refresh button
                Button(action: { 
                    appStateManager.forceRefresh()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.title3)
                }
                .disabled(weatherService.isLoading || weatherService.weatherStations.isEmpty)
                .buttonStyle(.plain)
                .help("Refresh weather data")
                
                // Settings button
                Button(action: { 
                    showingSettings = true
                }) {
                    Image(systemName: "gearshape")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .help("Settings")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Main content
            Group {
                if weatherService.weatherStations.isEmpty {
                    EmptyStateView(showingSettings: $showingSettings)
                } else if let selectedStation = selectedStation {
                    let stationBinding = Binding<WeatherStation>(
                        get: { selectedStation },
                        set: { newValue in
                            if let index = weatherService.weatherStations.firstIndex(where: { $0.id == newValue.id }) {
                                weatherService.weatherStations[index] = newValue
                            }
                        }
                    )
                    WeatherStationDetailView(
                        station: stationBinding,
                        weatherData: weatherService.weatherData[selectedStation.macAddress]
                    )
                } else {
                    VStack {
                        Text("Please select a weather station")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .animation(.none, value: weatherService.weatherStations.count)
        }
        .onAppear {
            print("📱 ContentView appeared - AppStateManager will handle refresh coordination")
            if selectedStation == nil {
                selectedStation = weatherService.weatherStations.first
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToStation)) { notification in
            if let stationMAC = notification.userInfo?["stationMAC"] as? String,
               let station = weatherService.weatherStations.first(where: { $0.macAddress == stationMAC }) {
                withAnimation(.none) {
                    selectedStation = station
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showMainWindow)) { _ in
            print("📱 Received showMainWindow notification")
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
                if let window = NSApp.mainWindow {
                    window.makeKeyAndOrderFront(nil)
                    print("✅ Activated main window from ContentView")
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(
                autoRefreshEnabled: $appStateManager.mainAppRefreshEnabled,
                refreshInterval: .constant(120)
            ) {
                print("🔄 Settings changed - AppStateManager will update refresh behavior")
            }
        }
        .task {
            if !weatherService.weatherStations.isEmpty {
                await weatherService.fetchAllWeatherData(forceRefresh: false)
            }
        }
        .onChange(of: weatherService.weatherStations) { _, newStations in
            withAnimation(.none) {
                if let current = selectedStation, !newStations.contains(where: { $0.id == current.id }) {
                    selectedStation = newStations.first
                } else if selectedStation == nil && !newStations.isEmpty {
                    selectedStation = newStations.first
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
    
    private func getStatusColor(for station: WeatherStation) -> Color {
        if !station.isActive {
            return .red
        } else if weatherService.isDataFresh(for: station) {
            return .green
        } else {
            return .orange
        }
    }
    
    private func getTemperature(for station: WeatherStation) -> String? {
        guard let weatherData = weatherService.weatherData[station.macAddress],
              let tempValue = Double(weatherData.outdoor.temperature.value),
              tempValue > -999 else {
            return nil
        }
        return MeasurementConverter.formatTemperature(
            String(tempValue), 
            originalUnit: weatherData.outdoor.temperature.unit
        )
    }
    
    private func getTodaysRain(for station: WeatherStation) -> String? {
        guard let weatherData = weatherService.weatherData[station.macAddress] else {
            return nil
        }
        
        let dailyRain = weatherData.rainfallPiezo.daily.value
        let unit = weatherData.rainfallPiezo.daily.unit
        
        guard let rainValue = Double(dailyRain), rainValue > 0 else {
            return nil
        }
        
        // Format the rain amount
        return MeasurementConverter.formatRainfall(dailyRain, originalUnit: unit)
    }
    
    private func getTodaysForecastIcon(for station: WeatherStation) -> String? {
        guard let forecast = WeatherForecastService.shared.getForecast(for: station) else {
            return nil
        }
        
        // Find today's forecast
        if let todaysForecast = forecast.dailyForecasts.first(where: { $0.isToday }) {
            return todaysForecast.weatherIcon
        }
        
        // Fallback to first available forecast
        return forecast.dailyForecasts.first?.weatherIcon
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