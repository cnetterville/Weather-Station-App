//
//  TemperatureConverter.swift
//  Weather Station App
//
//  Created by Curtis Netterville on 10/25/25.
//

import Foundation

struct MeasurementConverter {
    // MARK: - Temperature Conversions
    static func convertTemperature(_ value: String, from originalUnit: String) -> (fahrenheit: String, celsius: String) {
        guard let temp = Double(value) else { 
            return (fahrenheit: value, celsius: value) 
        }
        
        switch originalUnit.uppercased() {
        case "°F", "F":
            let celsius = (temp - 32) * 5 / 9
            return (fahrenheit: String(format: "%.1f", temp), celsius: String(format: "%.1f", celsius))
        case "°C", "C":
            let fahrenheit = (temp * 9 / 5) + 32
            return (fahrenheit: String(format: "%.1f", fahrenheit), celsius: String(format: "%.1f", temp))
        default:
            // If unit is unclear, assume Fahrenheit (common for US weather stations)
            let celsius = (temp - 32) * 5 / 9
            return (fahrenheit: String(format: "%.1f", temp), celsius: String(format: "%.1f", celsius))
        }
    }
    
    static func formatDualTemperature(_ value: String, originalUnit: String) -> String {
        let converted = convertTemperature(value, from: originalUnit)
        return "\(converted.fahrenheit)°F / \(converted.celsius)°C"
    }
    
    // MARK: - Wind Speed Conversions
    static func convertWindSpeed(_ value: String, from originalUnit: String) -> (mph: String, kph: String, ms: String) {
        guard let speed = Double(value) else {
            return (mph: value, kph: value, ms: value)
        }
        
        switch originalUnit.lowercased() {
        case "mph":
            let kph = speed * 1.60934
            let ms = speed * 0.44704
            return (mph: String(format: "%.1f", speed), kph: String(format: "%.1f", kph), ms: String(format: "%.1f", ms))
        case "km/h", "kph":
            let mph = speed / 1.60934
            let ms = speed / 3.6
            return (mph: String(format: "%.1f", mph), kph: String(format: "%.1f", speed), ms: String(format: "%.1f", ms))
        case "m/s":
            let mph = speed * 2.23694
            let kph = speed * 3.6
            return (mph: String(format: "%.1f", mph), kph: String(format: "%.1f", kph), ms: String(format: "%.1f", speed))
        default:
            // Default assume mph for US weather stations
            let kph = speed * 1.60934
            let ms = speed * 0.44704
            return (mph: String(format: "%.1f", speed), kph: String(format: "%.1f", kph), ms: String(format: "%.1f", ms))
        }
    }
    
    static func formatDualWindSpeed(_ value: String, originalUnit: String) -> String {
        let converted = convertWindSpeed(value, from: originalUnit)
        return "\(converted.mph) mph / \(converted.kph) km/h"
    }
    
    // MARK: - Distance Conversions
    static func convertDistance(_ value: String, from originalUnit: String) -> (miles: String, kilometers: String) {
        guard let distance = Double(value) else {
            return (miles: value, kilometers: value)
        }
        
        switch originalUnit.lowercased() {
        case "mi", "mile", "miles":
            let kilometers = distance * 1.60934
            return (miles: String(format: "%.1f", distance), kilometers: String(format: "%.1f", kilometers))
        case "km", "kilometer", "kilometers":
            let miles = distance / 1.60934
            return (miles: String(format: "%.1f", miles), kilometers: String(format: "%.1f", distance))
        default:
            // Default assume miles for US weather stations
            let kilometers = distance * 1.60934
            return (miles: String(format: "%.1f", distance), kilometers: String(format: "%.1f", kilometers))
        }
    }
    
    static func formatDualDistance(_ value: String, originalUnit: String) -> String {
        let converted = convertDistance(value, from: originalUnit)
        return "\(converted.miles) mi / \(converted.kilometers) km"
    }
    
    // MARK: - Rainfall Conversions
    static func convertRainfall(_ value: String, from originalUnit: String) -> (inches: String, millimeters: String) {
        guard let rain = Double(value) else {
            return (inches: value, millimeters: value)
        }
        
        switch originalUnit.lowercased() {
        case "in", "inch", "inches":
            let millimeters = rain * 25.4
            return (inches: String(format: "%.2f", rain), millimeters: String(format: "%.1f", millimeters))
        case "mm", "millimeter", "millimeters":
            let inches = rain / 25.4
            return (inches: String(format: "%.2f", inches), millimeters: String(format: "%.1f", rain))
        default:
            // Default assume inches for US weather stations
            let millimeters = rain * 25.4
            return (inches: String(format: "%.2f", rain), millimeters: String(format: "%.1f", millimeters))
        }
    }
    
    static func formatDualRainfall(_ value: String, originalUnit: String) -> String {
        let converted = convertRainfall(value, from: originalUnit)
        return "\(converted.inches) in / \(converted.millimeters) mm"
    }
    
    // MARK: - Rain Rate Conversions  
    static func convertRainRate(_ value: String, from originalUnit: String) -> (inchesPerHour: String, millimetersPerHour: String) {
        guard let rate = Double(value) else {
            return (inchesPerHour: value, millimetersPerHour: value)
        }
        
        switch originalUnit.lowercased() {
        case "in/hr", "in/h", "inches/hour", "inches per hour":
            let mmPerHour = rate * 25.4
            return (inchesPerHour: String(format: "%.2f", rate), millimetersPerHour: String(format: "%.1f", mmPerHour))
        case "mm/hr", "mm/h", "millimeters/hour", "millimeters per hour":
            let inPerHour = rate / 25.4
            return (inchesPerHour: String(format: "%.2f", inPerHour), millimetersPerHour: String(format: "%.1f", rate))
        default:
            // Default assume inches per hour for US weather stations
            let mmPerHour = rate * 25.4
            return (inchesPerHour: String(format: "%.2f", rate), millimetersPerHour: String(format: "%.1f", mmPerHour))
        }
    }
    
    static func formatDualRainRate(_ value: String, originalUnit: String) -> String {
        let converted = convertRainRate(value, from: originalUnit)
        return "\(converted.inchesPerHour) in/h / \(converted.millimetersPerHour) mm/h"
    }
    
    // MARK: - Wind Direction Conversions
    static func convertDegreesToCompass(_ degrees: String) -> String {
        guard let deg = Double(degrees) else {
            return degrees
        }
        
        // Normalize degrees to 0-360 range
        let normalizedDegrees = deg.truncatingRemainder(dividingBy: 360)
        let positiveDegrees = normalizedDegrees < 0 ? normalizedDegrees + 360 : normalizedDegrees
        
        // Convert to compass direction
        switch positiveDegrees {
        case 0..<11.25:
            return "N"
        case 11.25..<33.75:
            return "NNE"
        case 33.75..<56.25:
            return "NE"
        case 56.25..<78.75:
            return "ENE"
        case 78.75..<101.25:
            return "E"
        case 101.25..<123.75:
            return "ESE"
        case 123.75..<146.25:
            return "SE"
        case 146.25..<168.75:
            return "SSE"
        case 168.75..<191.25:
            return "S"
        case 191.25..<213.75:
            return "SSW"
        case 213.75..<236.25:
            return "SW"
        case 236.25..<258.75:
            return "WSW"
        case 258.75..<281.25:
            return "W"
        case 281.25..<303.75:
            return "WNW"
        case 303.75..<326.25:
            return "NW"
        case 326.25..<348.75:
            return "NNW"
        case 348.75...360:
            return "N"
        default:
            return "N" // fallback
        }
    }
    
    static func formatWindDirectionWithCompass(_ degrees: String) -> String {
        let compass = convertDegreesToCompass(degrees)
        if let deg = Double(degrees) {
            return "\(compass) (\(String(format: "%.0f", deg))°)"
        } else {
            return compass
        }
    }
}

// Legacy support - keeping the old name for backwards compatibility
typealias TemperatureConverter = MeasurementConverter