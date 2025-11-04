//
//  WeatherIconHelper.swift
//  Weather Station App
//
//  Created by Curtis Netterville on 10/25/25.
//

import Foundation

struct WeatherIconHelper {
    
    /// Get appropriate weather icon based on condition and time of day
    static func getWeatherIcon(for weatherCode: Int, station: WeatherStation) -> String {
        // Get base day icon
        let baseIcon = WeatherCodeInterpreter.systemIcon(for: weatherCode)
        
        // If we don't have location data, return base icon
        guard let latitude = station.latitude,
              let longitude = station.longitude else {
            return baseIcon
        }
        
        // Check if it's currently nighttime at the station location
        if let sunTimes = SunCalculator.calculateSunTimes(
            for: Date(),
            latitude: latitude,
            longitude: longitude,
            timeZone: station.timeZone
        ) {
            let isNighttime = !sunTimes.isCurrentlyDaylight
            
            if isNighttime {
                return convertToNightIcon(baseIcon)
            }
        }
        
        return baseIcon
    }
    
    /// Convert a generic icon to day/night variant based on time
    static func adaptIconForTimeOfDay(_ icon: String, station: WeatherStation) -> String {
        // If we don't have location data, return original icon
        guard let latitude = station.latitude,
              let longitude = station.longitude else {
            return icon
        }
        
        // Check if it's currently nighttime at the station location
        if let sunTimes = SunCalculator.calculateSunTimes(
            for: Date(),
            latitude: latitude,
            longitude: longitude,
            timeZone: station.timeZone
        ) {
            let isNighttime = !sunTimes.isCurrentlyDaylight
            
            if isNighttime {
                return convertToNightIcon(icon)
            }
        }
        
        return icon
    }
    
    /// Convert day icons to night icons
    private static func convertToNightIcon(_ dayIcon: String) -> String {
        switch dayIcon {
        // Clear sky variants
        case "sun.max.fill":
            return "moon.stars.fill"
        case "sun.max":
            return "moon.fill"
        case "sun.min.fill":
            return "moon.fill"
        case "sun.min":
            return "moon"
            
        // Partly cloudy variants
        case "cloud.sun.fill":
            return "cloud.moon.fill"
        case "cloud.sun":
            return "cloud.moon"
            
        // Rain variants
        case "cloud.sun.rain.fill":
            return "cloud.moon.rain.fill"
        case "cloud.sun.rain":
            return "cloud.moon.rain"
            
        // Storm variants
        case "cloud.sun.bolt.fill":
            return "cloud.moon.bolt.fill"
        case "cloud.sun.bolt":
            return "cloud.moon.bolt"
            
        default:
            // For weather that doesn't have sun/moon variants (rain, snow, fog, etc.)
            // keep the original icon as-is
            return dayIcon
        }
    }
}