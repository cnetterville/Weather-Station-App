//
//  HistoricalWeatherData.swift
//  Weather Station App
//
//  Created by Curtis Netterville on 10/25/25.
//

import Foundation

struct HistoricalWeatherResponse: Codable {
    let code: Int
    let msg: String
    let time: String
    let data: HistoricalWeatherData
}

struct HistoricalWeatherData: Codable {
    let outdoor: HistoricalOutdoorData?
    let indoor: HistoricalIndoorData?
    let solarAndUvi: HistoricalSolarAndUVIData?
    let rainfall: HistoricalRainfallData?
    let rainfallPiezo: HistoricalRainfallPiezoData?
    let wind: HistoricalWindData?
    let pressure: HistoricalPressureData?
    let lightning: HistoricalLightningData?
    let pm25Ch1: HistoricalPM25Data?
    let pm25Ch2: HistoricalPM25Data?
    let pm25Ch3: HistoricalPM25Data?
    let tempAndHumidityCh1: HistoricalTempHumidityData?
    let tempAndHumidityCh2: HistoricalTempHumidityData?
    let tempAndHumidityCh3: HistoricalTempHumidityData?
    
    enum CodingKeys: String, CodingKey {
        case outdoor, indoor, rainfall, wind, pressure, lightning
        case solarAndUvi = "solar_and_uvi"
        case rainfallPiezo = "rainfall_piezo"
        case pm25Ch1 = "pm25_ch1"
        case pm25Ch2 = "pm25_ch2"
        case pm25Ch3 = "pm25_ch3"
        case tempAndHumidityCh1 = "temp_and_humidity_ch1"
        case tempAndHumidityCh2 = "temp_and_humidity_ch2"
        case tempAndHumidityCh3 = "temp_and_humidity_ch3"
    }
}

struct HistoricalMeasurement: Codable {
    let unit: String
    let list: [String: String] // timestamp: value
}

struct HistoricalOutdoorData: Codable {
    let temperature: HistoricalMeasurement?
    let feelsLike: HistoricalMeasurement?
    let appTemp: HistoricalMeasurement?
    let dewPoint: HistoricalMeasurement?
    let humidity: HistoricalMeasurement?
    
    enum CodingKeys: String, CodingKey {
        case temperature, humidity
        case feelsLike = "feels_like"
        case appTemp = "app_temp"
        case dewPoint = "dew_point"
    }
}

struct HistoricalIndoorData: Codable {
    let temperature: HistoricalMeasurement?
    let humidity: HistoricalMeasurement?
    let dewPoint: HistoricalMeasurement?
    let feelsLike: HistoricalMeasurement?
    
    enum CodingKeys: String, CodingKey {
        case temperature, humidity
        case dewPoint = "dew_point"
        case feelsLike = "feels_like"
    }
}

struct HistoricalSolarAndUVIData: Codable {
    let solar: HistoricalMeasurement?
    let uvi: HistoricalMeasurement?
}

struct HistoricalRainfallData: Codable {
    let rainRate: HistoricalMeasurement?
    let daily: HistoricalMeasurement?
    let event: HistoricalMeasurement?
    let hourly: HistoricalMeasurement?
    let weekly: HistoricalMeasurement?
    let monthly: HistoricalMeasurement?
    let yearly: HistoricalMeasurement?
    
    enum CodingKeys: String, CodingKey {
        case daily, event, hourly, weekly, monthly, yearly
        case rainRate = "rain_rate"
    }
}

struct HistoricalRainfallPiezoData: Codable {
    let rainRate: HistoricalMeasurement?
    let daily: HistoricalMeasurement?
    let event: HistoricalMeasurement?
    let hourly: HistoricalMeasurement?
    let weekly: HistoricalMeasurement?
    let monthly: HistoricalMeasurement?
    let yearly: HistoricalMeasurement?
    
    enum CodingKeys: String, CodingKey {
        case daily, event, hourly, weekly, monthly, yearly
        case rainRate = "rain_rate"
    }
}

struct HistoricalWindData: Codable {
    let windSpeed: HistoricalMeasurement?
    let windGust: HistoricalMeasurement?
    let windDirection: HistoricalMeasurement?
    
    enum CodingKeys: String, CodingKey {
        case windSpeed = "wind_speed"
        case windGust = "wind_gust"
        case windDirection = "wind_direction"
    }
}

struct HistoricalPressureData: Codable {
    let relative: HistoricalMeasurement?
    let absolute: HistoricalMeasurement?
}

struct HistoricalLightningData: Codable {
    let distance: HistoricalMeasurement?
    let count: HistoricalMeasurement?
}

struct HistoricalPM25Data: Codable {
    let pm25: HistoricalMeasurement?
}

struct HistoricalTempHumidityData: Codable {
    let temperature: HistoricalMeasurement?
    let humidity: HistoricalMeasurement?
}

// Helper structures for time range selection
enum HistoricalTimeRange: String, CaseIterable {
    case lastHour = "1 Hour"
    case last6Hours = "6 Hours"
    case last24Hours = "24 Hours"
    case last7Days = "7 Days" 
    case last30Days = "30 Days"
    case last90Days = "90 Days"
    case last365Days = "1 Year"
    
    var timeInterval: TimeInterval {
        switch self {
        case .lastHour: return 3600
        case .last6Hours: return 6 * 3600
        case .last24Hours: return 24 * 3600
        case .last7Days: return 7 * 24 * 3600
        case .last30Days: return 30 * 24 * 3600
        case .last90Days: return 90 * 24 * 3600
        case .last365Days: return 365 * 24 * 3600
        }
    }
    
    var cycleType: String {
        switch self {
        case .lastHour, .last6Hours: return "5min"
        case .last24Hours: return "30min"
        case .last7Days: return "4hour"
        case .last30Days, .last90Days: return "1day"  // 1day cycle only has 3 months retention
        case .last365Days: return "1week"  // Use weekly data for 1 year (has 1 year retention)
        }
    }
    
    var maxDaysPerRequest: Int {
        switch self {
        case .lastHour, .last6Hours, .last24Hours: return 1
        case .last7Days: return 7
        case .last30Days: return 30
        case .last90Days: return 90  // Limited to ~90 days max for daily data
        case .last365Days: return 365
        }
    }
    
    var displayName: String {
        switch self {
        case .lastHour: return "1H"
        case .last6Hours: return "6H" 
        case .last24Hours: return "24H"
        case .last7Days: return "7D"
        case .last30Days: return "30D"
        case .last90Days: return "90D"
        case .last365Days: return "1Y"
        }
    }
}

// Data point for charting
struct ChartDataPoint: Identifiable {
    let id = UUID()
    let timestamp: Date
    let value: Double
}