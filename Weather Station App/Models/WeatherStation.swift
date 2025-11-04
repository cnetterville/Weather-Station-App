//
//  WeatherStation.swift
//  Weather Station App
//
//  Created by Curtis Netterville on 10/25/25.
//

import Foundation

struct WeatherStation: Identifiable, Codable, Equatable, Hashable {
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
    var cardOrder: [CardType] = CardType.defaultOrder // Custom card order
    
    enum CodingKeys: String, CodingKey {
        case name, macAddress, isActive, lastUpdated, sensorPreferences, customLabels, stationType, creationDate, deviceType, latitude, longitude, timeZoneId, associatedCameraMAC, menuBarLabel, cardOrder
    }
    
    // Custom decoder to handle missing cardOrder
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        name = try container.decode(String.self, forKey: .name)
        macAddress = try container.decode(String.self, forKey: .macAddress)
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
        lastUpdated = try container.decodeIfPresent(Date.self, forKey: .lastUpdated)
        sensorPreferences = try container.decodeIfPresent(SensorPreferences.self, forKey: .sensorPreferences) ?? SensorPreferences()
        customLabels = try container.decodeIfPresent(SensorLabels.self, forKey: .customLabels) ?? SensorLabels()
        stationType = try container.decodeIfPresent(String.self, forKey: .stationType)
        creationDate = try container.decodeIfPresent(Date.self, forKey: .creationDate)
        deviceType = try container.decodeIfPresent(Int.self, forKey: .deviceType)
        latitude = try container.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try container.decodeIfPresent(Double.self, forKey: .longitude)
        timeZoneId = try container.decodeIfPresent(String.self, forKey: .timeZoneId)
        associatedCameraMAC = try container.decodeIfPresent(String.self, forKey: .associatedCameraMAC)
        menuBarLabel = try container.decodeIfPresent(String.self, forKey: .menuBarLabel)
        
        // Handle cardOrder with default fallback
        cardOrder = try container.decodeIfPresent([CardType].self, forKey: .cardOrder) ?? CardType.defaultOrder
        
        logData("Decoded station '\(name)' with \(cardOrder.count) cards in order")
    }
    
    // Add explicit initializer for creating new stations
    init(name: String, macAddress: String) {
        self.name = name
        self.macAddress = macAddress
        self.cardOrder = CardType.defaultOrder
        logSuccess("Created new station '\(name)' with default card order (\(cardOrder.count) cards)")
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
    
    // Computed property to get the default menubar label (truncated name)
    var defaultMenuBarLabel: String {
        if name.count > 8 {
            return String(name.prefix(6)) + "…"
        }
        return name
    }
    
    // Computed property to get the display label for menubar (custom label or truncated name)
    var displayLabelForMenuBar: String {
        if let customLabel = menuBarLabel, !customLabel.isEmpty {
            return customLabel
        }
        
        return defaultMenuBarLabel
    }
    
    // Equatable conformance - only compare by ID
    static func == (lhs: WeatherStation, rhs: WeatherStation) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Card Type Enum for Reordering

enum CardType: String, Codable, CaseIterable, Identifiable {
    case stationInfo = "station_info"
    case outdoorTemp = "outdoor_temp"
    case forecast = "forecast"
    case radar = "radar"
    case indoorTemp = "indoor_temp"
    case tempHumidityCh1 = "temp_humidity_ch1"
    case tempHumidityCh2 = "temp_humidity_ch2"
    case tempHumidityCh3 = "temp_humidity_ch3"
    case wind = "wind"
    case pressure = "pressure"
    case rainfall = "rainfall"
    case rainfallPiezo = "rainfall_piezo"
    case airQualityCh1 = "air_quality_ch1"
    case airQualityCh2 = "air_quality_ch2"
    case airQualityCh3 = "air_quality_ch3"
    case solar = "solar"
    case lightning = "lightning"
    case batteryStatus = "battery_status"
    case sunriseSunset = "sunrise_sunset"
    case lunar = "lunar"
    case camera = "camera"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .stationInfo: return "Station Info"
        case .outdoorTemp: return "Outdoor Temperature"
        case .forecast: return "Forecast"
        case .radar: return "Radar"
        case .indoorTemp: return "Indoor Temperature"
        case .tempHumidityCh1: return "Temp/Humidity Ch1"
        case .tempHumidityCh2: return "Temp/Humidity Ch2"
        case .tempHumidityCh3: return "Temp/Humidity Ch3"
        case .wind: return "Wind"
        case .pressure: return "Pressure"
        case .rainfall: return "Rainfall (Traditional)"
        case .rainfallPiezo: return "Rainfall (Piezo)"
        case .airQualityCh1: return "Air Quality Ch1"
        case .airQualityCh2: return "Air Quality Ch2"
        case .airQualityCh3: return "Air Quality Ch3"
        case .solar: return "Solar & UV"
        case .lightning: return "Lightning"
        case .batteryStatus: return "Battery Status"
        case .sunriseSunset: return "Sunrise/Sunset"
        case .lunar: return "Lunar"
        case .camera: return "Camera"
        }
    }
    
    static var defaultOrder: [CardType] {
        return [
            .stationInfo,
            .outdoorTemp,
            .forecast,
            .radar,
            .indoorTemp,
            .tempHumidityCh1,
            .tempHumidityCh2,
            .tempHumidityCh3,
            .wind,
            .pressure,
            .rainfall,
            .rainfallPiezo,
            .airQualityCh1,
            .airQualityCh2,
            .airQualityCh3,
            .solar,
            .lightning,
            .batteryStatus,
            .sunriseSunset,
            .lunar,
            .camera
        ]
    }
}

struct SensorLabels: Codable, Equatable, Hashable {
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
    var forecast: String = "5-Day Forecast"
}

struct SensorPreferences: Codable, Equatable, Hashable {
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