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
    let timeZone: TimeZone
    
    var formattedSunrise: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.timeZone = timeZone
        return formatter.string(from: sunrise)
    }
    
    var formattedSunset: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.timeZone = timeZone
        return formatter.string(from: sunset)
    }
    
    var formattedDayLength: String {
        let hours = Int(dayLength / 3600)
        let minutes = Int((dayLength.truncatingRemainder(dividingBy: 3600)) / 60)
        return String(format: "%dh %02dm", hours, minutes)
    }
    
    /// Calculate time remaining until sunset (daylight left)
    var daylightLeft: TimeInterval? {
        let now = Date()
        
        // Only return daylight left if it's currently daytime and before sunset
        if now >= sunrise && now <= sunset {
            return sunset.timeIntervalSince(now)
        }
        
        return nil
    }
    
    /// Formatted string for daylight remaining
    var formattedDaylightLeft: String {
        guard let daylightRemaining = daylightLeft else {
            return "Nighttime"
        }
        
        let hours = Int(daylightRemaining / 3600)
        let minutes = Int((daylightRemaining.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        } else {
            return String(format: "%dm", minutes)
        }
    }
    
    var isCurrentlyDaylight: Bool {
        let now = Date()
        return now >= sunrise && now <= sunset
    }
}

struct SunTimesCache {
    let cacheKey: String
    let sunTimes: SunTimes
    let calculatedDate: Date
    
    init(cacheKey: String, sunTimes: SunTimes) {
        self.cacheKey = cacheKey
        self.sunTimes = sunTimes
        self.calculatedDate = Date()
    }
}

class SunCalculator {
    
    // Cache for storing calculated sun times
    private static var sunTimesCache: [String: SunTimesCache] = [:]
    private static let cacheQueue = DispatchQueue(label: "sun.calculator.cache", attributes: .concurrent)
    
    /// Generate cache key for a specific location, date, and timezone
    private static func generateCacheKey(date: Date, latitude: Double, longitude: Double, timeZone: TimeZone) -> String {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let dateString = String(format: "%04d%02d%02d", dateComponents.year ?? 0, dateComponents.month ?? 0, dateComponents.day ?? 0)
        
        // Round coordinates to 4 decimal places for cache key (about 11m precision)
        let latString = String(format: "%.4f", latitude)
        let lngString = String(format: "%.4f", longitude)
        
        return "\(dateString)_\(latString)_\(lngString)_\(timeZone.identifier)"
    }
    
    /// Get cached SunTimes or calculate new ones if not cached
    private static func getCachedOrCalculateSunTimes(for date: Date, latitude: Double, longitude: Double, timeZone: TimeZone) -> SunTimes? {
        let cacheKey = generateCacheKey(date: date, latitude: latitude, longitude: longitude, timeZone: timeZone)
        
        // Check cache first (thread-safe read)
        return cacheQueue.sync {
            if let cachedResult = sunTimesCache[cacheKey] {
                // Check if cache entry is still valid (within same day and not too old)
                let now = Date()
                let cacheAge = now.timeIntervalSince(cachedResult.calculatedDate)
                
                // Cache is valid for the same day and up to 1 hour old
                if cacheAge < 3600 {
                    return cachedResult.sunTimes
                } else {
                    // Remove stale cache entry
                    sunTimesCache.removeValue(forKey: cacheKey)
                }
            }
            return nil
        }
    }
    
    /// Store calculated SunTimes in cache
    private static func cacheSunTimes(_ sunTimes: SunTimes, for date: Date, latitude: Double, longitude: Double, timeZone: TimeZone) {
        let cacheKey = generateCacheKey(date: date, latitude: latitude, longitude: longitude, timeZone: timeZone)
        let cacheEntry = SunTimesCache(cacheKey: cacheKey, sunTimes: sunTimes)
        
        cacheQueue.async(flags: .barrier) {
            sunTimesCache[cacheKey] = cacheEntry
            
            // Clean up old cache entries (keep only last 50 entries)
            if sunTimesCache.count > 50 {
                let sortedKeys = sunTimesCache.keys.sorted()
                let keysToRemove = sortedKeys.prefix(sunTimesCache.count - 40) // Keep last 40
                for key in keysToRemove {
                    sunTimesCache.removeValue(forKey: key)
                }
            }
        }
    }
    
    /// Clear the entire cache (useful for testing or memory management)
    static func clearCache() {
        cacheQueue.async(flags: .barrier) {
            sunTimesCache.removeAll()
        }
    }
    
    /// Get cache statistics for debugging
    static func getCacheInfo() -> (count: Int, keys: [String]) {
        return cacheQueue.sync {
            return (count: sunTimesCache.count, keys: Array(sunTimesCache.keys))
        }
    }
    
    /// Calculate sunrise and sunset times using the accurate astronomical formula
    /// Based on NOAA's sunrise/sunset calculation algorithm with caching
    static func calculateSunTimes(for date: Date, latitude: Double, longitude: Double, timeZone: TimeZone = TimeZone.current) -> SunTimes? {
        // Try to get cached result first
        if let cachedResult = getCachedOrCalculateSunTimes(for: date, latitude: latitude, longitude: longitude, timeZone: timeZone) {
            return cachedResult
        }
        
        // Calculate new result
        let sunTimes = performSunTimesCalculation(for: date, latitude: latitude, longitude: longitude, timeZone: timeZone)
        
        // Cache the result if calculation was successful
        if let result = sunTimes {
            cacheSunTimes(result, for: date, latitude: latitude, longitude: longitude, timeZone: timeZone)
        }
        
        return sunTimes
    }
    
    /// Perform the actual sun times calculation (moved from original calculateSunTimes)
    private static func performSunTimesCalculation(for date: Date, latitude: Double, longitude: Double, timeZone: TimeZone) -> SunTimes? {
        // First, determine what "today" is in the station's local timezone
        var localCalendar = Calendar.current
        localCalendar.timeZone = timeZone
        let localDate = localCalendar.startOfDay(for: date)
        
        // Convert the local date to UTC for astronomical calculations
        // We want to calculate sunrise/sunset for the local date, not the UTC date
        var utcCalendar = Calendar.current
        utcCalendar.timeZone = TimeZone(secondsFromGMT: 0)!
        
        // Get the UTC date that corresponds to the same calendar day as the local date
        _ = localCalendar.dateInterval(of: .day, for: localDate)?.start ?? localDate
        
        // Get day of year using the local calendar (not UTC calendar)
        let dayOfYear = localCalendar.ordinality(of: .day, in: .year, for: localDate) ?? 1
        
        // Convert input longitude to positive east convention
        let lng = longitude
        let lat = latitude
        
        // Calculate the fractional year
        let N = Double(dayOfYear)
        let gamma = 2.0 * .pi / 365.0 * (N - 1.0)
        
        // Equation of time (in minutes)
        let eqtime = 229.18 * (0.000075 + 0.001868 * cos(gamma) - 0.032077 * sin(gamma) - 0.014615 * cos(2 * gamma) - 0.040849 * sin(2 * gamma))
        
        // Solar declination angle (in radians)
        let decl = 0.006918 - 0.399912 * cos(gamma) + 0.070257 * sin(gamma) - 0.006758 * cos(2 * gamma) + 0.000907 * sin(2 * gamma) - 0.002697 * cos(3 * gamma) + 0.00148 * sin(3 * gamma)
        
        // Hour angle (in radians) - standard refraction correction
        let zenithAngle = 90.833 * .pi / 180.0  // 90.833 degrees in radians
        let latRad = lat * .pi / 180.0
        
        let cosH = (cos(zenithAngle) / (cos(latRad) * cos(decl))) - tan(latRad) * tan(decl)
        
        // Check for polar day or night
        if cosH < -1.0 {
            // Polar day - sun never sets
            return SunTimes(sunrise: localDate.addingTimeInterval(-12 * 3600), 
                          sunset: localDate.addingTimeInterval(36 * 3600), 
                          dayLength: 24 * 3600,
                          timeZone: timeZone)
        } else if cosH > 1.0 {
            // Polar night - sun never rises
            return SunTimes(sunrise: localDate, sunset: localDate, dayLength: 0, timeZone: timeZone)
        }
        
        let hourAngle = acos(cosH) * 180.0 / .pi  // Convert back to degrees
        
        // Calculate sunrise and sunset in minutes from midnight UTC
        // This gives us the UTC times without timezone correction
        let sunriseUTC = 720.0 - 4.0 * (lng + hourAngle) - eqtime
        let sunsetUTC = 720.0 - 4.0 * (lng - hourAngle) - eqtime
        
        // Create provisional sunrise and sunset times in UTC
        let provisionalSunrise = localDate.addingTimeInterval(sunriseUTC * 60.0)
        let provisionalSunset = localDate.addingTimeInterval(sunsetUTC * 60.0)
        
        // Now get the correct timezone offsets for the actual sunrise and sunset times
        // This is crucial for DST transitions - we need the offset that will be in effect
        // at the time of sunrise/sunset, not the offset at midnight
        let sunriseOffset = Double(timeZone.secondsFromGMT(for: provisionalSunrise)) / 3600.0
        let sunsetOffset = Double(timeZone.secondsFromGMT(for: provisionalSunset)) / 3600.0
        
        // Recalculate with the correct timezone offsets
        let sunriseLocalMinutes = sunriseUTC + (sunriseOffset * 60.0)
        let sunsetLocalMinutes = sunsetUTC + (sunsetOffset * 60.0)
        
        // Create final sunrise and sunset dates
        let sunrise = localDate.addingTimeInterval(sunriseLocalMinutes * 60.0)
        let sunset = localDate.addingTimeInterval(sunsetLocalMinutes * 60.0)
        
        // Calculate day length
        let dayLength = sunset.timeIntervalSince(sunrise)
        
        return SunTimes(sunrise: sunrise, sunset: sunset, dayLength: max(0, dayLength), timeZone: timeZone)
    }
    
    /// Convert a UTC time to local time in the target timezone  
    private static func convertUTCToLocalTime(_ utcDate: Date, targetTimeZone: TimeZone) -> Date {
        // Date represents absolute time, no conversion needed
        // The timezone will be used by DateFormatter in SunTimes
        return utcDate
    }
    
    /// Convert a UTC time to equivalent time in target timezone
    private static func convertUTCToTimezone(_ utcDate: Date, targetTimeZone: TimeZone) -> Date {
        // The utcDate represents an absolute moment in UTC
        // We need to return the same absolute moment, but the SunTimes struct
        // will handle the timezone formatting using the provided timeZone property
        // 
        // No conversion needed here since Date represents absolute time
        // The timezone will be used by DateFormatter in the SunTimes formatting methods
        return utcDate
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
        let today = calculateSunTimes(for: now, latitude: latitude, longitude: longitude, timeZone: timeZone) // Now uses cache
        
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
            let tomorrowSunTimes = calculateSunTimes(for: tomorrow, latitude: latitude, longitude: longitude, timeZone: timeZone) // Now uses cache
            return ("Sunrise", tomorrowSunTimes?.sunrise ?? sunTimes.sunrise, false)
        }
    }
}