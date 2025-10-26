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
    
    enum CodingKeys: String, CodingKey {
        case name, macAddress, isActive, lastUpdated, sensorPreferences, customLabels, stationType, creationDate, deviceType
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
    var rainfall: String = "Rainfall (Piezo)"
    var airQualityCh1: String = "Air Quality Ch1 (PM2.5)"
    var airQualityCh2: String = "Air Quality Ch2 (PM2.5)"
    var uvIndex: String = "UV Index"
    var lightning: String = "Lightning"
    var tempHumidityCh1: String = "Temp/Humidity Ch1"
    var tempHumidityCh2: String = "Temp/Humidity Ch2"
    var tempHumidityCh3: String = "Temp/Humidity Ch3"
    var batteryStatus: String = "Battery Status"
}

struct SensorPreferences: Codable, Equatable {
    var showOutdoorTemp: Bool = true
    var showIndoorTemp: Bool = true
    var showWind: Bool = true
    var showPressure: Bool = true
    var showRainfall: Bool = true
    var showAirQualityCh1: Bool = true
    var showAirQualityCh2: Bool = true
    var showUVIndex: Bool = true
    var showLightning: Bool = true
    var showTempHumidityCh1: Bool = false
    var showTempHumidityCh2: Bool = false
    var showTempHumidityCh3: Bool = false
    var showBatteryStatus: Bool = false
}

struct APICredentials: Codable {
    var applicationKey: String
    var apiKey: String
    
    var isValid: Bool {
        !applicationKey.isEmpty && !apiKey.isEmpty
    }
}