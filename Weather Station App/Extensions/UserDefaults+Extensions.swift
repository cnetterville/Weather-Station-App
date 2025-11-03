import Foundation

extension UserDefaults {
    // MARK: - Weather Station Settings
    
    var stationRefreshInterval: TimeInterval {
        get {
            let value = double(forKey: "StationRefreshInterval")
            return value > 0 ? value : 120.0 // Default to 2 minutes
        }
        set {
            set(newValue, forKey: "StationRefreshInterval")
        }
    }
    
    var historicalDataRetention: TimeInterval {
        get {
            let value = double(forKey: "HistoricalDataRetention")
            return value > 0 ? value : 86400.0 // Default to 24 hours
        }
        set {
            set(newValue, forKey: "HistoricalDataRetention")
        }
    }
    
    var chartRefreshInterval: TimeInterval {
        get {
            let value = double(forKey: "ChartRefreshInterval")
            return value > 0 ? value : 300.0 // Default to 5 minutes
        }
        set {
            set(newValue, forKey: "ChartRefreshInterval")
        }
    }
    
    var enableDarkMode: Bool {
        get {
            return bool(forKey: "EnableDarkMode")
        }
        set {
            set(newValue, forKey: "EnableDarkMode")
        }
    }
    
    // MARK: - Menu Bar Settings
    
    var menuBarRefreshInterval: TimeInterval {
        get {
            let value = double(forKey: "MenuBarRefreshInterval")
            return value > 0 ? value : 120.0 // Default to 2 minutes - matches data freshness
        }
        set {
            set(newValue, forKey: "MenuBarRefreshInterval")
        }
    }
    
    var menuBarShowsTemperature: Bool {
        get {
            return bool(forKey: "MenuBarShowsTemperature")
        }
        set {
            set(newValue, forKey: "MenuBarShowsTemperature")
        }
    }
    
    var menuBarShowsHumidity: Bool {
        get {
            return bool(forKey: "MenuBarShowsHumidity")
        }
        set {
            set(newValue, forKey: "MenuBarShowsHumidity")
        }
    }
    
    var menuBarCycleThroughStations: Bool {
        get {
            return bool(forKey: "MenuBarCycleThroughStations")
        }
        set {
            set(newValue, forKey: "MenuBarCycleThroughStations")
        }
    }
    
    var menuBarCycleInterval: TimeInterval {
        get {
            let value = double(forKey: "MenuBarCycleInterval")
            return value > 0 ? value : 15.0 // Default to 15 seconds
        }
        set {
            set(newValue, forKey: "MenuBarCycleInterval")
        }
    }

    // MARK: - Radar Settings
    
    var radarRefreshInterval: TimeInterval {
        get {
            let value = double(forKey: "RadarRefreshInterval")
            return value > 0 ? value : 600.0 // Default to 10 minutes
        }
        set {
            set(newValue, forKey: "RadarRefreshInterval")
        }
    }
    
    // MARK: - Camera Settings
    
    var cameraRefreshInterval: TimeInterval {
        get {
            let value = double(forKey: "CameraRefreshInterval")
            return value > 0 ? value : 300.0 // Default to 5 minutes
        }
        set {
            set(newValue, forKey: "CameraRefreshInterval")
        }
    }
    
    // MARK: - Chart Settings
    
    var chartAnimationsEnabled: Bool {
        get {
            // Default to true if not set
            if object(forKey: "ChartAnimationsEnabled") == nil {
                return true
            }
            return bool(forKey: "ChartAnimationsEnabled")
        }
        set {
            set(newValue, forKey: "ChartAnimationsEnabled")
        }
    }
    
    var chartDataPointLimit: Int {
        get {
            let value = integer(forKey: "ChartDataPointLimit")
            return value > 0 ? value : 1000 // Default to 1000 points
        }
        set {
            set(newValue, forKey: "ChartDataPointLimit")
        }
    }
    
    // MARK: - Alert Settings
    
    var enableTemperatureAlerts: Bool {
        get {
            return bool(forKey: "EnableTemperatureAlerts")
        }
        set {
            set(newValue, forKey: "EnableTemperatureAlerts")
        }
    }
    
    var temperatureAlertLowThreshold: Double {
        get {
            let value = double(forKey: "TemperatureAlertLowThreshold")
            return value != 0 ? value : 32.0 // Default to 32°F
        }
        set {
            set(newValue, forKey: "TemperatureAlertLowThreshold")
        }
    }
    
    var temperatureAlertHighThreshold: Double {
        get {
            let value = double(forKey: "TemperatureAlertHighThreshold")
            return value != 0 ? value : 100.0 // Default to 100°F
        }
        set {
            set(newValue, forKey: "TemperatureAlertHighThreshold")
        }
    }
    
    var enableWindSpeedAlerts: Bool {
        get {
            return bool(forKey: "EnableWindSpeedAlerts")
        }
        set {
            set(newValue, forKey: "EnableWindSpeedAlerts")
        }
    }
    
    var windSpeedAlertThreshold: Double {
        get {
            let value = double(forKey: "WindSpeedAlertThreshold")
            return value > 0 ? value : 25.0 // Default to 25 mph
        }
        set {
            set(newValue, forKey: "WindSpeedAlertThreshold")
        }
    }
    
    // MARK: - Performance Settings
    
    var enableMemoryOptimization: Bool {
        get {
            // Default to true if not set
            if object(forKey: "EnableMemoryOptimization") == nil {
                return true
            }
            return bool(forKey: "EnableMemoryOptimization")
        }
        set {
            set(newValue, forKey: "EnableMemoryOptimization")
        }
    }
    
    var maxConcurrentRequests: Int {
        get {
            let value = integer(forKey: "MaxConcurrentRequests")
            return value > 0 ? value : 3 // Default to 3 concurrent requests
        }
        set {
            set(newValue, forKey: "MaxConcurrentRequests")
        }
    }
}