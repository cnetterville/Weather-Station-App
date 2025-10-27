//
//  WeatherDetailHelpers.swift
//  Weather Station App
//
//  Created by Curtis Netterville on 10/25/25.
//

import SwiftUI

// MARK: - Layout Helpers
struct WeatherDetailLayoutHelper {
    // Dynamic column calculation based on window width
    static func calculateColumns(for width: CGFloat) -> Int {
        switch width {
        case 0..<650:
            return 1
        case 650..<1000:
            return 2
        case 1000..<1400:
            return 3
        case 1400..<1800:
            return 4
        default:
            return 5
        }
    }
    
    static func calculateTileSize(for width: CGFloat, columns: Int) -> CGFloat {
        let spacing: CGFloat = 16
        let totalSpacing = spacing * CGFloat(columns - 1)
        let availableWidth = width - totalSpacing - 32 // 32 for padding
        let baseSize = availableWidth / CGFloat(columns)
        let minTileSize: CGFloat = 320
        let maxTileSize: CGFloat = 380
        return min(maxTileSize, max(minTileSize, baseSize))
    }
}

// MARK: - Status Text Helpers
struct WeatherStatusHelpers {
    static func rainStatusText(_ value: String) -> String {
        switch value {
        case "0": return "Not Raining"
        case "1": return "Raining"
        default: return "Status: \(value)"
        }
    }
    
    static func rainStatusColor(_ value: String) -> Color {
        switch value {
        case "0": return .green
        case "1": return .blue
        default: return .secondary
        }
    }
    
    static func aqiColor(for value: String) -> Color {
        guard let intValue = Int(value) else { return .secondary }
        switch intValue {
        case 0...50: return .green
        case 51...100: return .yellow
        case 101...150: return .orange
        case 151...200: return .red
        case 201...300: return .purple
        default: return .black
        }
    }
    
    static func batteryLevelText(_ value: String) -> String {
        guard let level = Int(value) else { return value }
        switch level {
        case 0: return "Empty"
        case 1: return "1-20%"
        case 2: return "21-40%"
        case 3: return "41-60%"
        case 4: return "61-80%"
        case 5: return "81-100%"
        case 6: return "DC Power"
        default: return value
        }
    }
    
    static func tempHumidityBatteryStatusText(_ value: String) -> String {
        switch value {
        case "0": return "Normal"
        case "1": return "Low"
        default: return value
        }
    }
}

// MARK: - Solar & UV Helpers
struct SolarUVHelpers {
    static func getUVIndexColor(_ value: String) -> Color {
        guard let uvi = Double(value) else { return .secondary }
        switch uvi {
        case 0...2: return .green
        case 3...5: return .yellow
        case 6...7: return .orange
        case 8...10: return .red
        default: return .purple
        }
    }
    
    static func getUVIndexDescription(_ value: String) -> String {
        guard let uvi = Double(value) else { return "Unknown" }
        switch uvi {
        case 0...2: return "Low"
        case 3...5: return "Moderate"
        case 6...7: return "High"
        case 8...10: return "Very High"
        default: return "Extreme"
        }
    }
    
    static func getSolarIntensityDescription(_ value: Double) -> String {
        switch value {
        case 0...200: return "Very Low"
        case 201...400: return "Low"
        case 401...600: return "Moderate"
        case 601...800: return "High"
        case 801...1000: return "Very High"
        default: return "Extreme"
        }
    }
    
    static func getSolarIntensityColor(_ value: Double) -> Color {
        switch value {
        case 0...200: return .gray
        case 201...400: return .blue
        case 401...600: return .green
        case 601...800: return .orange
        default: return .red
        }
    }
    
    static func estimateSolarPanelOutput(_ solarRadiation: Double) -> Double {
        // Rough estimation: peak solar radiation is typically ~1000 W/m²
        let peakRadiation = 1000.0
        return min(100, (solarRadiation / peakRadiation) * 100)
    }
}

// MARK: - Wind Helpers
struct WindHelpers {
    static func getBeaufortScale(windSpeedMph: Double) -> (number: Int, description: String) {
        switch windSpeedMph {
        case 0...1: return (0, "Calm")
        case 1...3: return (1, "Light Air")
        case 4...7: return (2, "Light Breeze")
        case 8...12: return (3, "Gentle Breeze")
        case 13...18: return (4, "Moderate Breeze")
        case 19...24: return (5, "Fresh Breeze")
        case 25...31: return (6, "Strong Breeze")
        case 32...38: return (7, "Near Gale")
        case 39...46: return (8, "Gale")
        case 47...54: return (9, "Strong Gale")
        case 55...63: return (10, "Storm")
        case 64...72: return (11, "Violent Storm")
        default: return (12, "Hurricane")
        }
    }
}

// MARK: - Sun Helpers
struct SunHelpers {
    static func sunIconForCurrentTime(station: WeatherStation) -> String {
        guard let latitude = station.latitude, let longitude = station.longitude,
              let sunTimes = SunCalculator.calculateSunTimes(for: Date(), latitude: latitude, longitude: longitude, timeZone: station.timeZone) else {
            return "sun.horizon"
        }
        
        return sunTimes.isCurrentlyDaylight ? "sun.max.fill" : "moon.stars.fill"
    }
}