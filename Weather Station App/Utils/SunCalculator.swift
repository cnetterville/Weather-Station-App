//
//  SunCalculator.swift
//  Weather Station App
//
//  Created by Curtis Netterville on 10/25/25.
//

import Foundation

struct SunTimes {
    let sunrise: Date
    let sunset: Date
    let dayLength: TimeInterval
    
    var formattedSunrise: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: sunrise)
    }
    
    var formattedSunset: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: sunset)
    }
    
    var formattedDayLength: String {
        let hours = Int(dayLength / 3600)
        let minutes = Int((dayLength.truncatingRemainder(dividingBy: 3600)) / 60)
        return String(format: "%dh %02dm", hours, minutes)
    }
    
    var isCurrentlyDaylight: Bool {
        let now = Date()
        return now >= sunrise && now <= sunset
    }
}

class SunCalculator {
    
    /// Calculate sunrise and sunset times using the accurate astronomical formula
    /// Based on the hour angle calculation with proper atmospheric correction
    static func calculateSunTimes(for date: Date, latitude: Double, longitude: Double, timeZone: TimeZone = TimeZone.current) -> SunTimes? {
        let calendar = Calendar.current
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
        
        // Debug logging for timezone information
        print("🌍 SunCalculator Debug:")
        print("   Latitude: \(latitude), Longitude: \(longitude)")
        print("   Using timezone: \(timeZone.identifier)")
        print("   Timezone offset: \(timeZone.secondsFromGMT(for: date) / 3600) hours from GMT")
        
        // Convert latitude to radians
        let latRad = latitude * .pi / 180.0
        
        // Step 1: Calculate Solar Declination (δ) in radians
        let N = Double(dayOfYear)
        let delta = 0.4095 * sin(2 * .pi / 365 * (N - 80))
        
        // Step 2: Calculate Equation of Time (E) - simplified approximation in minutes
        let B = 2 * .pi * (N - 81) / 365
        let E = 9.87 * sin(2 * B) - 7.53 * cos(B) - 1.5 * sin(B)
        
        // Step 3: Calculate Hour Angle (H) using the main formula
        let zenithRad = 90.833 * .pi / 180.0  // 90.833° in radians (includes atmospheric refraction)
        
        let cosH = (cos(zenithRad) - sin(latRad) * sin(delta)) / (cos(latRad) * cos(delta))
        
        // Check for polar day or polar night
        if cosH < -1.0 {
            // Polar day - sun never sets
            let noon = calendar.startOfDay(for: date).addingTimeInterval(12 * 3600)
            return SunTimes(sunrise: noon.addingTimeInterval(-12 * 3600), 
                          sunset: noon.addingTimeInterval(12 * 3600), 
                          dayLength: 24 * 3600)
        } else if cosH > 1.0 {
            // Polar night - sun never rises
            let midnight = calendar.startOfDay(for: date)
            return SunTimes(sunrise: midnight, sunset: midnight, dayLength: 0)
        }
        
        let H = acos(cosH) * 180.0 / .pi  // Convert back to degrees
        
        // Step 4: Calculate Universal Time (UT) for sunrise and sunset
        let timeFromHour = H / 15.0  // Convert hour angle to hours
        let longitudeCorrection = longitude / 15.0  // Longitude correction in hours
        let equationCorrection = E / 60.0  // Equation of time correction in hours
        
        let utSunrise = 12 - timeFromHour - longitudeCorrection - equationCorrection
        let utSunset = 12 + timeFromHour - longitudeCorrection - equationCorrection
        
        print("   UT Sunrise: \(String(format: "%.2f", utSunrise)) hours")
        print("   UT Sunset: \(String(format: "%.2f", utSunset)) hours")
        
        // Step 5: Convert to local time using the specified timezone
        let timeZoneOffset = Double(timeZone.secondsFromGMT(for: date)) / 3600.0
        
        let localSunrise = utSunrise + timeZoneOffset
        let localSunset = utSunset + timeZoneOffset
        
        print("   Local Sunrise: \(String(format: "%.2f", localSunrise)) hours")
        print("   Local Sunset: \(String(format: "%.2f", localSunset)) hours")
        
        // Convert decimal hours to actual Date objects
        let startOfDay = calendar.startOfDay(for: date)
        let sunriseDate = startOfDay.addingTimeInterval(localSunrise * 3600)
        let sunsetDate = startOfDay.addingTimeInterval(localSunset * 3600)
        
        // Handle cases where times might be in the next/previous day
        let adjustedSunriseDate = adjustSunTimeIfNeeded(sunriseDate, referenceDate: date, calendar: calendar)
        let adjustedSunsetDate = adjustSunTimeIfNeeded(sunsetDate, referenceDate: date, calendar: calendar)
        
        print("   Final Sunrise: \(adjustedSunriseDate)")
        print("   Final Sunset: \(adjustedSunsetDate)")
        print("🌍 End SunCalculator Debug\n")
        
        // Calculate day length
        let dayLength = adjustedSunsetDate.timeIntervalSince(adjustedSunriseDate)
        
        return SunTimes(sunrise: adjustedSunriseDate, sunset: adjustedSunsetDate, dayLength: max(0, dayLength))
    }
    
    /// Adjust sun time if it falls outside the expected day range
    private static func adjustSunTimeIfNeeded(_ sunTime: Date, referenceDate: Date, calendar: Calendar) -> Date {
        let sunDay = calendar.startOfDay(for: sunTime)
        let refDay = calendar.startOfDay(for: referenceDate)
        
        if sunDay != refDay {
            // If the calculated time is in a different day, adjust it
            let dayDifference = calendar.dateComponents([.day], from: sunDay, to: refDay).day ?? 0
            return sunTime.addingTimeInterval(TimeInterval(dayDifference * 24 * 3600))
        }
        
        return sunTime
    }
    
    /// Calculate next event (sunrise or sunset) for a given location
    static func getNextSunEvent(latitude: Double, longitude: Double, timeZone: TimeZone = TimeZone.current) -> (event: String, time: Date, isCurrentlyDaylight: Bool) {
        let now = Date()
        let today = SunCalculator.calculateSunTimes(for: now, latitude: latitude, longitude: longitude, timeZone: timeZone)
        
        guard let sunTimes = today else {
            return ("Unknown", now, false)
        }
        
        if now < sunTimes.sunrise {
            return ("Sunrise", sunTimes.sunrise, false)
        } else if now < sunTimes.sunset {
            return ("Sunset", sunTimes.sunset, true)
        } else {
            // After sunset, get tomorrow's sunrise
            let calendar = Calendar.current
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
            let tomorrowSunTimes = SunCalculator.calculateSunTimes(for: tomorrow, latitude: latitude, longitude: longitude, timeZone: timeZone)
            return ("Sunrise", tomorrowSunTimes?.sunrise ?? sunTimes.sunrise, false)
        }
    }
}