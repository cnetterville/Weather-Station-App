//
//  WeatherForecastModels.swift
//  Weather Station App
//
//  Created by Curtis Netterville on 10/25/25.
//

import Foundation
import SwiftUI

// MARK: - Processed Forecast Data Models

struct WeatherForecast {
    let location: ForecastLocation
    let dailyForecasts: [DailyWeatherForecast]
    let hourlyForecasts: [HourlyWeatherForecast]
    let weatherAlerts: [WeatherAlert]
    let restOfDayForecast: DaypartForecast?
    let lastUpdated: Date
    
    var isExpired: Bool {
        // Refresh forecast every 3 hours
        Date().timeIntervalSince(lastUpdated) > 10800
    }
    
    var hasActiveAlerts: Bool {
        return !weatherAlerts.isEmpty
    }
    
    func weatherIcon(for forecast: DailyWeatherForecast) -> String {
        return WeatherCodeInterpreter.systemIcon(
            for: forecast.weatherCode,
            latitude: location.latitude,
            longitude: location.longitude,
            timeZone: forecast.timezone
        )
    }
    
    // Get hourly forecasts for a specific day
    func hourlyForecasts(for date: Date, timezone: TimeZone) -> [HourlyWeatherForecast] {
        let calendar = Calendar.current
        var calendarCopy = calendar
        calendarCopy.timeZone = timezone
        
        return hourlyForecasts.filter { hourly in
            calendarCopy.isDate(hourly.time, inSameDayAs: date)
        }
    }
}

struct ForecastLocation {
    let latitude: Double
    let longitude: Double
    let timezone: String
    let elevation: Double
}

struct HourlyWeatherForecast {
    let time: Date
    let temperature: Double
    let precipitationProbability: Int
    let precipitation: Double
    let weatherCode: Int
    let windSpeed: Double
    let windDirection: Int
    let humidity: Int
    let timezone: TimeZone
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a" // e.g., "3 PM"
        formatter.timeZone = timezone
        return formatter.string(from: time)
    }
    
    var shortFormattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "ha" // e.g., "3PM"
        formatter.timeZone = timezone
        return formatter.string(from: time)
    }
    
    var formattedTemperature: String {
        let temp = Int(temperature.rounded())
        let converted = MeasurementConverter.convertTemperature(String(temp), from: "°C")
        let displayMode = UserDefaults.standard.unitSystemDisplayMode
        
        switch displayMode {
        case .imperial:
            return "\(Int(Double(converted.fahrenheit) ?? 0))°"
        case .metric:
            return "\(temp)°"
        case .both:
            return "\(Int(Double(converted.fahrenheit) ?? 0))°/\(temp)°"
        }
    }
    
    var formattedWindSpeed: String {
        let displayMode = UserDefaults.standard.unitSystemDisplayMode
        let converted = MeasurementConverter.convertWindSpeed(String(format: "%.0f", windSpeed), from: "km/h")
        
        switch displayMode {
        case .imperial:
            return "\(Int(Double(converted.mph) ?? 0))mph"
        case .metric:
            return "\(Int(windSpeed))km/h"
        case .both:
            return "\(Int(Double(converted.mph) ?? 0))/\(Int(windSpeed))"
        }
    }
    
    var weatherIcon: String {
        WeatherCodeInterpreter.systemIcon(for: weatherCode)
    }
    
    var windDirectionText: String {
        WindDirectionConverter.directionText(for: windDirection)
    }
}

struct DailyWeatherForecast {
    let date: Date
    let weatherCode: Int
    let maxTemperature: Double
    let minTemperature: Double
    let precipitation: Double
    let precipitationProbability: Int
    let maxWindSpeed: Double
    let windDirection: Int
    let timezone: TimeZone
    let restOfDayForecast: DaypartForecast?
    
    // Extended details for days without hourly data
    let humidity: Int?
    let uvIndex: Int?
    let visibility: Double? // in kilometers
    let pressure: Double? // in millibars/hPa
    
    // Computed properties for UI
    var dayOfWeek: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        formatter.timeZone = timezone
        return formatter.string(from: date)
    }
    
    var shortDayOfWeek: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        formatter.timeZone = timezone
        return formatter.string(from: date)
    }
    
    var monthDay: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        formatter.timeZone = timezone
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
        let displayMode = UserDefaults.standard.unitSystemDisplayMode
        let converted = MeasurementConverter.convertWindSpeed(String(format: "%.0f", maxWindSpeed), from: "km/h")
        
        switch displayMode {
        case .imperial:
            return "\(Int(Double(converted.mph) ?? 0))mph"
        case .metric:
            return "\(Int(maxWindSpeed))km/h"
        case .both:
            return "\(Int(Double(converted.mph) ?? 0))mph/\(Int(maxWindSpeed))km/h"
        }
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
    
    // Formatted extended details
    var formattedHumidity: String {
        guard let hum = humidity else { return "—" }
        return "\(hum)%"
    }
    
    var formattedUVIndex: String {
        guard let uv = uvIndex else { return "—" }
        return "\(uv)"
    }
    
    var uvIndexLevel: String {
        guard let uv = uvIndex else { return "—" }
        switch uv {
        case 0...2: return "Low"
        case 3...5: return "Moderate"
        case 6...7: return "High"
        case 8...10: return "Very High"
        default: return "Extreme"
        }
    }
    
    var uvIndexColor: SwiftUI.Color {
        guard let uv = uvIndex else { return .gray }
        switch uv {
        case 0...2: return .green
        case 3...5: return .yellow
        case 6...7: return .orange
        case 8...10: return .red
        default: return .purple
        }
    }
    
    var formattedVisibility: String {
        guard let vis = visibility else { return "—" }
        let displayMode = UserDefaults.standard.unitSystemDisplayMode
        
        switch displayMode {
        case .imperial:
            let miles = vis * 0.621371
            return String(format: "%.1fmi", miles)
        case .metric:
            return String(format: "%.1fkm", vis)
        case .both:
            let miles = vis * 0.621371
            return String(format: "%.1fkm/%.1fmi", vis, miles)
        }
    }
    
    var formattedPressure: String {
        guard let press = pressure else { return "—" }
        let displayMode = UserDefaults.standard.unitSystemDisplayMode
        
        switch displayMode {
        case .imperial:
            let inHg = press * 0.02953
            return String(format: "%.2finHg", inHg)
        case .metric:
            return String(format: "%.0fhPa", press)
        case .both:
            let inHg = press * 0.02953
            return String(format: "%.0fhPa/%.2finHg", press, inHg)
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
    
    static func systemIcon(for code: Int, latitude: Double?, longitude: Double?, timeZone: TimeZone) -> String {
        // Get base icon
        let baseIcon = systemIcon(for: code)
        
        // If we don't have location data, return base icon
        guard let lat = latitude, let lon = longitude else {
            return baseIcon
        }
        
        // Check if it's currently nighttime
        if let sunTimes = SunCalculator.calculateSunTimes(for: Date(), latitude: lat, longitude: lon, timeZone: timeZone) {
            let isNighttime = !sunTimes.isCurrentlyDaylight
            
            if isNighttime {
                return convertToNightIcon(baseIcon)
            }
        }
        
        return baseIcon
    }
    
    private static func convertToNightIcon(_ dayIcon: String) -> String {
        switch dayIcon {
        case "sun.max.fill":
            return "moon.stars.fill"
        case "sun.max":
            return "moon.fill"
        case "cloud.sun.fill":
            return "cloud.moon.fill"
        case "cloud.sun":
            return "cloud.moon"
        case "cloud.sun.rain.fill":
            return "cloud.moon.rain.fill"
        case "cloud.sun.rain":
            return "cloud.moon.rain"
        case "cloud.sun.bolt.fill":
            return "cloud.moon.bolt.fill"
        case "cloud.sun.bolt":
            return "cloud.moon.bolt"
        default:
            // For weather that doesn't have sun/moon variants (rain, snow, fog, etc.)
            // keep the original icon
            return dayIcon
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

// MARK: - Weather Alert Model

struct DaypartForecast {
    let forecastStart: Date
    let forecastEnd: Date
    let cloudCover: Double?
    let condition: String
    let humidity: Double?
    let precipitationAmount: Double?
    let precipitationChance: Double
    let snowfallAmount: Double?
    let temperature: Double?
    let temperatureMax: Double?
    let temperatureMin: Double?
    let windDirection: Int?
    let windSpeed: Double?
    
    var formattedPrecipChance: String {
        return "\(Int((precipitationChance * 100).rounded()))%"
    }
    
    var formattedTemperature: String {
        guard let temp = temperature else { return "—" }
        let tempInt = Int(temp.rounded())
        let converted = MeasurementConverter.convertTemperature(String(tempInt), from: "°C")
        let displayMode = UserDefaults.standard.unitSystemDisplayMode
        
        switch displayMode {
        case .imperial:
            return "\(Int(Double(converted.fahrenheit) ?? 0))°F"
        case .metric:
            return "\(tempInt)°C"
        case .both:
            return "\(Int(Double(converted.fahrenheit) ?? 0))°F/\(tempInt)°C"
        }
    }
    
    var formattedTempRange: String {
        guard let tempMax = temperatureMax, let tempMin = temperatureMin else { return "—" }
        let maxInt = Int(tempMax.rounded())
        let minInt = Int(tempMin.rounded())
        let convertedMax = MeasurementConverter.convertTemperature(String(maxInt), from: "°C")
        let convertedMin = MeasurementConverter.convertTemperature(String(minInt), from: "°C")
        let displayMode = UserDefaults.standard.unitSystemDisplayMode
        
        switch displayMode {
        case .imperial:
            return "\(Int(Double(convertedMax.fahrenheit) ?? 0))°F - \(Int(Double(convertedMin.fahrenheit) ?? 0))°F"
        case .metric:
            return "\(maxInt)°C - \(minInt)°C"
        case .both:
            return "\(Int(Double(convertedMax.fahrenheit) ?? 0))/\(maxInt)° - \(Int(Double(convertedMin.fahrenheit) ?? 0))/\(minInt)°"
        }
    }
    
    var formattedWindSpeed: String {
        guard let wind = windSpeed else { return "—" }
        let displayMode = UserDefaults.standard.unitSystemDisplayMode
        let converted = MeasurementConverter.convertWindSpeed(String(format: "%.0f", wind), from: "km/h")
        
        switch displayMode {
        case .imperial:
            return "\(Int(Double(converted.mph) ?? 0))mph"
        case .metric:
            return "\(Int(wind))km/h"
        case .both:
            return "\(Int(Double(converted.mph) ?? 0))mph/\(Int(wind))km/h"
        }
    }
    
    var windDirectionText: String {
        guard let direction = windDirection else { return "—" }
        return WindDirectionConverter.directionText(for: direction)
    }
    
    var formattedPrecipitation: String {
        guard let precip = precipitationAmount else { return "—" }
        let displayMode = UserDefaults.standard.unitSystemDisplayMode
        
        switch displayMode {
        case .imperial:
            let inches = precip * 0.0393701
            if inches < 0.05 {
                return "0.00in"
            } else {
                return String(format: "%.2fin", inches)
            }
        case .metric:
            if precip < 0.5 {
                return "0.0mm"
            } else {
                return String(format: "%.1fmm", precip)
            }
        case .both:
            let inches = precip * 0.0393701
            if precip < 0.5 && inches < 0.05 {
                return "0.0mm/0.00in"
            } else {
                return String(format: "%.1fmm/%.2fin", precip, inches)
            }
        }
    }
    
    var formattedHumidity: String {
        guard let hum = humidity else { return "—" }
        return "\(Int((hum * 100).rounded()))%"
    }
    
    var formattedCloudCover: String {
        guard let cloud = cloudCover else { return "—" }
        return "\(Int((cloud * 100).rounded()))%"
    }
}

struct WeatherAlert: Identifiable {
    let id: String
    let severity: AlertSeverity
    let source: String
    let eventName: String
    let region: String
    let summary: String
    let detailsURL: URL?
    let effectiveTime: Date
    let expiresTime: Date?
    
    var isActive: Bool {
        let now = Date()
        if let expires = expiresTime {
            return now >= effectiveTime && now < expires
        }
        return now >= effectiveTime
    }
    
    var severityColor: Color {
        switch severity {
        case .extreme:
            return .red
        case .severe:
            return .orange
        case .moderate:
            return .yellow
        case .minor:
            return .blue
        case .unknown:
            return .gray
        }
    }
    
    var severityIcon: String {
        switch severity {
        case .extreme:
            return "exclamationmark.triangle.fill"
        case .severe:
            return "exclamationmark.triangle.fill"
        case .moderate:
            return "exclamationmark.circle.fill"
        case .minor:
            return "info.circle.fill"
        case .unknown:
            return "info.circle"
        }
    }
    
    var formattedTimeRange: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        
        let start = formatter.string(from: effectiveTime)
        
        if let expires = expiresTime {
            let end = formatter.string(from: expires)
            return "\(start) - \(end)"
        } else {
            return "Effective: \(start)"
        }
    }
}

enum AlertSeverity: String {
    case extreme = "extreme"
    case severe = "severe"
    case moderate = "moderate"
    case minor = "minor"
    case unknown = "unknown"
    
    init(fromString value: String) {
        self = AlertSeverity(rawValue: value.lowercased()) ?? .unknown
    }
}