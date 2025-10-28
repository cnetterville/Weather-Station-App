//
//  MenuBarManager.swift
//  Weather Station App
//
//  Created by Curtis Netterville on 10/25/25.
//

import SwiftUI
import AppKit
import Combine

class MenuBarManager: ObservableObject {
    private var statusItem: NSStatusItem?
    private let weatherService = WeatherStationService.shared
    private var cycleThroughTimer: Timer?
    
    // Add a simple flag for activation requests
    @Published var shouldActivateApp: Bool = false
    
    @Published var isMenuBarEnabled: Bool = false {
        didSet {
            DispatchQueue.main.async {
                if self.isMenuBarEnabled {
                    self.setupStatusItem()
                } else {
                    self.removeStatusItem()
                }
                UserDefaults.standard.set(self.isMenuBarEnabled, forKey: "MenuBarEnabled")
            }
        }
    }
    
    @Published var selectedStationMac: String = "" {
        didSet {
            UserDefaults.standard.set(selectedStationMac, forKey: "MenuBarSelectedStation")
            DispatchQueue.main.async {
                self.updateMenuBarTitle()
                // Reset cycling when station selection changes
                if self.displayMode == .cycleThrough {
                    self.setupCyclingTimer()
                }
            }
        }
    }
    
    @Published var showStationName: Bool = false {
        didSet {
            UserDefaults.standard.set(showStationName, forKey: "MenuBarShowStationName")
            DispatchQueue.main.async {
                self.updateMenuBarTitle()
            }
        }
    }
    
    @Published var temperatureDisplayMode: MenuBarTemperatureMode = .fahrenheit {
        didSet {
            UserDefaults.standard.set(temperatureDisplayMode.rawValue, forKey: "MenuBarTemperatureMode")
            DispatchQueue.main.async {
                self.updateMenuBarTitle()
            }
        }
    }
    
    @Published var displayMode: MenuBarDisplayMode = .singleStation {
        didSet {
            UserDefaults.standard.set(displayMode.rawValue, forKey: "MenuBarDisplayMode")
            DispatchQueue.main.async {
                if self.displayMode == .cycleThrough {
                    self.setupCyclingTimer()
                } else {
                    self.stopCyclingTimer()
                }
                self.updateMenuBarTitle()
            }
        }
    }
    
    @Published var cycleInterval: TimeInterval = 10.0 {
        didSet {
            UserDefaults.standard.set(cycleInterval, forKey: "MenuBarCycleInterval")
            if displayMode == .cycleThrough {
                setupCyclingTimer()
            }
        }
    }
    
    // For cycling through stations
    private var currentCycleIndex = 0

    static let shared = MenuBarManager()
    
    private init() {
        // Load settings synchronously first
        loadSettings()
        
        // Setup observers and status item after main queue
        DispatchQueue.main.async {
            self.setupObservers()
            if self.isMenuBarEnabled {
                self.setupStatusItem()
            }
            
            // Force an initial update after a brief delay to ensure data is loaded
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.updateMenuBarTitle()
                
                // Start cycling if enabled
                if self.displayMode == .cycleThrough {
                    self.setupCyclingTimer()
                }
            }
        }
    }
    
    private func loadSettings() {
        isMenuBarEnabled = UserDefaults.standard.bool(forKey: "MenuBarEnabled")
        selectedStationMac = UserDefaults.standard.string(forKey: "MenuBarSelectedStation") ?? ""
        showStationName = UserDefaults.standard.bool(forKey: "MenuBarShowStationName")
        cycleInterval = UserDefaults.standard.object(forKey: "MenuBarCycleInterval") as? TimeInterval ?? 10.0
        
        if let modeRawValue = UserDefaults.standard.object(forKey: "MenuBarTemperatureMode") as? String,
           let mode = MenuBarTemperatureMode(rawValue: modeRawValue) {
            temperatureDisplayMode = mode
        }
        
        if let displayRawValue = UserDefaults.standard.object(forKey: "MenuBarDisplayMode") as? String,
           let mode = MenuBarDisplayMode(rawValue: displayRawValue) {
            displayMode = mode
        }
    }
    
    private func setupObservers() {
        // Listen for weather data updates
        NotificationCenter.default.addObserver(
            forName: .weatherDataUpdated,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateMenuBarTitle()
        }
        
        // Listen for unit system changes
        NotificationCenter.default.addObserver(
            forName: .unitSystemChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateMenuBarTitle()
        }
        
        // Listen for when weather stations are loaded/updated
        NotificationCenter.default.addObserver(
            forName: .weatherStationsUpdated,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self?.updateMenuBarTitle()
            }
        }
    }
    
    private func setupStatusItem() {
        guard statusItem == nil else { return }
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.title = "Loading..."
        statusItem?.button?.action = #selector(statusItemClicked)
        statusItem?.button?.target = self
        
        updateMenuBarTitle()
    }
    
    private func removeStatusItem() {
        if let statusItem = statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
        }
    }
    
    @objc private func statusItemClicked() {
        print("🖱️ MenuBar item clicked!")
        
        // Use NotificationCenter instead of @Published property
        NotificationCenter.default.post(name: .bringAppToFront, object: nil)
        print("📢 Posted bringAppToFront notification")
        
        // Navigate to selected station
        if let selectedStation = getSelectedStation() {
            print("📍 Posting navigation to station: \(selectedStation.name)")
            NotificationCenter.default.post(
                name: .navigateToStation, 
                object: nil, 
                userInfo: ["stationMAC": selectedStation.macAddress]
            )
        } else {
            print("❌ No selected station found")
        }
    }
    
    private func updateMenuBarTitle() {
        guard let statusItem = statusItem else { return }
        
        let title = getMenuBarTitle()
        statusItem.button?.title = title
        
        // Debug logging to help troubleshoot
        if let station = getSelectedStation() {
            print("🖥️ MenuBar updated: \(title) for station \(station.name)")
        } else {
            print("🖥️ MenuBar updated: \(title) (no station selected)")
        }
    }
    
    private func getMenuBarTitle() -> String {
        switch displayMode {
        case .singleStation:
            return getSingleStationTitle()
        case .allStations:
            return getAllStationsTitle()
        case .cycleThrough:
            return getCycleStationTitle()
        }
    }
    
    private func getSingleStationTitle() -> String {
        guard let station = getSelectedStation() else {
            return "No Station"
        }
        
        guard let weatherData = weatherService.weatherData[station.macAddress],
              let temp = Double(weatherData.outdoor.temperature.value) else {
            let displayLabel = station.displayLabelForMenuBar
            return showStationName ? "\(displayLabel): Loading..." : "Loading..."
        }
        
        let tempString = formatTemperature(temp)
        
        if showStationName && weatherService.weatherStations.count > 1 {
            let displayLabel = station.displayLabelForMenuBar
            return "\(displayLabel): \(tempString)"
        }
        
        return tempString
    }
    
    private func getAllStationsTitle() -> String {
        let stations = availableStations
        
        if stations.isEmpty {
            return "No Stations"
        }
        
        var tempStrings: [String] = []
        for station in stations {
            if let weatherData = weatherService.weatherData[station.macAddress],
               let temp = Double(weatherData.outdoor.temperature.value) {
                let tempString = formatTemperature(temp)
                let displayLabel = station.displayLabelForMenuBar
                // Use even shorter labels for "all stations" mode
                let shortLabel = displayLabel.count > 4 ? 
                    String(displayLabel.prefix(4)) + ":" : displayLabel + ":"
                tempStrings.append("\(shortLabel)\(tempString)")
            }
        }
        
        if tempStrings.isEmpty {
            return "Loading..."
        }
        
        // Join with separator and truncate if too long
        let combined = tempStrings.joined(separator: " | ")
        return combined.count > 50 ? String(combined.prefix(47)) + "…" : combined
    }
    
    private func getCycleStationTitle() -> String {
        let stations = availableStations
        
        if stations.isEmpty {
            return "No Stations"
        }
        
        // Ensure current index is valid
        if currentCycleIndex >= stations.count {
            currentCycleIndex = 0
        }
        
        let station = stations[currentCycleIndex]
        
        guard let weatherData = weatherService.weatherData[station.macAddress],
              let temp = Double(weatherData.outdoor.temperature.value) else {
            return "Loading..."
        }
        
        let tempString = formatTemperature(temp)
        
        if showStationName {
            let displayLabel = station.displayLabelForMenuBar
            return "\(displayLabel): \(tempString)"
        }
        
        return tempString
    }
    
    private func formatTemperature(_ tempF: Double) -> String {
        let unitSystem = UserDefaults.standard.unitSystemDisplayMode
        
        switch temperatureDisplayMode {
        case .fahrenheit:
            return "\(Int(round(tempF)))°F"
        case .celsius:
            let tempC = (tempF - 32) * 5/9
            return "\(Int(round(tempC)))°C"
        case .both:
            let tempC = (tempF - 32) * 5/9
            return "\(Int(round(tempF)))°F/\(Int(round(tempC)))°C"
        case .auto:
            // Use the app's unit system preference
            switch unitSystem {
            case .imperial:
                return "\(Int(round(tempF)))°F"
            case .metric:
                let tempC = (tempF - 32) * 5/9
                return "\(Int(round(tempC)))°C"
            case .both:
                let tempC = (tempF - 32) * 5/9
                return "\(Int(round(tempF)))°F/\(Int(round(tempC)))°C"
            }
        }
    }
    
    private func getSelectedStation() -> WeatherStation? {
        if selectedStationMac.isEmpty {
            // Use the first active station
            return weatherService.weatherStations.first { $0.isActive }
        } else {
            return weatherService.weatherStations.first { $0.macAddress == selectedStationMac }
        }
    }
    
    // Get available stations for selection
    var availableStations: [WeatherStation] {
        return weatherService.weatherStations.filter { $0.isActive }
    }
    
    private func setupCyclingTimer() {
        stopCyclingTimer() // Stop any existing timer
        
        guard displayMode == .cycleThrough, availableStations.count > 1 else { return }
        
        cycleThroughTimer = Timer.scheduledTimer(withTimeInterval: cycleInterval, repeats: true) { _ in
            DispatchQueue.main.async {
                self.cycleToNextStation()
            }
        }
        
        print("🔄 Started cycling through \(availableStations.count) stations every \(Int(cycleInterval))s")
    }
    
    private func stopCyclingTimer() {
        cycleThroughTimer?.invalidate()
        cycleThroughTimer = nil
    }
    
    private func cycleToNextStation() {
        let stations = availableStations
        guard stations.count > 1 else { return }
        
        currentCycleIndex = (currentCycleIndex + 1) % stations.count
        let nextStation = stations[currentCycleIndex]
        
        // Don't trigger the didSet observer for cycling
        UserDefaults.standard.set(nextStation.macAddress, forKey: "MenuBarSelectedStation")
        selectedStationMac = nextStation.macAddress
        updateMenuBarTitle()
        
        print("🔄 Cycled to station: \(nextStation.name)")
    }
}

enum MenuBarDisplayMode: String, CaseIterable, Codable {
    case singleStation = "single"
    case allStations = "all"
    case cycleThrough = "cycle"
    
    var displayName: String {
        switch self {
        case .singleStation:
            return "Single Station"
        case .allStations:
            return "All Stations"
        case .cycleThrough:
            return "Cycle Through Stations"
        }
    }
    
    var description: String {
        switch self {
        case .singleStation:
            return "Show one selected station"
        case .allStations:
            return "Show all stations at once"
        case .cycleThrough:
            return "Rotate through stations automatically"
        }
    }
}

enum MenuBarTemperatureMode: String, CaseIterable, Codable {
    case fahrenheit = "fahrenheit"
    case celsius = "celsius"
    case both = "both"
    case auto = "auto"
    
    var displayName: String {
        switch self {
        case .fahrenheit:
            return "Fahrenheit (°F)"
        case .celsius:
            return "Celsius (°C)"
        case .both:
            return "Both (°F/°C)"
        case .auto:
            return "Follow App Settings"
        }
    }
}

// Notification names
extension Notification.Name {
    static let weatherDataUpdated = Notification.Name("weatherDataUpdated")
    static let unitSystemChanged = Notification.Name("unitSystemChanged")
    static let openSettings = Notification.Name("openSettings")
    static let showSettingsFromMenuBar = Notification.Name("showSettingsFromMenuBar")
    static let navigateToStation = Notification.Name("navigateToStation")
    static let weatherStationsUpdated = Notification.Name("weatherStationsUpdated")
    static let bringAppToFront = Notification.Name("bringAppToFront")
}