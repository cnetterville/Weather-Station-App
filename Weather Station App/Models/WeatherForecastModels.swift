//
//  WeatherForecastModels.swift
//  Weather Station App
//
//  Created by Curtis Netterville on 10/25/25.
//

import Foundation

// MARK: - Open-Meteo API Response Models

struct ForecastResponse: Codable {
    let latitude: Double
    let longitude: Double
    let timezone: String
    let timezoneAbbreviation: String
    let elevation: Double
    let daily: DailyForecast
    
    enum CodingKeys: String, CodingKey {
        case latitude, longitude, timezone, elevation, daily
        case timezoneAbbreviation = "timezone_abbreviation"
    }
}

struct DailyForecast: Codable {
    let time: [String]
    let weatherCode: [Int]
    let temperature2mMax: [Double]
    let temperature2mMin: [Double]
    let precipitationSum: [Double]
    let windSpeed10mMax: [Double]
    let windDirection10mDominant: [Int]
    
    enum CodingKeys: String, CodingKey {
        case time
        case weatherCode = "weather_code"
        case temperature2mMax = "temperature_2m_max"
        case temperature2mMin = "temperature_2m_min"
        case precipitationSum = "precipitation_sum"
        case windSpeed10mMax = "wind_speed_10m_max"
        case windDirection10mDominant = "wind_direction_10m_dominant"
    }
}

// MARK: - Processed Forecast Data Models

struct WeatherForecast {
    let location: ForecastLocation
    let dailyForecasts: [DailyWeatherForecast]
    let lastUpdated: Date
    
    var isExpired: Bool {
        // Refresh forecast every 3 hours
        Date().timeIntervalSince(lastUpdated) > 10800
    }
}

struct ForecastLocation {
    let latitude: Double
    let longitude: Double
    let timezone: String
    let elevation: Double
}

struct DailyWeatherForecast {
    let date: Date
    let weatherCode: Int
    let maxTemperature: Double
    let minTemperature: Double
    let precipitation: Double
    let maxWindSpeed: Double
    let windDirection: Int
    
    // Computed properties for UI
    var dayOfWeek: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }
    
    var shortDayOfWeek: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
    
    var monthDay: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
    
    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
    
    var isTomorrow: Bool {
        Calendar.current.isDateInTomorrow(date)
    }
    
    var displayDay: String {
        if isToday {
            return "Today"
        } else if isTomorrow {
            return "Tomorrow"
        } else {
            return shortDayOfWeek
        }
    }
    
    var weatherDescription: String {
        WeatherCodeInterpreter.description(for: weatherCode)
    }
    
    var weatherIcon: String {
        WeatherCodeInterpreter.systemIcon(for: weatherCode)
    }
    
    var formattedMaxTemp: String {
        TemperatureConverter.formatTemperature(String(maxTemperature), originalUnit: "°C")
    }
    
    var formattedMinTemp: String {
        TemperatureConverter.formatTemperature(String(minTemperature), originalUnit: "°C")
    }
    
    var formattedPrecipitation: String {
        if precipitation < 0.1 {
            return "0mm"
        } else {
            return String(format: "%.1fmm", precipitation)
        }
    }
    
    var formattedWindSpeed: String {
        return String(format: "%.0f km/h", maxWindSpeed)
    }
    
    var windDirectionText: String {
        return WindDirectionConverter.directionText(for: windDirection)
    }
    
    var precipitationColor: Color {
        switch precipitation {
        case 0..<0.1: return .clear
        case 0.1..<1: return .blue.opacity(0.3)
        case 1..<5: return .blue.opacity(0.6)
        case 5..<15: return .blue
        default: return .indigo
        }
    }
}

// MARK: - Weather Code Interpreter

struct WeatherCodeInterpreter {
    static func description(for code: Int) -> String {
        switch code {
        case 0: return "Clear sky"
        case 1: return "Mainly clear"
        case 2: return "Partly cloudy"
        case 3: return "Overcast"
        case 45: return "Fog"
        case 48: return "Depositing rime fog"
        case 51: return "Light drizzle"
        case 53: return "Moderate drizzle"
        case 55: return "Dense drizzle"
        case 56: return "Light freezing drizzle"
        case 57: return "Dense freezing drizzle"
        case 61: return "Slight rain"
        case 63: return "Moderate rain"
        case 65: return "Heavy rain"
        case 66: return "Light freezing rain"
        case 67: return "Heavy freezing rain"
        case 71: return "Slight snow fall"
        case 73: return "Moderate snow fall"
        case 75: return "Heavy snow fall"
        case 77: return "Snow grains"
        case 80: return "Slight rain showers"
        case 81: return "Moderate rain showers"
        case 82: return "Violent rain showers"
        case 85: return "Slight snow showers"
        case 86: return "Heavy snow showers"
        case 95: return "Thunderstorm"
        case 96: return "Thunderstorm with slight hail"
        case 99: return "Thunderstorm with heavy hail"
        default: return "Unknown"
        }
    }
    
    static func systemIcon(for code: Int) -> String {
        switch code {
        case 0: return "sun.max.fill"
        case 1: return "sun.max"
        case 2: return "cloud.sun.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51, 53, 55: return "cloud.drizzle.fill"
        case 56, 57: return "cloud.sleet.fill"
        case 61, 63: return "cloud.rain.fill"
        case 65: return "cloud.heavyrain.fill"
        case 66, 67: return "cloud.sleet.fill"
        case 71, 73, 75, 77: return "cloud.snow.fill"
        case 80, 81: return "cloud.rain.fill"
        case 82: return "cloud.heavyrain.fill"
        case 85, 86: return "cloud.snow.fill"
        case 95: return "cloud.bolt.fill"
        case 96, 99: return "cloud.bolt.rain.fill"
        default: return "questionmark.circle.fill"
        }
    }
}

// MARK: - Wind Direction Converter

struct WindDirectionConverter {
    static func directionText(for degrees: Int) -> String {
        switch degrees {
        case 0...22, 338...360: return "N"
        case 23...67: return "NE"
        case 68...112: return "E"
        case 113...157: return "SE"
        case 158...202: return "S"
        case 203...247: return "SW"
        case 248...292: return "W"
        case 293...337: return "NW"
        default: return "—"
        }
    }
}

// MARK: - Color Extension

extension Color {
    static var clear: Color {
        Color(.clear)
    }
}