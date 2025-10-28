// 
//  SettingsView.swift
//  Weather Station App
//
//  Created by Curtis Netterville on 10/25/25.
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var weatherService = WeatherStationService.shared
    @StateObject private var menuBarManager = MenuBarManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var applicationKey: String = ""
    @State private var apiKey: String = ""
    @State private var showingAddStation = false
    @State private var testMessage: String = ""
    @State private var testSuccess: Bool = false
    @State private var isTesting: Bool = false
    @State private var showingAPIDebugger = false
    @State private var showingEditStation = false
    @State private var editingStation: WeatherStation?
    @State private var unitSystemDisplayMode: UnitSystemDisplayMode = .both
    
    // Auto-refresh settings - use local state if no binding provided
    @State private var localAutoRefreshEnabled = true
    @State private var localRefreshInterval: TimeInterval = 300
    
    // Optional bindings for when called from ContentView
    var autoRefreshEnabled: Binding<Bool>?
    var refreshInterval: Binding<TimeInterval>?
    var onSettingsChanged: (() -> Void)?
    
    // Computed properties to use either binding or local state
    private var autoRefreshBinding: Binding<Bool> {
        autoRefreshEnabled ?? $localAutoRefreshEnabled
    }
    
    private var refreshIntervalBinding: Binding<TimeInterval> {
        refreshInterval ?? $localRefreshInterval
    }
    
    // Refresh interval options (in seconds)
    private let refreshIntervals: [(String, TimeInterval)] = [
        ("1 minute", 60),
        ("2 minutes", 120),
        ("5 minutes", 300),
        ("10 minutes", 600),
        ("15 minutes", 900),
        ("30 minutes", 1800),
        ("1 hour", 3600)
    ]
    
    // Default initializer
    init() {
        self.autoRefreshEnabled = nil
        self.refreshInterval = nil
        self.onSettingsChanged = nil
    }
    
    // Initializer with bindings
    init(autoRefreshEnabled: Binding<Bool>, refreshInterval: Binding<TimeInterval>, onSettingsChanged: @escaping () -> Void) {
        self.autoRefreshEnabled = autoRefreshEnabled
        self.refreshInterval = refreshInterval
        self.onSettingsChanged = onSettingsChanged
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Weather Station Settings")
                    .font(.title)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // MenuBar Settings
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Menu Bar")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle("Show temperature in menu bar", isOn: $menuBarManager.isMenuBarEnabled)
                                .toggleStyle(.checkbox)
                            
                            if menuBarManager.isMenuBarEnabled {
                                VStack(alignment: .leading, spacing: 12) {
                                    // Display Mode Selection
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Display Mode:")
                                            .font(.headline)
                                        
                                        Picker("Display Mode", selection: $menuBarManager.displayMode) {
                                            ForEach(MenuBarDisplayMode.allCases, id: \.self) { mode in
                                                VStack(alignment: .leading) {
                                                    Text(mode.displayName)
                                                    Text(mode.description)
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }
                                                .tag(mode)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                    }
                                    
                                    // Station Selection (only for single station mode)
                                    if menuBarManager.displayMode == .singleStation {
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text("Weather Station:")
                                                .font(.headline)
                                            
                                            if menuBarManager.availableStations.isEmpty {
                                                Text("No active weather stations available")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            } else {
                                                Picker("Station", selection: $menuBarManager.selectedStationMac) {
                                                    Text("First available station")
                                                        .tag("")
                                                    
                                                    ForEach(menuBarManager.availableStations, id: \.macAddress) { station in
                                                        Text(station.name)
                                                            .tag(station.macAddress)
                                                    }
                                                }
                                                .pickerStyle(.menu)
                                            }
                                        }
                                    }
                                    
                                    // Cycling Options (only for cycle mode)
                                    if menuBarManager.displayMode == .cycleThrough {
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text("Cycling Options:")
                                                .font(.headline)
                                            
                                            HStack {
                                                Text("Cycle Interval:")
                                                    .font(.subheadline)
                                                
                                                Spacer()
                                                
                                                Picker("Interval", selection: $menuBarManager.cycleInterval) {
                                                    Text("5 seconds").tag(5.0)
                                                    Text("10 seconds").tag(10.0)
                                                    Text("15 seconds").tag(15.0)
                                                    Text("30 seconds").tag(30.0)
                                                    Text("1 minute").tag(60.0)
                                                    Text("2 minutes").tag(120.0)
                                                }
                                                .pickerStyle(.menu)
                                                .frame(width: 120)
                                            }
                                            
                                            Text("Cycling through \(menuBarManager.availableStations.count) active station\(menuBarManager.availableStations.count == 1 ? "" : "s")")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    // Temperature Display Mode
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Temperature Display:")
                                            .font(.headline)
                                        
                                        Picker("Temperature Mode", selection: $menuBarManager.temperatureDisplayMode) {
                                            ForEach(MenuBarTemperatureMode.allCases, id: \.self) { mode in
                                                Text(mode.displayName)
                                                    .tag(mode)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                    }
                                    
                                    // Display Options
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Display Options:")
                                            .font(.headline)
                                        
                                        Toggle("Show station names", isOn: $menuBarManager.showStationName)
                                            .toggleStyle(.checkbox)
                                            .disabled(menuBarManager.displayMode == .allStations) // Always shows names in all stations mode
                                        
                                        Toggle("Show decimal places", isOn: $menuBarManager.showDecimals)
                                            .toggleStyle(.checkbox)
                                        
                                        Toggle("Show rain icon when raining", isOn: $menuBarManager.showRainIcon)
                                            .toggleStyle(.checkbox)
                                        
                                        Toggle("Show sun icon for high UV (3+)", isOn: $menuBarManager.showUVIcon)
                                            .toggleStyle(.checkbox)
                                        
                                        Toggle("Show moon icon at night", isOn: $menuBarManager.showNightIcon)
                                            .toggleStyle(.checkbox)
                                        
                                        // Custom menubar labels section
                                        if !menuBarManager.availableStations.isEmpty {
                                            Divider()
                                                .padding(.vertical, 4)
                                            
                                            VStack(alignment: .leading, spacing: 8) {
                                                HStack {
                                                    Text("Custom MenuBar Labels:")
                                                        .font(.subheadline)
                                                        .fontWeight(.medium)
                                                    
                                                    Spacer()
                                                    
                                                    // Preview of how it will look in menubar
                                                    if let previewText = getMenuBarPreview() {
                                                        VStack(alignment: .trailing) {
                                                            Text("Preview:")
                                                                .font(.caption2)
                                                                .foregroundColor(.secondary)
                                                            Text(previewText)
                                                                .font(.system(.caption, design: .monospaced))
                                                                .padding(.horizontal, 6)
                                                                .padding(.vertical, 2)
                                                                .background(Color.black.opacity(0.8))
                                                                .foregroundColor(.white)
                                                                .cornerRadius(4)
                                                        }
                                                    }
                                                }
                                                
                                                Text("Set short labels for each station to save menubar space (max 8 characters):")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                
                                                ForEach(Array(menuBarManager.availableStations.enumerated()), id: \.element.id) { index, station in
                                                    MenuBarLabelEditor(station: station)
                                                }
                                                
                                                // Quick action buttons
                                                HStack {
                                                    Button("Reset All Labels") {
                                                        resetAllCustomLabels()
                                                    }
                                                    .buttonStyle(.bordered)
                                                    .controlSize(.small)
                                                    
                                                    Button("Auto-Generate Short Labels") {
                                                        autoGenerateShortLabels()
                                                    }
                                                    .buttonStyle(.bordered)
                                                    .controlSize(.small)
                                                    
                                                    Spacer()
                                                }
                                            }
                                        }
                                    }
                                    
                                    // Info
                                    HStack {
                                        Image(systemName: "info.circle")
                                            .foregroundColor(.blue)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Click the menu bar item to see detailed weather info and quick actions")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Text("Custom labels help keep the menubar compact while showing meaningful station identifiers")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            if menuBarManager.displayMode == .allStations {
                                                Text("All stations mode: Shows abbreviated data from all active stations")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            } else if menuBarManager.displayMode == .cycleThrough {
                                                Text("Cycle mode: Automatically rotates between stations every \(Int(menuBarManager.cycleInterval)) seconds")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                }
                                .padding(.leading, 16)
                            }
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .cornerRadius(8)
                    }
                    
                    // Display Preferences
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Display Preferences")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Unit System:")
                                    .font(.headline)
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(UnitSystemDisplayMode.allCases, id: \.self) { mode in
                                        Button(action: {
                                            unitSystemDisplayMode = mode
                                            UserDefaults.standard.unitSystemDisplayMode = mode
                                        }) {
                                            HStack {
                                                Image(systemName: unitSystemDisplayMode == mode ? "checkmark.circle.fill" : "circle")
                                                    .foregroundColor(unitSystemDisplayMode == mode ? .blue : .secondary)
                                                
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(mode.shortName)
                                                        .font(.headline)
                                                        .foregroundColor(.primary)
                                                    Text(mode.displayName)
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }
                                                
                                                Spacer()
                                            }
                                            .padding(.vertical, 4)
                                        }
                                        .buttonStyle(.plain)
                                        .background(unitSystemDisplayMode == mode ? Color.blue.opacity(0.1) : Color.clear)
                                        .cornerRadius(6)
                                    }
                                }
                                
                                HStack {
                                    Image(systemName: "info.circle")
                                        .foregroundColor(.blue)
                                    Text("Choose how measurements are displayed: temperature, wind speed, rainfall, lightning distance, etc.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .cornerRadius(8)
                    }
                    
                    // Auto-Refresh Settings
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Auto-Refresh Settings")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle("Enable Auto-Refresh", isOn: autoRefreshBinding)
                                .toggleStyle(.checkbox)
                                .onChange(of: autoRefreshBinding.wrappedValue) { _, _ in
                                    saveAutoRefreshSettings()
                                    onSettingsChanged?()
                                }
                            
                            if autoRefreshBinding.wrappedValue {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Refresh Interval:")
                                        .font(.headline)
                                   
                                    // Use a more compact layout for the picker
                                    VStack(alignment: .leading, spacing: 8) {
                                        // First row
                                        HStack(spacing: 8) {
                                            IntervalButton(label: "1 min", interval: 60.0, binding: refreshIntervalBinding, onChanged: {
                                                saveAutoRefreshSettings()
                                                onSettingsChanged?()
                                            })
                                            IntervalButton(label: "2 min", interval: 120.0, binding: refreshIntervalBinding, onChanged: {
                                                saveAutoRefreshSettings()
                                                onSettingsChanged?()
                                            })
                                            IntervalButton(label: "5 min", interval: 300.0, binding: refreshIntervalBinding, onChanged: {
                                                saveAutoRefreshSettings()
                                                onSettingsChanged?()
                                            })
                                        }
                                        
                                        // Second row
                                        HStack(spacing: 8) {
                                            IntervalButton(label: "10 min", interval: 600.0, binding: refreshIntervalBinding, onChanged: {
                                                saveAutoRefreshSettings()
                                                onSettingsChanged?()
                                            })
                                            IntervalButton(label: "15 min", interval: 900.0, binding: refreshIntervalBinding, onChanged: {
                                                saveAutoRefreshSettings()
                                                onSettingsChanged?()
                                            })
                                            IntervalButton(label: "30 min", interval: 1800.0, binding: refreshIntervalBinding, onChanged: {
                                                saveAutoRefreshSettings()
                                                onSettingsChanged?()
                                            })
                                            IntervalButton(label: "1 hour", interval: 3600.0, binding: refreshIntervalBinding, onChanged: {
                                                saveAutoRefreshSettings()
                                                onSettingsChanged?()
                                            })
                                        }
                                    }
                                   
                                    HStack {
                                        Image(systemName: "info.circle")
                                            .foregroundColor(.blue)
                                        Text("Weather data will automatically refresh at the selected interval")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .cornerRadius(8)
                    }
                    
                    // API Configuration
                    VStack(alignment: .leading, spacing: 16) {
                        Text("API Configuration")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Application Key")
                                    .font(.headline)
                                SecureField("Enter Ecowitt Application Key", text: $applicationKey)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(.body, design: .monospaced))
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("API Key")
                                    .font(.headline)
                                SecureField("Enter Ecowitt API Key", text: $apiKey)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(.body, design: .monospaced))
                            }
                            
                            HStack(spacing: 12) {
                                Button("Save API Keys") {
                                    weatherService.updateCredentials(
                                        applicationKey: applicationKey,
                                        apiKey: apiKey
                                    )
                                    testMessage = ""
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(applicationKey.isEmpty || apiKey.isEmpty)
                                
                                Button("Test Connection") {
                                    testConnection()
                                }
                                .disabled(applicationKey.isEmpty || apiKey.isEmpty || weatherService.weatherStations.isEmpty || isTesting)
                            }
                            
                            if isTesting {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Testing connection...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            if !testMessage.isEmpty {
                                HStack {
                                    Image(systemName: testSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundColor(testSuccess ? .green : .red)
                                    Text(testMessage)
                                        .font(.caption)
                                        .foregroundColor(testSuccess ? .green : .red)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background((testSuccess ? Color.green : Color.red).opacity(0.1))
                                .cornerRadius(6)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Find these keys in your Ecowitt account dashboard")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("API Endpoint: cdnapi.ecowitt.net/api/v3/device/real_time")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .font(.system(.caption2, design: .monospaced))
                            }
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .cornerRadius(8)
                    }
                    
                    // Weather Stations
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Weather Stations")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Spacer()
                            
                            // First row of buttons
                            HStack(spacing: 8) {
                                Button("Discover Stations") {
                                    discoverStations()
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(applicationKey.isEmpty || apiKey.isEmpty || weatherService.isDiscoveringStations)
                                
                                Button("Add Manually") {
                                    showingAddStation = true
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        
                        // Second row of management buttons
                        HStack {
                            Spacer()
                            
                            Button("Update All Info") {
                                updateAllStationsInfo()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(applicationKey.isEmpty || apiKey.isEmpty || weatherService.weatherStations.isEmpty)
                            
                            Menu("Associate Cameras") {
                                Button("Within 1 km") {
                                    weatherService.associateCamerasWithStations(distanceThresholdKm: 1.0)
                                }
                                Button("Within 5 km") {
                                    weatherService.associateCamerasWithStations(distanceThresholdKm: 5.0)
                                }
                                Button("Within 15 km") {
                                    weatherService.associateCamerasWithStations(distanceThresholdKm: 15.0)
                                }
                                Button("Within 50 km") {
                                    weatherService.associateCamerasWithStations(distanceThresholdKm: 50.0)
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(applicationKey.isEmpty || apiKey.isEmpty || weatherService.discoveredStations.isEmpty)
                        }
                        
                        // Station Discovery Results
                        if weatherService.isDiscoveringStations {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Discovering stations...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        }
                        
                        if !weatherService.discoveredStations.isEmpty {
                            DiscoveredStationsSection()
                        }
                        
                        if weatherService.weatherStations.isEmpty && weatherService.discoveredStations.isEmpty && !weatherService.isDiscoveringStations {
                            VStack(spacing: 12) {
                                Image(systemName: "location.slash")
                                    .font(.system(size: 24))
                                    .foregroundColor(.secondary)
                                Text("No weather stations configured")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text("Use 'Discover Stations' to automatically find your devices, or add them manually")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                            .cornerRadius(8)
                        } else if !weatherService.weatherStations.isEmpty {
                            ExistingStationsSection(
                                applicationKey: applicationKey,
                                apiKey: apiKey,
                                testIndividualStation: testIndividualStation,
                                copyAPIURL: copyAPIURL
                            )
                        }
                    }
                }
                .padding()
            }
        }
        .frame(width: 700, height: 500)
        .onAppear {
            applicationKey = weatherService.credentials.applicationKey
            apiKey = weatherService.credentials.apiKey
            unitSystemDisplayMode = UserDefaults.standard.unitSystemDisplayMode
        }
        .sheet(isPresented: $showingAddStation) {
            AddWeatherStationView()
        }
        .sheet(isPresented: $showingEditStation) {
            if let station = editingStation {
                EditWeatherStationView(station: station)
            }
        }
        .sheet(isPresented: $showingAPIDebugger) {
            APIDebugView()
        }
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }
    
    private func testConnection() {
        isTesting = true
        testMessage = ""
        
        Task {
            // First save the credentials
            weatherService.updateCredentials(
                applicationKey: applicationKey,
                apiKey: apiKey
            )
            
            // Then test the connection
            let result = await weatherService.testAPIConnection()
            
            await MainActor.run {
                isTesting = false
                testSuccess = result.success
                testMessage = result.message
            }
        }
    }
    
    private func testIndividualStation(_ station: WeatherStation) {
        isTesting = true
        testMessage = ""
        
        Task {
            // First save the credentials
            weatherService.updateCredentials(
                applicationKey: applicationKey,
                apiKey: apiKey
            )
            
            // Test this specific station
            await weatherService.fetchWeatherData(for: station)
            
            await MainActor.run {
                isTesting = false
                if let errorMsg = weatherService.errorMessage {
                    testSuccess = false
                    testMessage = "Station \(station.name): \(errorMsg)"
                } else {
                    testSuccess = true
                    testMessage = "Station \(station.name): Connection successful!"
                }
            }
        }
    }
    
    private func copyAPIURL(for station: WeatherStation) {
        let apiURL = "https://cdnapi.ecowitt.net/api/v3/device/real_time?application_key=\(applicationKey)&api_key=\(apiKey)&mac=\(station.macAddress)&call_back=all"
        
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(apiURL, forType: .string)
        
        testMessage = "API URL copied to clipboard for \(station.name)"
        testSuccess = true
    }
    
    private func discoverStations() {
        // Save credentials first
        weatherService.updateCredentials(
            applicationKey: applicationKey,
            apiKey: apiKey
        )
        
        Task {
            let result = await weatherService.discoverWeatherStations()
            
            await MainActor.run {
                testSuccess = result.success
                testMessage = result.message
                
                if !result.success {
                    // If discovery failed, show the error
                    print("❌ Station discovery failed: \(result.message)")
                }
            }
        }
    }

    private func updateAllStationsInfo() {
        Task {
            for station in weatherService.weatherStations {
                let result = await weatherService.fetchStationInfo(for: station)
                print("Updated \(station.name): \(result.message)")
                
                // Small delay between requests
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            }
        }
    }

    private func saveAutoRefreshSettings() {
        UserDefaults.standard.set(autoRefreshBinding.wrappedValue, forKey: "AutoRefreshEnabled")
        UserDefaults.standard.set(refreshIntervalBinding.wrappedValue, forKey: "RefreshInterval")
    }
    
    private func getMenuBarPreview() -> String? {
        let activeStations = menuBarManager.availableStations
        let sampleTemp = menuBarManager.showDecimals ? "72.3°F" : "72°F"
        
        // Show sample icons based on settings and priority (rain > UV > night)
        let weatherIcon = if menuBarManager.showRainIcon {
            "💧 " // Rain has highest priority in preview
        } else if menuBarManager.showUVIcon {
            "☀️ " // UV second priority
        } else if menuBarManager.showNightIcon {
            "🌙 " // Night lowest priority
        } else {
            ""
        }
        
        switch menuBarManager.displayMode {
        case .singleStation:
            if let station = activeStations.first {
                let label = station.displayLabelForMenuBar
                let baseTemp = menuBarManager.showStationName ? "\(label): \(sampleTemp)" : sampleTemp
                return "\(weatherIcon)\(baseTemp)"
            }
        case .allStations:
            if activeStations.count > 0 {
                let samples = activeStations.prefix(3).map { station in
                    let label = station.displayLabelForMenuBar
                    let shortLabel = label.count > 4 ? String(label.prefix(4)) + ":" : label + ":"
                    return "\(shortLabel)\(sampleTemp)"
                }
                let preview = samples.joined(separator: " | ")
                let basePreview = activeStations.count > 3 ? preview + " | ..." : preview
                return "\(weatherIcon)\(basePreview)"
            }
        case .cycleThrough:
            if let station = activeStations.first {
                let label = station.displayLabelForMenuBar
                let baseTemp = menuBarManager.showStationName ? "\(label): \(sampleTemp)" : sampleTemp
                return "\(weatherIcon)\(baseTemp)"
            }
        }
        
        return nil
    }
    
    private func resetAllCustomLabels() {
        for station in menuBarManager.availableStations {
            if let index = weatherService.weatherStations.firstIndex(where: { $0.id == station.id }) {
                var updatedStation = weatherService.weatherStations[index]
                updatedStation.menuBarLabel = nil
                weatherService.updateWeatherStation(updatedStation)
            }
        }
        
        // Trigger menubar update
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NotificationCenter.default.post(name: .weatherDataUpdated, object: nil)
        }
    }
    
    private func autoGenerateShortLabels() {
        for (index, station) in menuBarManager.availableStations.enumerated() {
            if let stationIndex = weatherService.weatherStations.firstIndex(where: { $0.id == station.id }) {
                var updatedStation = weatherService.weatherStations[stationIndex]
                
                // Generate a short label based on the station name
                let words = station.name.split(separator: " ")
                let shortLabel: String
                
                if words.count > 1 {
                    // Use first letter of each word (up to 4 letters) + number if needed
                    let initials = words.prefix(3).map { String($0.first ?? "?") }.joined()
                    shortLabel = initials + (index > 0 ? "\(index + 1)" : "")
                } else {
                    // Use first 6 characters of single word
                    shortLabel = String(station.name.prefix(6))
                }
                
                updatedStation.menuBarLabel = String(shortLabel.prefix(8)) // Ensure max 8 chars
                weatherService.updateWeatherStation(updatedStation)
            }
        }
        
        // Trigger menubar update
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NotificationCenter.default.post(name: .weatherDataUpdated, object: nil)
        }
    }
}

struct AddWeatherStationView: View {
    @StateObject private var weatherService = WeatherStationService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var stationName = ""
    @State private var macAddress = ""
    @State private var macError: String = ""
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Add Weather Station")
                    .font(.title)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("Cancel") {
                    dismiss()
                }
            }
            
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Station Name")
                        .font(.headline)
                    TextField("e.g., Home Weather Station", text: $stationName)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("MAC Address")
                        .font(.headline)
                    TextField("e.g., A0:A3:B3:7B:28:8B", text: $macAddress)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .onChange(of: macAddress) { _, newValue in
                            validateMAC(newValue)
                        }
                    
                    if !macError.isEmpty {
                        Text(macError)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Find the MAC address in your Ecowitt app under Device List")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Format: XX:XX:XX:XX:XX:XX (uppercase)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("⚠️ Device must be registered to your Ecowitt account")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            Button("Add Station") {
                let formattedMAC = MACAddressValidator.format(macAddress)
                let newStation = WeatherStation(
                    name: stationName,
                    macAddress: formattedMAC
                )
                weatherService.addWeatherStation(newStation)
                
                // Automatically fetch station info (timezone, location, etc.) after adding
                Task {
                    let _ = await weatherService.fetchStationInfo(for: newStation)
                }
                
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .disabled(stationName.isEmpty || macAddress.isEmpty || !macError.isEmpty)
            
            Spacer()
        }
        .padding()
        .frame(width: 450, height: 350)
    }
    
    private func validateMAC(_ mac: String) {
        let formatted = MACAddressValidator.format(mac)
        
        if mac.isEmpty {
            macError = ""
        } else if !MACAddressValidator.isValid(formatted) {
            macError = "Invalid MAC address format"
        } else {
            macError = ""
            macAddress = formatted // Auto-format as user types
        }
    }
}

struct EditWeatherStationView: View {
    @StateObject private var weatherService = WeatherStationService.shared
    @Environment(\.dismiss) private var dismiss
    
    let station: WeatherStation
    
    @State private var stationName = ""
    @State private var macAddress = ""
    @State private var macError: String = ""
    @State private var testMessage: String = ""
    @State private var testSuccess: Bool = false
    @State private var isTesting: Bool = false
    @State private var sensorPreferences = SensorPreferences()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Edit Weather Station")
                    .font(.title)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("Cancel") {
                    dismiss()
                }
            }
            .padding()
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Basic Information
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Station Information")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Station Name")
                                    .font(.headline)
                                TextField("Station name", text: $stationName)
                                    .textFieldStyle(.roundedBorder)
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("MAC Address")
                                    .font(.headline)
                                TextField("MAC Address", text: $macAddress)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(.body, design: .monospaced))
                                    .onChange(of: macAddress) { _, newValue in
                                        validateMAC(newValue)
                                    }
                                
                                if !macError.isEmpty {
                                    Text(macError)
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                                
                                Text("⚠️ Device must be registered to your Ecowitt account")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .cornerRadius(8)
                    }
                    
                    // Sensor Display Preferences
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Display Preferences")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Choose which sensors to display for this weather station:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 16) {
                            // Main Sensors
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Primary Sensors")
                                    .font(.headline)
                                
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                                    SensorToggleRow("🌡️ Outdoor Temperature", isOn: $sensorPreferences.showOutdoorTemp)
                                    SensorToggleRow("🏠 Indoor Temperature", isOn: $sensorPreferences.showIndoorTemp)
                                    SensorToggleRow("💨 Wind", isOn: $sensorPreferences.showWind)
                                    SensorToggleRow("📊 Pressure", isOn: $sensorPreferences.showPressure)
                                    SensorToggleRow("🌧️ Rainfall (Traditional)", isOn: $sensorPreferences.showRainfall)
                                    SensorToggleRow("🌧️ Rainfall (Piezo)", isOn: $sensorPreferences.showRainfallPiezo)
                                    SensorToggleRow("☀️ UV Index", isOn: $sensorPreferences.showUVIndex)
                                    SensorToggleRow("⚡ Lightning", isOn: $sensorPreferences.showLightning)
                                }
                            }
                            
                            Divider()
                            
                            // Air Quality
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Air Quality Sensors")
                                    .font(.headline)
                                
                                VStack(spacing: 4) {
                                    SensorToggleRow("🌫️ Air Quality Ch1 (PM2.5)", isOn: $sensorPreferences.showAirQualityCh1)
                                    SensorToggleRow("🌫️ Air Quality Ch2 (PM2.5)", isOn: $sensorPreferences.showAirQualityCh2)
                                    SensorToggleRow("🌫️ Air Quality Ch3 (PM2.5)", isOn: $sensorPreferences.showAirQualityCh3)
                                }
                            }
                            
                            Divider()
                            
                            // Additional Temperature Sensors
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Additional Temperature Sensors")
                                    .font(.headline)
                                
                                VStack(spacing: 4) {
                                    SensorToggleRow("🌡️ Temperature & Humidity Ch1", isOn: $sensorPreferences.showTempHumidityCh1)
                                    SensorToggleRow("🌡️ Temperature & Humidity Ch2", isOn: $sensorPreferences.showTempHumidityCh2)
                                    SensorToggleRow("🌡️ Temperature & Humidity Ch3", isOn: $sensorPreferences.showTempHumidityCh3)
                                }
                            }
                            
                            Divider()
                            
                            // System Information
                            VStack(alignment: .leading, spacing: 8) {
                                Text("System Information")
                                    .font(.headline)
                                
                                SensorToggleRow("🔋 Battery Status", isOn: $sensorPreferences.showBatteryStatus)
                                SensorToggleRow("🌅 Sunrise/Sunset", isOn: $sensorPreferences.showSunriseSunset)
                                SensorToggleRow("🌙 Moon & Lunar", isOn: $sensorPreferences.showLunar)
                                SensorToggleRow("📷 Weather Camera", isOn: $sensorPreferences.showCamera)
                            }
                            
                            // Quick Actions
                            HStack(spacing: 12) {
                                Button("Show All") {
                                    setAllSensors(to: true)
                                }
                                .buttonStyle(.bordered)
                                
                                Button("Hide All") {
                                    setAllSensors(to: false)
                                }
                                .buttonStyle(.bordered)
                                
                                Button("Reset to Defaults") {
                                    sensorPreferences = SensorPreferences()
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .cornerRadius(8)
                    }
                }
                .padding()
            }
            
            // Bottom Actions
            Divider()
            HStack(spacing: 12) {
                Button("Test Connection") {
                    testUpdatedStation()
                }
                .disabled(stationName.isEmpty || macAddress.isEmpty || !macError.isEmpty || isTesting)
                
                Spacer()
                
                Button("Save Changes") {
                    var updatedStation = station
                    updatedStation.name = stationName.trimmingCharacters(in: .whitespacesAndNewlines)
                    let newMAC = macAddress.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                    
                    if updatedStation.macAddress != newMAC {
                        weatherService.weatherData.removeValue(forKey: updatedStation.macAddress)
                        updatedStation.macAddress = newMAC
                        updatedStation.lastUpdated = nil
                    }
                    
                    updatedStation.sensorPreferences = sensorPreferences
                    weatherService.updateWeatherStation(updatedStation)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(stationName.isEmpty || macAddress.isEmpty || !macError.isEmpty)
            }
            .padding()
            
            if isTesting {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Testing connection...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom)
            }
            
            if !testMessage.isEmpty {
                HStack {
                    Image(systemName: testSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(testSuccess ? .green : .red)
                    Text(testMessage)
                        .font(.caption)
                        .foregroundColor(testSuccess ? .green : .red)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background((testSuccess ? Color.green : Color.red).opacity(0.1))
                .cornerRadius(6)
                .padding(.bottom)
            }
        }
        .frame(width: 600, height: 700)
        .onAppear {
            stationName = station.name
            macAddress = station.macAddress
            sensorPreferences = station.sensorPreferences
        }
    }
    
    private func validateMAC(_ mac: String) {
        let formatted = MACAddressValidator.format(mac)
        
        if mac.isEmpty {
            macError = ""
        } else if !MACAddressValidator.isValid(formatted) {
            macError = "Invalid MAC address format"
        } else {
            macError = ""
            macAddress = formatted
        }
    }
    
    private func setAllSensors(to value: Bool) {
        sensorPreferences.showOutdoorTemp = value
        sensorPreferences.showIndoorTemp = value
        sensorPreferences.showWind = value
        sensorPreferences.showPressure = value
        sensorPreferences.showRainfall = value
        sensorPreferences.showRainfallPiezo = value
        sensorPreferences.showAirQualityCh1 = value
        sensorPreferences.showAirQualityCh2 = value
        sensorPreferences.showAirQualityCh3 = value
        sensorPreferences.showUVIndex = value
        sensorPreferences.showLightning = value
        sensorPreferences.showTempHumidityCh1 = value
        sensorPreferences.showTempHumidityCh2 = value
        sensorPreferences.showTempHumidityCh3 = value
        sensorPreferences.showBatteryStatus = value
        sensorPreferences.showSunriseSunset = value
        sensorPreferences.showCamera = value
    }
    
    private func testUpdatedStation() {
        isTesting = true
        testMessage = ""
        
        let testStation = WeatherStation(
            name: stationName.trimmingCharacters(in: .whitespacesAndNewlines),
            macAddress: macAddress.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        )
        
        Task {
            await weatherService.fetchWeatherData(for: testStation)
            
            await MainActor.run {
                isTesting = false
                if let errorMsg = weatherService.errorMessage {
                    testSuccess = false
                    testMessage = "Test failed: \(errorMsg)"
                } else {
                    testSuccess = true
                    testMessage = "Connection successful! MAC address is valid."
                }
            }
        }
    }
}

struct SensorToggleRow: View {
    let title: String
    @Binding var isOn: Bool
    
    init(_ title: String, isOn: Binding<Bool>) {
        self.title = title
        self._isOn = isOn
    }
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}

struct DiscoveredStationsSection: View {
    @StateObject private var weatherService = WeatherStationService.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Discovered Devices")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    let stationCount = weatherService.discoveredStations.filter { $0.type == 1 }.count
                    let cameraCount = weatherService.discoveredStations.filter { $0.type == 2 }.count
                    
                    Text("\(stationCount) weather station\(stationCount == 1 ? "" : "s"), \(cameraCount) camera\(cameraCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(spacing: 4) {
                    Button("Add All Stations") {
                        weatherService.addAllDiscoveredStations()
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                    .disabled(weatherService.discoveredStations.filter { $0.type == 1 }.isEmpty)
                    
                    Button("Associate Cameras") {
                        weatherService.associateCamerasWithStations()
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                    .disabled(weatherService.discoveredStations.filter { $0.type == 2 }.isEmpty)
                }
            }
            
            VStack(spacing: 8) {
                ForEach(weatherService.discoveredStations, id: \.mac) { device in
                    DiscoveredStationRow(device: device)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
    }
}

struct DiscoveredStationRow: View {
    let device: EcowittDevice
    @StateObject private var weatherService = WeatherStationService.shared
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
    
    private func deviceTypeDescription(_ type: Int) -> String {
        switch type {
        case 1: return "Gateway"
        case 2: return "Camera"
        default: return "Type \(type)"
        }
    }
    
    private func deviceTypeColor(_ type: Int) -> Color {
        switch type {
        case 1: return .blue
        case 2: return .purple
        default: return .gray
        }
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(device.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text(deviceTypeDescription(device.type))
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(deviceTypeColor(device.type).opacity(0.2))
                        .foregroundColor(deviceTypeColor(device.type))
                        .cornerRadius(4)
                }
                
                Text(device.mac)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .font(.system(.caption, design: .monospaced))
                
                if let stationType = device.stationtype {
                    Text("Model: \(stationType)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                if let createtime = device.createtime {
                    let date = Date(timeIntervalSince1970: TimeInterval(createtime))
                    Text("Created: \(date, formatter: dateFormatter)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                if let longitude = device.longitude, let latitude = device.latitude {
                    Text("Location: \(String(format: "%.4f", latitude)), \(String(format: "%.4f", longitude))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(spacing: 4) {
                // Check if already added as a station
                if weatherService.weatherStations.contains(where: { $0.macAddress == device.mac }) {
                    Text("Added as Station")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(4)
                } else if device.type == 1 {
                    // Weather station - can be added
                    Button("Add as Station") {
                        weatherService.addDiscoveredStation(device)
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                } else if device.type == 2 {
                    // Camera - show different options
                    Text("Camera Device")
                        .font(.caption2)
                        .foregroundColor(.purple)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(4)
                } else {
                    // Unknown device type
                    Button("Add Device") {
                        weatherService.addDiscoveredStation(device)
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                }
            }
        }
        .padding()
        .background(device.type == 2 ? Color.purple.opacity(0.05) : Color.green.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(device.type == 2 ? Color.purple.opacity(0.3) : Color.green.opacity(0.3), lineWidth: 1)
        )
    }
}

struct ExistingStationsSection: View {
    let applicationKey: String
    let apiKey: String
    let testIndividualStation: (WeatherStation) -> Void
    let copyAPIURL: (WeatherStation) -> Void
    
    @StateObject private var weatherService = WeatherStationService.shared
    @State private var showingEditStation = false
    @State private var editingStation: WeatherStation?
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }
    
    var body: some View {
        VStack(spacing: 8) {
            ForEach(weatherService.weatherStations) { station in
                ExistingStationRow(
                    station: station,
                    applicationKey: applicationKey,
                    apiKey: apiKey,
                    testIndividualStation: testIndividualStation,
                    copyAPIURL: copyAPIURL,
                    editingStation: $editingStation,
                    showingEditStation: $showingEditStation
                )
            }
        }
        .sheet(isPresented: $showingEditStation) {
            if let station = editingStation {
                EditWeatherStationView(station: station)
            }
        }
    }
}

struct ExistingStationRow: View {
    let station: WeatherStation
    let applicationKey: String
    let apiKey: String
    let testIndividualStation: (WeatherStation) -> Void
    let copyAPIURL: (WeatherStation) -> Void
    @Binding var editingStation: WeatherStation?
    @Binding var showingEditStation: Bool
    
    @StateObject private var weatherService = WeatherStationService.shared
    @State private var isUpdatingInfo = false
    @State private var updateMessage = ""
    @State private var updateSuccess = false
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Circle()
                    .fill(station.isActive ? Color.green : Color.gray)
                    .frame(width: 10, height: 10)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(station.name)
                        .font(.headline)
                    Text(station.macAddress)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let lastUpdated = station.lastUpdated {
                        Text("Last updated: \(lastUpdated, formatter: dateFormatter)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    // Show location and timezone info
                    if let latitude = station.latitude, let longitude = station.longitude {
                        Text("Location: \(String(format: "%.4f", latitude)), \(String(format: "%.4f", longitude))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    if let timeZoneId = station.timeZoneId {
                        Text("Timezone: \(timeZoneId)")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    } else {
                        Text("⚠️ No timezone data - using device timezone")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                    
                    if let cameraMAC = station.associatedCameraMAC {
                        Text("📷 Camera: \(cameraMAC)")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                }
                
                Spacer()
                
                StationActionButtons(
                    station: station,
                    testIndividualStation: testIndividualStation,
                    copyAPIURL: copyAPIURL,
                    editingStation: $editingStation,
                    showingEditStation: $showingEditStation
                )
                
                Toggle("", isOn: Binding(
                    get: { station.isActive },
                    set: { newValue in
                        var updated = station
                        updated.isActive = newValue
                        weatherService.updateWeatherStation(updated)
                    }
                ))
                
                Button("Remove") {
                    weatherService.removeWeatherStation(station)
                }
                .foregroundColor(.red)
            }
            
            // Show API URL for this station
            if !applicationKey.isEmpty && !apiKey.isEmpty {
                StationAPIURL(station: station, applicationKey: applicationKey, apiKey: apiKey)
            }
            
            if station.menuBarLabel != nil {
                MenuBarLabelEditor(station: station)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
    }
}

struct StationActionButtons: View {
    let station: WeatherStation
    let testIndividualStation: (WeatherStation) -> Void
    let copyAPIURL: (WeatherStation) -> Void
    @Binding var editingStation: WeatherStation?
    @Binding var showingEditStation: Bool
    
    @StateObject private var weatherService = WeatherStationService.shared
    @State private var isUpdatingInfo = false
    @State private var updateMessage = ""
    @State private var updateSuccess = false
    
    var body: some View {
        VStack(spacing: 4) {
            Button("Test") {
                testIndividualStation(station)
            }
            .buttonStyle(.bordered)
            .font(.caption)
            
            Button("Edit") {
                editingStation = station
                showingEditStation = true
            }
            .buttonStyle(.bordered)
            .font(.caption)
            
            Button(isUpdatingInfo ? "Updating..." : "Update Info") {
                updateStationInfo()
            }
            .buttonStyle(.bordered)
            .font(.caption)
            .disabled(isUpdatingInfo)
            
            Button("Copy URL") {
                copyAPIURL(station)
            }
            .buttonStyle(.bordered)
            .font(.caption)
            
            if !updateMessage.isEmpty {
                Text(updateMessage)
                    .font(.caption2)
                    .foregroundColor(updateSuccess ? .green : .red)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    private func updateStationInfo() {
        isUpdatingInfo = true
        updateMessage = ""
        
        Task {
            let result = await weatherService.fetchStationInfo(for: station)
            
            await MainActor.run {
                isUpdatingInfo = false
                updateSuccess = result.success
                updateMessage = result.message
                
                // Clear message after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    updateMessage = ""
                }
            }
        }
    }
}

struct StationAPIURL: View {
    let station: WeatherStation
    let applicationKey: String
    let apiKey: String
    
    var body: some View {
        let apiURL = "https://cdnapi.ecowitt.net/api/v3/device/real_time?application_key=\(applicationKey)&api_key=\(apiKey)&mac=\(station.macAddress)&call_back=all"
        
        VStack(alignment: .leading, spacing: 2) {
            Text("API URL:")
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(apiURL)
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.blue)
                .textSelection(.enabled)
        }
        .padding(.top, 4)
    }
}

struct IntervalButton: View {
    let label: String
    let interval: TimeInterval
    let binding: Binding<TimeInterval>
    let onChanged: () -> Void
    
    var body: some View {
        Button(label) {
            binding.wrappedValue = interval
            onChanged()
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .background(binding.wrappedValue == interval ? Color.accentColor : Color.clear)
        .foregroundColor(binding.wrappedValue == interval ? .white : .primary)
        .cornerRadius(6)
    }
}

struct MenuBarLabelEditor: View {
    let station: WeatherStation
    @StateObject private var weatherService = WeatherStationService.shared
    @State private var customLabel: String = ""
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(station.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(station.macAddress)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .font(.system(.caption2, design: .monospaced))
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                TextField("Short Label", text: $customLabel)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)
                    .font(.system(.body, design: .default))
                    .onChange(of: customLabel) { _, newValue in
                        // Limit to 8 characters for menubar display
                        if newValue.count > 8 {
                            customLabel = String(newValue.prefix(8))
                        }
                        updateStationLabel(newValue)
                    }
                
                Text("\(customLabel.count)/8 chars")
                    .font(.caption2)
                    .foregroundColor(customLabel.count > 6 ? .orange : .secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(6)
        .onAppear {
            customLabel = station.menuBarLabel ?? ""
        }
    }
    
    private func updateStationLabel(_ newLabel: String) {
        if let index = weatherService.weatherStations.firstIndex(where: { $0.id == station.id }) {
            var updatedStation = weatherService.weatherStations[index]
            updatedStation.menuBarLabel = newLabel.isEmpty ? nil : newLabel
            weatherService.updateWeatherStation(updatedStation)
            
            // Trigger menubar update
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NotificationCenter.default.post(name: .weatherDataUpdated, object: nil)
            }
        }
    }
}

#Preview {
    SettingsView()
}