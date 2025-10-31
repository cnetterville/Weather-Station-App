//
//  WeatherForecastModels.swift
//  Weather Station App
//
//  Created by Curtis Netterville on 10/25/25.
//

import Foundation
import SwiftUI

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
    let timezone: TimeZone // Add timezone property
    
    // Computed properties for UI
    var dayOfWeek: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        formatter.timeZone = timezone // Use forecast location's timezone
        return formatter.string(from: date)
    }
    
    var shortDayOfWeek: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        formatter.timeZone = timezone // Use forecast location's timezone
        return formatter.string(from: date)
    }
    
    var monthDay: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        formatter.timeZone = timezone // Use forecast location's timezone
        return formatter.string(from: date)
    }
    
    var isToday: Bool {
        let calendar = Calendar.current
        let today = Date()
        
        // Get the current date in the forecast location's timezone
        let forecastCalendar = Calendar(identifier: calendar.identifier)
        guard let forecastTimeZone = TimeZone(identifier: timezone.identifier) else {
            // Fallback to original behavior if timezone is invalid
            return calendar.isDateInToday(date)
        }
        
        var forecastCalendarCopy = forecastCalendar
        forecastCalendarCopy.timeZone = forecastTimeZone
        
        return forecastCalendarCopy.isDate(date, inSameDayAs: today)
    }
    
    var isTomorrow: Bool {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        
        // Get tomorrow in the forecast location's timezone
        let forecastCalendar = Calendar(identifier: calendar.identifier)
        guard let forecastTimeZone = TimeZone(identifier: timezone.identifier) else {
            // Fallback to original behavior if timezone is invalid
            return calendar.isDateInTomorrow(date)
        }
        
        var forecastCalendarCopy = forecastCalendar
        forecastCalendarCopy.timeZone = forecastTimeZone
        
        return forecastCalendarCopy.isDate(date, inSameDayAs: tomorrow)
    }
    
    var displayDay: String {
        if isToday {
            return "Today"
        } else {
            return shortDayOfWeek
        }
    }
    
    var weatherDescription: String {
        WeatherCodeInterpreter.description(for: weatherCode)
    }
    
    var shortWeatherDescription: String {
        WeatherCodeInterpreter.shortDescription(for: weatherCode)
    }
    
    var veryShortWeatherDescription: String {
        WeatherCodeInterpreter.veryShortDescription(for: weatherCode)
    }
    
    var weatherIcon: String {
        WeatherCodeInterpreter.systemIcon(for: weatherCode)
    }
    
    var formattedMaxTemp: String {
        let temp = Int(maxTemperature.rounded())
        let converted = MeasurementConverter.convertTemperature(String(temp), from: "°C")
        let displayMode = UserDefaults.standard.unitSystemDisplayMode
        
        switch displayMode {
        case .imperial:
            return "\(Int(Double(converted.fahrenheit) ?? 0))°F"
        case .metric:
            return "\(temp)°C"
        case .both:
            return "\(Int(Double(converted.fahrenheit) ?? 0))°F/\(temp)°C"
        }
    }
    
    var formattedMinTemp: String {
        let temp = Int(minTemperature.rounded())
        let converted = MeasurementConverter.convertTemperature(String(temp), from: "°C")
        let displayMode = UserDefaults.standard.unitSystemDisplayMode
        
        switch displayMode {
        case .imperial:
            return "\(Int(Double(converted.fahrenheit) ?? 0))°F"
        case .metric:
            return "\(temp)°C"
        case .both:
            return "\(Int(Double(converted.fahrenheit) ?? 0))°F/\(temp)°C"
        }
    }
    
    var formattedPrecipitation: String {
        let displayMode = UserDefaults.standard.unitSystemDisplayMode
        
        switch displayMode {
        case .imperial:
            // Convert mm to inches and display in inches
            let inches = precipitation * 0.0393701
            if inches < 0.05 {
                return "0.00in"
            } else {
                return String(format: "%.2fin", inches)
            }
            
        case .metric:
            // Display in original mm
            if precipitation < 0.5 {
                return "0.0mm"
            } else {
                return String(format: "%.1fmm", precipitation)
            }
            
        case .both:
            // Show both units
            let inches = precipitation * 0.0393701
            if precipitation < 0.5 && inches < 0.05 {
                return "0.0mm/0.00in"
            } else {
                return String(format: "%.1fmm/%.2fin", precipitation, inches)
            }
        }
    }
    
    var formattedWindSpeed: String {
        return String(format: "%.0f km/h", maxWindSpeed)
    }
    
    var windDirectionText: String {
        return WindDirectionConverter.directionText(for: windDirection)
    }
    
    var precipitationColor: SwiftUI.Color {
        switch precipitation {
        case 0..<0.1: return SwiftUI.Color.clear
        case 0.1..<1: return SwiftUI.Color.blue.opacity(0.2)
        case 1..<5: return SwiftUI.Color.blue.opacity(0.3)
        case 5..<15: return SwiftUI.Color.blue.opacity(0.4)
        default: return SwiftUI.Color.blue.opacity(0.5)
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
    
    static func shortDescription(for code: Int) -> String {
        switch code {
        case 0: return "Clear"
        case 1: return "M. Clear"
        case 2: return "P. Cloudy"
        case 3: return "Overcast"
        case 45: return "Fog"
        case 48: return "Rime Fog"
        case 51: return "Lt Drizzle"
        case 53: return "Drizzle"
        case 55: return "Hvy Drizzle"
        case 56: return "Frz Drizzle"
        case 57: return "Hvy Frz Drizzle"
        case 61: return "Lt Rain"
        case 63: return "Rain"
        case 65: return "Hvy Rain"
        case 66: return "Lt Frz Rain"
        case 67: return "Hvy Frz Rain"
        case 71: return "Lt Snow"
        case 73: return "Snow"
        case 75: return "Hvy Snow"
        case 77: return "Snow Grains"
        case 80: return "Lt Showers"
        case 81: return "Showers"
        case 82: return "Hvy Showers"
        case 85: return "Lt Snow Showers"
        case 86: return "Hvy Snow Showers"
        case 95: return "T-Storm"
        case 96: return "T-Storm Hail"
        case 99: return "Hvy T-Storm Hail"
        default: return "Unknown"
        }
    }
    
    static func veryShortDescription(for code: Int) -> String {
        switch code {
        case 0: return "Clear"
        case 1: return "Clear"
        case 2: return "Cloudy"
        case 3: return "Overcast"
        case 45, 48: return "Fog"
        case 51, 53, 55: return "Drizzle"
        case 56, 57: return "Frz Drizzle"
        case 61: return "Lt Rain"
        case 63: return "Rain"
        case 65: return "Hvy Rain"
        case 66, 67: return "Frz Rain"
        case 71: return "Lt Snow"
        case 73: return "Snow"
        case 75: return "Hvy Snow"
        case 77: return "Snow"
        case 80: return "Showers"
        case 81: return "Showers"
        case 82: return "Hvy Showers"
        case 85: return "Snow Showers"
        case 86: return "Hvy Snow Showers"
        case 95: return "T-Storm"
        case 96, 99: return "T-Storm"
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