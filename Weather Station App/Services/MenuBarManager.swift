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
    private let forecastService = WeatherForecastService.shared
    private var cycleThroughTimer: Timer?
    private var backgroundRefreshTimer: Timer?
    
    @Published var isMenuBarEnabled: Bool = false {
        didSet {
            DispatchQueue.main.async {
                if self.isMenuBarEnabled {
                    self.setupStatusItem()
                    self.startBackgroundRefresh()
                } else {
                    self.removeStatusItem()
                    self.stopBackgroundRefresh()
                }
                UserDefaults.standard.set(self.isMenuBarEnabled, forKey: "MenuBarEnabled")
            }
        }
    }
    
    @Published var hideDockIcon: Bool = false {
        didSet {
            UserDefaults.standard.set(hideDockIcon, forKey: "HideDockIcon")
            DispatchQueue.main.async {
                self.updateDockVisibility()
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
    
    @Published var showDecimals: Bool = false {
        didSet {
            UserDefaults.standard.set(showDecimals, forKey: "MenuBarShowDecimals")
            DispatchQueue.main.async {
                self.updateMenuBarTitle()
            }
        }
    }
    
    @Published var showRainIcon: Bool = true {
        didSet {
            UserDefaults.standard.set(showRainIcon, forKey: "MenuBarShowRainIcon")
            DispatchQueue.main.async {
                self.updateMenuBarTitle()
            }
        }
    }
    
    @Published var showUVIcon: Bool = true {
        didSet {
            UserDefaults.standard.set(showUVIcon, forKey: "MenuBarShowUVIcon")
            DispatchQueue.main.async {
                self.updateMenuBarTitle()
            }
        }
    }
    
    @Published var showNightIcon: Bool = false {
        didSet {
            UserDefaults.standard.set(showNightIcon, forKey: "MenuBarShowNightIcon")
            DispatchQueue.main.async {
                self.updateMenuBarTitle()
            }
        }
    }
    
    @Published var showCloudyIcon: Bool = true {
        didSet {
            UserDefaults.standard.set(showCloudyIcon, forKey: "MenuBarShowCloudyIcon")
            DispatchQueue.main.async {
                self.updateMenuBarTitle()
            }
        }
    }
    
    @Published var backgroundRefreshEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(backgroundRefreshEnabled, forKey: "MenuBarBackgroundRefreshEnabled")
            if backgroundRefreshEnabled && isMenuBarEnabled {
                startBackgroundRefresh()
            } else if !backgroundRefreshEnabled {
                stopBackgroundRefresh()
            }
        }
    }
    
    @Published var backgroundRefreshInterval: TimeInterval = 600 { // 10 minutes default (longer than main app)
        didSet {
            UserDefaults.standard.set(backgroundRefreshInterval, forKey: "MenuBarBackgroundRefreshInterval")
            if backgroundRefreshEnabled && isMenuBarEnabled {
                startBackgroundRefresh()
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
                self.startBackgroundRefresh()
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
    
    deinit {
        logMemory("MenuBarManager deinit - cleaning up resources")
        
        // Remove all observers
        NotificationCenter.default.removeObserver(self)
        
        // Stop and clean up timers
        stopCyclingTimer()
        stopBackgroundRefresh()
        
        // Remove status item
        if let statusItem = statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
        }
        
        logMemory("MenuBarManager cleanup completed")
    }
    
    private func loadSettings() {
        isMenuBarEnabled = UserDefaults.standard.bool(forKey: "MenuBarEnabled")
        hideDockIcon = UserDefaults.standard.bool(forKey: "HideDockIcon")
        selectedStationMac = UserDefaults.standard.string(forKey: "MenuBarSelectedStation") ?? ""
        showStationName = UserDefaults.standard.bool(forKey: "MenuBarShowStationName")
        cycleInterval = UserDefaults.standard.object(forKey: "MenuBarCycleInterval") as? TimeInterval ?? 10.0
        showDecimals = UserDefaults.standard.bool(forKey: "MenuBarShowDecimals")
        showRainIcon = UserDefaults.standard.object(forKey: "MenuBarShowRainIcon") as? Bool ?? true
        showUVIcon = UserDefaults.standard.object(forKey: "MenuBarShowUVIcon") as? Bool ?? true
        showNightIcon = UserDefaults.standard.bool(forKey: "MenuBarShowNightIcon")
        showCloudyIcon = UserDefaults.standard.object(forKey: "MenuBarShowCloudyIcon") as? Bool ?? true
        
        backgroundRefreshEnabled = UserDefaults.standard.object(forKey: "MenuBarBackgroundRefreshEnabled") as? Bool ?? true
        backgroundRefreshInterval = UserDefaults.standard.object(forKey: "MenuBarBackgroundRefreshInterval") as? TimeInterval ?? 600 // 10 minutes default
        
        // Apply dock visibility setting on load
        DispatchQueue.main.async {
            self.updateDockVisibility()
        }
        
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
            self,
            selector: #selector(weatherDataUpdated),
            name: .weatherDataUpdated,
            object: nil
        )
        
        // Listen for unit system changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(unitSystemChanged),
            name: .unitSystemChanged,
            object: nil
        )
        
        // Listen for when weather stations are loaded/updated
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(weatherStationsUpdated),
            name: .weatherStationsUpdated,
            object: nil
        )
        
        // Listen for forecast data updates
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(forecastDataUpdated),
            name: .forecastDataUpdated,
            object: nil
        )
        
        // Listen for app termination to clean up
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillTerminate),
            name: NSApplication.willTerminateNotification,
            object: nil
        )
        
        // Listen for main app visibility changes from AppStateManager
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(mainAppBecameVisible),
            name: .mainAppVisible,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(mainAppBecameHidden),
            name: .mainAppHidden,
            object: nil
        )
    }
    
    @objc private func weatherDataUpdated() {
        DispatchQueue.main.async { [weak self] in
            self?.updateMenuBarTitle()
        }
    }
    
    @objc private func unitSystemChanged() {
        DispatchQueue.main.async { [weak self] in
            self?.updateMenuBarTitle()
        }
    }
    
    @objc private func weatherStationsUpdated() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.updateMenuBarTitle()
        }
    }
    
    @objc private func forecastDataUpdated() {
        DispatchQueue.main.async { [weak self] in
            self?.updateMenuBarTitle()
        }
    }
    
    @objc private func appWillTerminate() {
        logMemory("App will terminate - cleaning up MenuBarManager")
        
        // Stop timers immediately
        stopCyclingTimer()
        stopBackgroundRefresh()
        
        // Remove status item
        removeStatusItem()
        
        // Remove all observers
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func mainAppBecameVisible() {
        logRefresh("MenuBar received mainAppVisible notification - stopping background refresh")
        stopBackgroundRefresh()
    }
    
    @objc private func mainAppBecameHidden() {
        logRefresh("MenuBar received mainAppHidden notification - starting background refresh if enabled")
        if backgroundRefreshEnabled && isMenuBarEnabled {
            startBackgroundRefresh()
        }
    }
    
    private func setupStatusItem() {
        guard statusItem == nil else { return }
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.title = "Loading..."
        statusItem?.button?.action = #selector(statusItemClicked)
        statusItem?.button?.target = self
        
        // Add context menu for right-click
        setupContextMenu()
        
        // Enable tooltip
        statusItem?.button?.toolTip = "Loading weather data..."
        
        updateMenuBarTitle()
        
        // Load forecast data for better weather icons
        loadForecastDataForMenuBar()
    }
    
    private func setupContextMenu() {
        let menu = NSMenu()
        
        // Open App menu item
        let openAppItem = NSMenuItem(title: "Open Weather Station App", action: #selector(statusItemClicked), keyEquivalent: "")
        openAppItem.target = self
        menu.addItem(openAppItem)
        
        // Separator
        menu.addItem(NSMenuItem.separator())
        
        // Refresh Data menu item
        let refreshItem = NSMenuItem(title: "Refresh Data", action: #selector(refreshWeatherData), keyEquivalent: "")
        refreshItem.target = self
        menu.addItem(refreshItem)
        
        // Separator
        menu.addItem(NSMenuItem.separator())
        
        // Quit menu item
        let quitItem = NSMenuItem(title: "Quit Weather Station App", action: #selector(quitApplication), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
    }
    
    @objc private func refreshWeatherData() {
        logRefresh("Manual refresh requested from menu bar")
        // Force immediate refresh
        Task {
            await weatherService.fetchAllWeatherData(forceRefresh: true)
        }
    }
    
    @objc private func quitApplication() {
        logInfo("Quit requested from menu bar context menu")
        NSApplication.shared.terminate(nil)
    }
    
    private func loadForecastDataForMenuBar() {
        Task {
            let activeStations = weatherService.weatherStations.filter { $0.isActive && $0.latitude != nil && $0.longitude != nil }
            if !activeStations.isEmpty {
                await forecastService.fetchForecastsForAllStations(activeStations)
                
                // Update menubar after forecast data is loaded
                await MainActor.run {
                    self.updateMenuBarTitle()
                }
            }
        }
    }
    
    private func removeStatusItem() {
        if let statusItem = statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
        }
    }
    
    @objc private func statusItemClicked() {
        logUI("MenuBar clicked - attempting to show app")
        
        // Activate the app first
        NSApp.activate(ignoringOtherApps: true)
        
        // Try to find existing main window
        let mainWindows = NSApp.windows.filter { window in
            !window.className.contains("StatusBar") && 
            !window.className.contains("Item") &&
            window.contentView != nil &&
            window.frame.width > 500
        }
        
        if let existingWindow = mainWindows.first {
            logUI("Found existing window - bringing to front")
            
            if existingWindow.isMiniaturized {
                existingWindow.deminiaturize(nil)
            }
            
            existingWindow.makeKeyAndOrderFront(nil)
            existingWindow.orderFrontRegardless()
            
        } else {
            logWarning("No existing window found - using simple notification approach")
            
            // Use a simple notification that ContentView will handle
            NotificationCenter.default.post(name: .showMainWindow, object: nil)
            
            // Give it a moment, then try to activate any window that appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                NSApp.activate(ignoringOtherApps: true)
                
                // Look for any new windows
                if let newWindow = NSApp.windows.first(where: { window in
                    !window.className.contains("StatusBar") && 
                    !window.className.contains("Item") &&
                    window.contentView != nil &&
                    window.frame.width > 500
                }) {
                    newWindow.makeKeyAndOrderFront(nil)
                    logSuccess("Found and activated new window")
                } else {
                    logWarning("No window appeared after notification")
                }
            }
        }
        
        // Navigate to selected station
        if let selectedStation = getSelectedStation() {
            NotificationCenter.default.post(
                name: .navigateToStation, 
                object: nil, 
                userInfo: ["stationMAC": selectedStation.macAddress]
            )
            logUI("Posted navigation to station: \(selectedStation.name)")
        }
    }
    
    private func updateMenuBarTitle() {
        guard let statusItem = statusItem else { return }
        
        let title = getMenuBarTitle()
        statusItem.button?.title = title
        
        // Update tooltip with detailed information
        statusItem.button?.toolTip = getMenuBarTooltip()
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
        let weatherIcon = getWeatherIconForStation(weatherData, station: station)
        
        let baseTitle: String
        if showStationName && weatherService.weatherStations.count > 1 {
            let displayLabel = station.displayLabelForMenuBar
            baseTitle = "\(displayLabel): \(weatherIcon)\(tempString)"
        } else {
            baseTitle = "\(weatherIcon)\(tempString)"
        }
        
        return baseTitle
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
                let weatherIcon = getWeatherIconForStation(weatherData, station: station)
                let displayLabel = station.displayLabelForMenuBar
                
                // Use even shorter labels for "all stations" mode
                let shortLabel = displayLabel.count > 4 ? 
                    String(displayLabel.prefix(4)) + ":" : displayLabel + ":"
                tempStrings.append("\(shortLabel)\(weatherIcon)\(tempString)")
            }
        }
        
        if tempStrings.isEmpty {
            return "Loading..."
        }
        
        // Join with separator and truncate if too long
        let combined = tempStrings.joined(separator: " | ")
        return combined.count > 60 ? String(combined.prefix(57)) + "…" : combined
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
        let weatherIcon = getWeatherIconForStation(weatherData, station: station)
        
        let baseTitle: String
        if showStationName {
            let displayLabel = station.displayLabelForMenuBar
            baseTitle = "\(displayLabel): \(weatherIcon)\(tempString)"
        } else {
            baseTitle = "\(weatherIcon)\(tempString)"
        }
        
        return baseTitle
    }
    
    // Helper method to get weather icon for a specific station
    private func getWeatherIconForStation(_ weatherData: WeatherStationData, station: WeatherStation) -> String {
        logWeather("Getting weather icon for station: \(station.name)")
        
        // Priority 1: Use Open-Meteo forecast icon if available
        if let forecastIcon = getForecastIconForStation(station) {
            logWeather("  Using forecast icon: \(forecastIcon)")
            return forecastIcon
        }
        
        logDebug("  - showRainIcon: \(showRainIcon)")
        logDebug("  - showUVIcon: \(showUVIcon)")
        logDebug("  - showCloudyIcon: \(showCloudyIcon)")
        logDebug("  - showNightIcon: \(showNightIcon)")
        
        // Fallback to current weather condition icons
        // Priority 2: Rain (highest priority)
        if showRainIcon && isRaining(weatherData) {
            let icon = getRainIconString()
            logWeather("  Selected rain icon: \(icon)")
            return icon
        }
        
        // Priority 3: High UV (sunny conditions)
        if showUVIcon && hasSignificantUV(weatherData) {
            let icon = getUVIconString()
            logWeather("  Selected UV icon: \(icon)")
            return icon
        }
        
        // Priority 4: Cloudy daytime (overcast but still daylight)
        if showCloudyIcon && isCloudyDaytime(weatherData) {
            let icon = getCloudyIconString()
            logWeather("  Selected cloudy icon: \(icon)")
            return icon
        }
        
        // Priority 5: Night time (lowest priority) - now using actual sunset/sunrise
        if showNightIcon && isNightTime(weatherData, for: station) {
            let icon = getNightIconString()
            logWeather("  Selected night icon: \(icon)")
            return icon
        }
        
        return ""
    }
    
    // New method to get forecast-based weather icon
    private func getForecastIconForStation(_ station: WeatherStation) -> String? {
        guard let forecast = forecastService.getForecast(for: station) else {
            logWeather("  No forecast data available for \(station.name)")
            return nil
        }
        
        // Find today's forecast
        guard let todaysForecast = forecast.dailyForecasts.first(where: { $0.isToday }) else {
            logWeather("  No today's forecast found for \(station.name)")
            return nil
        }
        
        // Get the day/night adapted icon
        let baseIcon = todaysForecast.weatherIcon
        let adaptedIcon = WeatherIconHelper.adaptIconForTimeOfDay(baseIcon, station: station)
        
        // Convert the SF Symbol to an emoji equivalent for menubar display
        return convertSFSymbolToEmoji(adaptedIcon)
    }
    
    // Helper method to convert SF Symbols to appropriate emoji for menubar
    private func convertSFSymbolToEmoji(_ sfSymbol: String) -> String? {
        switch sfSymbol {
        // Day icons
        case "sun.max.fill", "sun.max":
            return "☀️"
        case "cloud.sun.fill":
            return "⛅"
            
        // Night icons
        case "moon.stars.fill":
            return "🌙"
        case "moon.fill":
            return "🌙"
        case "cloud.moon.fill":
            return "☁️" // Cloudy night still uses cloud emoji
        case "cloud.moon.rain.fill":
            return "🌧️"
        case "cloud.moon.bolt.fill":
            return "⛈️"
            
        // Weather conditions (day/night agnostic)
        case "cloud.fill":
            return "☁️"
        case "cloud.fog.fill":
            return "🌫️"
        case "cloud.drizzle.fill":
            return "🌦️"
        case "cloud.rain.fill":
            return "🌧️"
        case "cloud.heavyrain.fill":
            return "🌧️"
        case "cloud.sleet.fill":
            return "🌨️"
        case "cloud.snow.fill":
            return "🌨️"
        case "cloud.bolt.fill", "cloud.bolt.rain.fill":
            return "⛈️"
        default:
            return nil
        }
    }
    
    private func formatTemperature(_ tempF: Double) -> String {
        let unitSystem = UserDefaults.standard.unitSystemDisplayMode
        
        switch temperatureDisplayMode {
        case .fahrenheit:
            if showDecimals {
                return String(format: "%.1f°F", tempF)
            } else {
                return "\(Int(round(tempF)))°F"
            }
        case .celsius:
            let tempC = (tempF - 32) * 5/9
            if showDecimals {
                return String(format: "%.1f°C", tempC)
            } else {
                return "\(Int(round(tempC)))°C"
            }
        case .both:
            let tempC = (tempF - 32) * 5/9
            if showDecimals {
                return String(format: "%.1f°F/%.1f°C", tempF, tempC)
            } else {
                return "\(Int(round(tempF)))°F/\(Int(round(tempC)))°C"
            }
        case .auto:
            // Use the app's unit system preference
            switch unitSystem {
            case .imperial:
                if showDecimals {
                    return String(format: "%.1f°F", tempF)
                } else {
                    return "\(Int(round(tempF)))°F"
                }
            case .metric:
                let tempC = (tempF - 32) * 5/9
                if showDecimals {
                    return String(format: "%.1f°C", tempC)
                } else {
                    return "\(Int(round(tempC)))°C"
                }
            case .both:
                let tempC = (tempF - 32) * 5/9
                if showDecimals {
                    return String(format: "%.1f°F/%.1f°C", tempF, tempC)
                } else {
                    return "\(Int(round(tempF)))°F/\(Int(round(tempC)))°C"
                }
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
    
    // MARK: - Rain Detection Helpers
    
    private func getRainIcon(for weatherData: WeatherStationData) -> String {
        guard showRainIcon && isRaining(weatherData) else { return "" }
        return getRainIconString()
    }
    
    private func getRainIconString() -> String {
        return "💧" // Raindrop emoji
    }
    
    private func getUVIconString() -> String {
        return "☀️" // Sun emoji
    }
    
    private func getNightIconString() -> String {
        return "🌙" // Moon emoji
    }
    
    private func getCloudyIconString() -> String {
        return "☁️" // Cloud emoji
    }
    
    private func isRaining(_ weatherData: WeatherStationData) -> Bool {
        // Check piezo rain gauge status - this is the primary indicator
        let stateString = weatherData.rainfallPiezo.state.value
        let rainRateString = weatherData.rainfallPiezo.rainRate.value
        
        // Debug logging to understand what we're getting
        logWeather("Rain Detection Debug:")
        logWeather("  - Piezo State: '\(stateString)' (unit: \(weatherData.rainfallPiezo.state.unit))")
        logWeather("  - Rain Rate: '\(rainRateString)' (unit: \(weatherData.rainfallPiezo.rainRate.unit))")
        
        // Primary check: piezo state (this is the key indicator for active rain)
        if let state = Double(stateString) {
            logWeather("  - Parsed piezo state: \(state)")
            // Piezo state typically indicates: 0 = not raining, 1 = raining
            // Some systems might use different values, so check for any positive value
            if state > 0.0 {
                logWeather("  Rain detected via piezo state: \(state)")
                return true
            }
        } else {
            // Handle case where state might be a string like "raining" or "dry"
            let stateLower = stateString.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            logWeather("  - Piezo state as string: '\(stateLower)'")
            
            if stateLower == "raining" || stateLower == "rain" || stateLower == "wet" || stateLower == "1" {
                logWeather("  Rain detected via piezo state string: '\(stateLower)'")
                return true
            }
        }
        
        // Secondary check: current rain rate (immediate rainfall)
        if let rainRate = Double(rainRateString), rainRate > 0.0 {
            logWeather("  Rain detected via current rate: \(rainRate)")
            return true
        }
        
        logWeather("  No active rain detected")
        return false
    }
    
    private func hasHighUV(_ weatherData: WeatherStationData) -> Bool {
        return hasSignificantUV(weatherData)
    }
    
    private func hasSignificantUV(_ weatherData: WeatherStationData) -> Bool {
        let solarString = weatherData.solarAndUvi.solar.value
        guard let solarValue = Double(solarString) else {
            return false
        }
        
        // Use solar radiation instead of UV index for more accurate detection
        // Clear sunny conditions: 600+ W/m² (typical peak solar radiation)
        // This provides more responsive and accurate sunny weather detection
        return solarValue >= 600.0
    }
    
    private func isNightTime(_ weatherData: WeatherStationData, for station: WeatherStation) -> Bool {
        // Use actual sunrise/sunset calculation if coordinates are available
        if let latitude = station.latitude,
           let longitude = station.longitude {
            
            let sunTimes = SunCalculator.calculateSunTimes(
                for: Date(),
                latitude: latitude,
                longitude: longitude,
                timeZone: station.timeZone
            )
            
            // Return true if it's currently NOT daylight (i.e., between sunset and sunrise)
            return sunTimes?.isCurrentlyDaylight == false
        }
        
        // Fallback to solar radiation if coordinates are not available
        let solarString = weatherData.solarAndUvi.solar.value
        guard let solarValue = Double(solarString) else {
            return false
        }
        
        // Very low solar radiation indicates nighttime
        return solarValue < 50.0 // Nighttime threshold
    }
    
    private func isCloudyDaytime(_ weatherData: WeatherStationData) -> Bool {
        let solarString = weatherData.solarAndUvi.solar.value
        
        guard let solarValue = Double(solarString) else {
            return false
        }
        
        // Cloudy/overcast daytime: moderate solar radiation
        // Between nighttime threshold and sunny threshold
        // 50-600 W/m² range indicates daylight but not clear/sunny
        return solarValue >= 50.0 && solarValue < 600.0
    }
    
    // MARK: - Updated Weather Icon Helpers
    
    // Fallback method for when we can't determine the station
    private func getWeatherIconWithoutStation(for weatherData: WeatherStationData) -> String {
        // Priority 1: Rain (highest priority)
        if showRainIcon && isRaining(weatherData) {
            return getRainIconString()
        }
        
        // Priority 2: High UV (sunny conditions)
        if showUVIcon && hasSignificantUV(weatherData) {
            return getUVIconString()
        }
        
        // Priority 3: Cloudy daytime (overcast but still daylight)
        if showCloudyIcon && isCloudyDaytime(weatherData) {
            return getCloudyIconString()
        }
        
        // Priority 4: Night time (lowest priority) - fallback to solar radiation
        if showNightIcon && isNightTimeFallback(weatherData) {
            return getNightIconString()
        }
        
        return ""
    }
    
    private func isNightTimeFallback(_ weatherData: WeatherStationData) -> Bool {
        let solarString = weatherData.solarAndUvi.solar.value
        
        guard let solarValue = Double(solarString) else {
            return false
        }
        
        // Use solar radiation for nighttime detection as fallback
        // Very low solar radiation indicates true nighttime
        return solarValue < 50.0 // Nighttime threshold
    }
    
    private func setupCyclingTimer() {
        stopCyclingTimer() // Stop any existing timer
        
        guard displayMode == .cycleThrough, availableStations.count > 1 else { return }
        
        cycleThroughTimer = Timer.scheduledTimer(withTimeInterval: cycleInterval, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.cycleToNextStation()
            }
        }
        
        logTimer("Started cycling through \(availableStations.count) stations every \(Int(cycleInterval))s")
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
        
        logTimer("Cycled to station: \(nextStation.name)")
    }
    
    // MARK: - Background Refresh Management
    
    private func startBackgroundRefresh() {
        stopBackgroundRefresh() // Stop any existing timer
        
        guard backgroundRefreshEnabled && isMenuBarEnabled && !availableStations.isEmpty else {
            logRefresh("MenuBar refresh not started - disabled or no stations")
            return
        }
        
        backgroundRefreshTimer = Timer.scheduledTimer(withTimeInterval: backgroundRefreshInterval, repeats: true) { [weak self] timer in
            guard let self = self else {
                logError("MenuBarManager deallocated, stopping background refresh timer")
                timer.invalidate()
                return
            }
            
            logRefresh("MenuBar background refresh timer fired at \(Date())")
            
            // Check if any data is stale before fetching - be more aggressive about refreshing
            let staleStations = self.weatherService.weatherStations.filter { station in
                guard station.isActive else { return false }
                
                // Consider data stale if:
                // 1. We have no data at all for this station
                // 2. The data is older than our freshness duration (2 minutes)
                // 3. The last update was more than 5 minutes ago (safety margin)
                
                if self.weatherService.weatherData[station.macAddress] == nil {
                    logRefresh("  Station \(station.name) has no data - needs refresh")
                    return true
                }
                
                guard let lastUpdated = station.lastUpdated else {
                    logRefresh("  Station \(station.name) has no lastUpdated timestamp - needs refresh")
                    return true
                }
                
                let dataAge = Date().timeIntervalSince(lastUpdated)
                let isStale = dataAge > 300 // 5 minutes - more aggressive than the 2 minute default
                
                if isStale {
                    logRefresh("  Station \(station.name) data is stale (age: \(Int(dataAge))s) - needs refresh")
                } else {
                    logRefresh("  Station \(station.name) data is fresh (age: \(Int(dataAge))s)")
                }
                
                return isStale
            }
            
            if !staleStations.isEmpty {
                logRefresh("Found \(staleStations.count) stations with stale data")
                
                Task { @MainActor in
                    logRefresh("Starting background refresh for stale menu bar data")
                    await self.weatherService.fetchAllWeatherData(forceRefresh: false) // Smart refresh
                    logRefresh("MenuBar background refresh completed at \(Date())")
                }
            } else {
                logRefresh("All menu bar data is fresh, skipping background refresh")
            }
        }
        
        let minutes = Int(backgroundRefreshInterval / 60)
        logRefresh("MenuBar background refresh started: every \(minutes) minute\(minutes == 1 ? "" : "s")")
        
        // Run an initial refresh after a short delay if data is stale
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            let staleStations = self.weatherService.weatherStations.filter { station in
                guard station.isActive else { return false }
                
                if self.weatherService.weatherData[station.macAddress] == nil {
                    return true
                }
                
                guard let lastUpdated = station.lastUpdated else {
                    return true
                }
                
                return Date().timeIntervalSince(lastUpdated) > 300 // 5 minutes
            }
            
            if !staleStations.isEmpty {
                logRefresh("Running initial menubar background refresh for \(staleStations.count) stations with stale data")
                Task {
                    await self.weatherService.fetchAllWeatherData(forceRefresh: false)
                }
            } else {
                logRefresh("All menubar data is fresh on startup")
            }
        }
    }
    
    private func stopBackgroundRefresh() {
        backgroundRefreshTimer?.invalidate()
        backgroundRefreshTimer = nil
        logRefresh("MenuBar background refresh stopped")
    }
    
    // MARK: - Dock Visibility
    
    private func getMenuBarTooltip() -> String {
        switch displayMode {
        case .singleStation:
            return getSingleStationTooltip()
        case .allStations:
            return getAllStationsTooltip()
        case .cycleThrough:
            return getCycleStationTooltip()
        }
    }
    
    private func getSingleStationTooltip() -> String {
        guard let station = getSelectedStation() else {
            return "No active weather station"
        }
        
        guard let weatherData = weatherService.weatherData[station.macAddress],
              let temp = Double(weatherData.outdoor.temperature.value) else {
            return "\(station.name)\nLoading weather data..."
        }
        
        var tooltipLines: [String] = []
        
        // Station name
        tooltipLines.append("📍 \(station.name)")
        tooltipLines.append("")
        
        // Temperature
        let tempString = formatTemperature(temp)
        tooltipLines.append("🌡️ Temperature: \(tempString)")
        
        // Feels like temperature
        if let feelsLike = Double(weatherData.outdoor.feelsLike.value) {
            let feelsLikeString = formatTemperature(feelsLike)
            tooltipLines.append("🤚 Feels Like: \(feelsLikeString)")
        }
        
        // Humidity
        if let humidity = Double(weatherData.outdoor.humidity.value) {
            tooltipLines.append("💧 Humidity: \(Int(humidity))%")
        }
        
        // Wind
        if let windSpeed = Double(weatherData.wind.windSpeed.value) {
            let unitSystem = UserDefaults.standard.unitSystemDisplayMode
            let windString = formatWindSpeed(windSpeed, unitSystem: unitSystem)
            
            if let windDir = Double(weatherData.wind.windDirection.value) {
                let direction = getWindDirection(windDir)
                tooltipLines.append("💨 Wind: \(windString) \(direction)")
            } else {
                tooltipLines.append("💨 Wind: \(windString)")
            }
        }
        
        // Pressure
        if let pressure = Double(weatherData.pressure.relative.value) {
            let unitSystem = UserDefaults.standard.unitSystemDisplayMode
            let pressureString = formatPressure(pressure, unitSystem: unitSystem)
            tooltipLines.append("📊 Pressure: \(pressureString)")
        }
        
        // Rainfall
        let rainRateString = weatherData.rainfallPiezo.rainRate.value
        if let rainRate = Double(rainRateString), rainRate > 0 {
            let unitSystem = UserDefaults.standard.unitSystemDisplayMode
            let rainString = formatRainRate(rainRate, unitSystem: unitSystem)
            tooltipLines.append("🌧️ Rain Rate: \(rainString)")
        }
        
        // UV Index
        if let uvi = Double(weatherData.solarAndUvi.uvi.value) {
            tooltipLines.append("☀️ UV Index: \(String(format: "%.1f", uvi))")
        }
        
        tooltipLines.append("")
        
        // Last update time
        if let lastUpdated = station.lastUpdated {
            let timeAgo = getTimeAgoString(from: lastUpdated)
            tooltipLines.append("🕐 Updated: \(timeAgo)")
        }
        
        return tooltipLines.joined(separator: "\n")
    }
    
    private func getAllStationsTooltip() -> String {
        let stations = availableStations
        
        if stations.isEmpty {
            return "No active weather stations"
        }
        
        var tooltipLines: [String] = []
        tooltipLines.append("All Active Stations")
        tooltipLines.append("")
        
        for station in stations {
            if let weatherData = weatherService.weatherData[station.macAddress],
               let temp = Double(weatherData.outdoor.temperature.value) {
                let tempString = formatTemperature(temp)
                let weatherIcon = getWeatherIconForStation(weatherData, station: station)
                
                var stationLine = "\(weatherIcon) \(station.name): \(tempString)"
                
                // Add last update time for this station
                if let lastUpdated = station.lastUpdated {
                    let timeAgo = getTimeAgoString(from: lastUpdated)
                    stationLine += " (\(timeAgo))"
                }
                
                tooltipLines.append(stationLine)
            } else {
                tooltipLines.append("⏳ \(station.name): Loading...")
            }
        }
        
        tooltipLines.append("")
        tooltipLines.append("Click to open app • Right-click for options")
        
        return tooltipLines.joined(separator: "\n")
    }
    
    private func getCycleStationTooltip() -> String {
        let stations = availableStations
        
        if stations.isEmpty {
            return "No active weather stations"
        }
        
        // Ensure current index is valid
        if currentCycleIndex >= stations.count {
            currentCycleIndex = 0
        }
        
        let station = stations[currentCycleIndex]
        
        guard let weatherData = weatherService.weatherData[station.macAddress],
              let temp = Double(weatherData.outdoor.temperature.value) else {
            return "\(station.name)\nLoading weather data..."
        }
        
        var tooltipLines: [String] = []
        
        // Current station indicator
        tooltipLines.append("🔄 Cycling Mode (Station \(currentCycleIndex + 1) of \(stations.count))")
        tooltipLines.append("")
        
        // Station name
        tooltipLines.append("📍 \(station.name)")
        tooltipLines.append("")
        
        // Temperature
        let tempString = formatTemperature(temp)
        tooltipLines.append("🌡️ Temperature: \(tempString)")
        
        // Humidity
        if let humidity = Double(weatherData.outdoor.humidity.value) {
            tooltipLines.append("💧 Humidity: \(Int(humidity))%")
        }
        
        // Wind
        if let windSpeed = Double(weatherData.wind.windSpeed.value) {
            let unitSystem = UserDefaults.standard.unitSystemDisplayMode
            let windString = formatWindSpeed(windSpeed, unitSystem: unitSystem)
            tooltipLines.append("💨 Wind: \(windString)")
        }
        
        tooltipLines.append("")
        
        // Show all stations in cycle
        tooltipLines.append("Other Stations:")
        for (index, otherStation) in stations.enumerated() {
            if index != currentCycleIndex {
                if let otherData = weatherService.weatherData[otherStation.macAddress],
                   let otherTemp = Double(otherData.outdoor.temperature.value) {
                    let otherTempString = formatTemperature(otherTemp)
                    tooltipLines.append("  • \(otherStation.name): \(otherTempString)")
                }
            }
        }
        
        tooltipLines.append("")
        
        // Last update time
        if let lastUpdated = station.lastUpdated {
            let timeAgo = getTimeAgoString(from: lastUpdated)
            tooltipLines.append("🕐 Updated: \(timeAgo)")
        }
        
        // Cycling info
        let intervalString = formatCycleInterval(cycleInterval)
        tooltipLines.append("⏱️ Changes every \(intervalString)")
        
        return tooltipLines.joined(separator: "\n")
    }
    
    // MARK: - Tooltip Helper Methods
    
    private func formatWindSpeed(_ windSpeedMPH: Double, unitSystem: UnitSystemDisplayMode) -> String {
        switch unitSystem {
        case .imperial, .both:
            return String(format: "%.1f mph", windSpeedMPH)
        case .metric:
            let windSpeedKMH = windSpeedMPH * 1.60934
            return String(format: "%.1f km/h", windSpeedKMH)
        }
    }
    
    private func formatPressure(_ pressureInHg: Double, unitSystem: UnitSystemDisplayMode) -> String {
        switch unitSystem {
        case .imperial:
            return String(format: "%.2f inHg", pressureInHg)
        case .metric:
            let pressureHPa = pressureInHg * 33.8639
            return String(format: "%.1f hPa", pressureHPa)
        case .both:
            let pressureHPa = pressureInHg * 33.8639
            return String(format: "%.2f inHg / %.1f hPa", pressureInHg, pressureHPa)
        }
    }
    
    private func formatRainRate(_ rainRateInPerHour: Double, unitSystem: UnitSystemDisplayMode) -> String {
        switch unitSystem {
        case .imperial:
            return String(format: "%.2f in/hr", rainRateInPerHour)
        case .metric:
            let rainRateMM = rainRateInPerHour * 25.4
            return String(format: "%.1f mm/hr", rainRateMM)
        case .both:
            let rainRateMM = rainRateInPerHour * 25.4
            return String(format: "%.2f in/hr / %.1f mm/hr", rainRateInPerHour, rainRateMM)
        }
    }
    
    private func getWindDirection(_ degrees: Double) -> String {
        let directions = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE", 
                          "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
        let index = Int((degrees + 11.25) / 22.5) % 16
        return directions[index]
    }
    
    private func getTimeAgoString(from date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        
        if seconds < 60 {
            return "just now"
        } else if seconds < 120 {
            return "1 minute ago"
        } else if seconds < 3600 {
            return "\(seconds / 60) minutes ago"
        } else if seconds < 7200 {
            return "1 hour ago"
        } else {
            return "\(seconds / 3600) hours ago"
        }
    }
    
    private func formatCycleInterval(_ interval: TimeInterval) -> String {
        let seconds = Int(interval)
        
        if seconds < 60 {
            return "\(seconds) second\(seconds == 1 ? "" : "s")"
        } else if seconds < 3600 {
            let minutes = seconds / 60
            return "\(minutes) minute\(minutes == 1 ? "" : "s")"
        } else {
            let hours = seconds / 3600
            return "\(hours) hour\(hours == 1 ? "" : "s")"
        }
    }
    
    private func updateDockVisibility() {
        if hideDockIcon {
            // Hide the dock icon
            NSApp.setActivationPolicy(.accessory)
            logUI("Dock icon hidden")
        } else {
            // Show the dock icon
            NSApp.setActivationPolicy(.regular)
            logUI("Dock icon shown")
        }
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
            return "CycleThrough Stations"
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
    static let showMainWindow = Notification.Name("showMainWindow")
    static let radarSettingsChanged = Notification.Name("radarSettingsChanged")
}