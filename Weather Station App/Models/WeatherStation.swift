//
//  WeatherStation.swift
//  Weather Station App
//
//  Created by Curtis Netterville on 10/25/25.
//

import Foundation

struct WeatherStation: Identifiable, Codable, Equatable {
    let id = UUID()
    var name: String
    var macAddress: String
    var isActive: Bool = true
    var lastUpdated: Date?
    var sensorPreferences: SensorPreferences = SensorPreferences()
    var customLabels: SensorLabels = SensorLabels()
    var stationType: String?
    var creationDate: Date?
    var deviceType: Int?
    var latitude: Double?
    var longitude: Double?
    var timeZoneId: String?
    var associatedCameraMAC: String? // Link to camera device
    var menuBarLabel: String? // Custom short label for menubar display
    
    enum CodingKeys: String, CodingKey {
        case name, macAddress, isActive, lastUpdated, sensorPreferences, customLabels, stationType, creationDate, deviceType, latitude, longitude, timeZoneId, associatedCameraMAC, menuBarLabel
    }
    
    // Computed property to get the station's timezone
    var timeZone: TimeZone {
        if let timeZoneId = timeZoneId,
           let stationTimeZone = TimeZone(identifier: timeZoneId) {
            return stationTimeZone
        }
        
        // Fallback to device's local timezone if station timezone is not available
        return TimeZone.current
    }
    
    // Computed property to get the display label for menubar (custom label or truncated name)
    var displayLabelForMenuBar: String {
        if let customLabel = menuBarLabel, !customLabel.isEmpty {
            return customLabel
        }
        
        // Fallback to truncated name if no custom label
        if name.count > 8 {
            return String(name.prefix(6)) + "…"
        }
        
        return name
    }
    
    // Equatable conformance
    static func == (lhs: WeatherStation, rhs: WeatherStation) -> Bool {
        lhs.id == rhs.id
    }
}

struct SensorLabels: Codable, Equatable {
    var outdoorTemp: String = "Outdoor Temperature"
    var indoorTemp: String = "Indoor Temperature" 
    var wind: String = "Wind"
    var pressure: String = "Pressure"
    var rainfall: String = "Rainfall (Traditional)"
    var rainfallPiezo: String = "Rainfall (Piezo)"
    var airQualityCh1: String = "Air Quality Ch1 (PM2.5)"
    var airQualityCh2: String = "Air Quality Ch2 (PM2.5)"
    var airQualityCh3: String = "Air Quality Ch3 (PM2.5)"
    var uvIndex: String = "UV Index"
    var solar: String = "Solar & UV"
    var lightning: String = "Lightning"
    var tempHumidityCh1: String = "Temp/Humidity Ch1"
    var tempHumidityCh2: String = "Temp/Humidity Ch2"
    var tempHumidityCh3: String = "Temp/Humidity Ch3"
    var batteryStatus: String = "Battery Status"
    var sunriseSunset: String = "Sunrise/Sunset"
    var lunar: String = "Moon & Lunar"
    var camera: String = "Weather Camera"
    var radar: String = "Weather Radar"
    var forecast: String = "4-Day Forecast"
}

struct SensorPreferences: Codable, Equatable {
    var showOutdoorTemp: Bool = true
    var showIndoorTemp: Bool = true
    var showWind: Bool = true
    var showPressure: Bool = true
    var showRainfall: Bool = true // Traditional rain gauge
    var showRainfallPiezo: Bool = true // Piezo rain gauge
    var showAirQualityCh1: Bool = true
    var showAirQualityCh2: Bool = true
    var showAirQualityCh3: Bool = true
    var showUVIndex: Bool = true
    var showSolar: Bool = true
    var showLightning: Bool = true
    var showTempHumidityCh1: Bool = false
    var showTempHumidityCh2: Bool = false
    var showTempHumidityCh3: Bool = false
    var showBatteryStatus: Bool = false
    var showSunriseSunset: Bool = true
    var showLunar: Bool = true
    var showCamera: Bool = true
    var showRadar: Bool = true
    var showForecast: Bool = true
    
    // Migration support for existing installations
    init() {
        // Default values are set above
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        showOutdoorTemp = try container.decodeIfPresent(Bool.self, forKey: .showOutdoorTemp) ?? true
        showIndoorTemp = try container.decodeIfPresent(Bool.self, forKey: .showIndoorTemp) ?? true
        showWind = try container.decodeIfPresent(Bool.self, forKey: .showWind) ?? true
        showPressure = try container.decodeIfPresent(Bool.self, forKey: .showPressure) ?? true
        showAirQualityCh1 = try container.decodeIfPresent(Bool.self, forKey: .showAirQualityCh1) ?? true
        showAirQualityCh2 = try container.decodeIfPresent(Bool.self, forKey: .showAirQualityCh2) ?? true
        showAirQualityCh3 = try container.decodeIfPresent(Bool.self, forKey: .showAirQualityCh3) ?? true
        showUVIndex = try container.decodeIfPresent(Bool.self, forKey: .showUVIndex) ?? true
        showSolar = try container.decodeIfPresent(Bool.self, forKey: .showSolar) ?? true
        showLightning = try container.decodeIfPresent(Bool.self, forKey: .showLightning) ?? true
        showTempHumidityCh1 = try container.decodeIfPresent(Bool.self, forKey: .showTempHumidityCh1) ?? false
        showTempHumidityCh2 = try container.decodeIfPresent(Bool.self, forKey: .showTempHumidityCh2) ?? false
        showTempHumidityCh3 = try container.decodeIfPresent(Bool.self, forKey: .showTempHumidityCh3) ?? false
        showBatteryStatus = try container.decodeIfPresent(Bool.self, forKey: .showBatteryStatus) ?? false
        showSunriseSunset = try container.decodeIfPresent(Bool.self, forKey: .showSunriseSunset) ?? true
        showLunar = try container.decodeIfPresent(Bool.self, forKey: .showLunar) ?? true
        showCamera = try container.decodeIfPresent(Bool.self, forKey: .showCamera) ?? true
        showRadar = try container.decodeIfPresent(Bool.self, forKey: .showRadar) ?? true
        showForecast = try container.decodeIfPresent(Bool.self, forKey: .showForecast) ?? true
        
        // Migration logic for rainfall preferences
        if let oldRainfallPref = try container.decodeIfPresent(Bool.self, forKey: .showRainfall) {
            // If old preference exists, use it for both types
            showRainfall = oldRainfallPref
            showRainfallPiezo = oldRainfallPref
        } else {
            // Check for new separate preferences
            showRainfall = try container.decodeIfPresent(Bool.self, forKey: .showRainfall) ?? true
            showRainfallPiezo = try container.decodeIfPresent(Bool.self, forKey: .showRainfallPiezo) ?? true
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case showOutdoorTemp, showIndoorTemp, showWind, showPressure
        case showRainfall, showRainfallPiezo
        case showAirQualityCh1, showAirQualityCh2, showAirQualityCh3
        case showUVIndex, showSolar, showLightning
        case showTempHumidityCh1, showTempHumidityCh2, showTempHumidityCh3
        case showBatteryStatus, showSunriseSunset, showLunar, showCamera, showRadar
        case showForecast
    }
}

struct APICredentials: Codable {
    var applicationKey: String
    var apiKey: String
    
    var isValid: Bool {
        !applicationKey.isEmpty && !apiKey.isEmpty
    }
}