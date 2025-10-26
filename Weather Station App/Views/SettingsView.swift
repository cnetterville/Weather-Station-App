//
//  SettingsView.swift
//  Weather Station App
//
//  Created by Curtis Netterville on 10/25/25.
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var weatherService = WeatherStationService.shared
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
                                            ForEach([("1 min", 60.0), ("2 min", 120.0), ("5 min", 300.0)], id: \.1) { label, interval in
                                                Button(label) {
                                                    refreshIntervalBinding.wrappedValue = interval
                                                    saveAutoRefreshSettings()
                                                    onSettingsChanged?()
                                                }
                                                .buttonStyle(.bordered)
                                                .controlSize(.small)
                                                .background(refreshIntervalBinding.wrappedValue == interval ? Color.accentColor : Color.clear)
                                                .foregroundColor(refreshIntervalBinding.wrappedValue == interval ? .white : .primary)
                                                .cornerRadius(6)
                                            }
                                        }
                                        
                                        // Second row
                                        HStack(spacing: 8) {
                                            ForEach([("10 min", 600.0), ("15 min", 900.0), ("30 min", 1800.0), ("1 hour", 3600.0)], id: \.1) { label, interval in
                                                Button(label) {
                                                    refreshIntervalBinding.wrappedValue = interval
                                                    saveAutoRefreshSettings()
                                                    onSettingsChanged?()
                                                }
                                                .buttonStyle(.bordered)
                                                .controlSize(.small)
                                                .background(refreshIntervalBinding.wrappedValue == interval ? Color.accentColor : Color.clear)
                                                .foregroundColor(refreshIntervalBinding.wrappedValue == interval ? .white : .primary)
                                                .cornerRadius(6)
                                            }
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
                            
                            // Station Discovery Button
                            Button("Discover Stations") {
                                discoverStations()
                            }
                            .buttonStyle(.bordered)
                            .disabled(applicationKey.isEmpty || apiKey.isEmpty || weatherService.isDiscoveringStations)
                            
                            Button("Add Manually") {
                                showingAddStation = true
                            }
                            .buttonStyle(.borderedProminent)
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

    private func saveAutoRefreshSettings() {
        UserDefaults.standard.set(autoRefreshBinding.wrappedValue, forKey: "AutoRefreshEnabled")
        UserDefaults.standard.set(refreshIntervalBinding.wrappedValue, forKey: "RefreshInterval")
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
                                    SensorToggleRow("🌧️ Rainfall", isOn: $sensorPreferences.showRainfall)
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
                    saveChanges()
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
        sensorPreferences.showAirQualityCh1 = value
        sensorPreferences.showAirQualityCh2 = value
        sensorPreferences.showUVIndex = value
        sensorPreferences.showLightning = value
        sensorPreferences.showTempHumidityCh1 = value
        sensorPreferences.showTempHumidityCh2 = value
        sensorPreferences.showTempHumidityCh3 = value
        sensorPreferences.showBatteryStatus = value
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
    
    private func saveChanges() {
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
                Text("Discovered Stations")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Add All") {
                    weatherService.addAllDiscoveredStations()
                }
                .buttonStyle(.bordered)
                .font(.caption)
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
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
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
            
            // Check if already added
            if weatherService.weatherStations.contains(where: { $0.macAddress == device.mac }) {
                Text("Already Added")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(4)
            } else {
                Button("Add") {
                    weatherService.addDiscoveredStation(device)
                }
                .buttonStyle(.bordered)
                .font(.caption)
            }
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
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
            
            Button("Copy URL") {
                copyAPIURL(station)
            }
            .buttonStyle(.bordered)
            .font(.caption)
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

#Preview {
    SettingsView()
}