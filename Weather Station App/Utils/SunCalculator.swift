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
    
    var isCurrentlyDaylight: Bool {
        let now = Date()
        
        // Convert all times to the station's timezone for proper comparison
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        
        let nowInStationTZ = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: now)
        let sunriseInStationTZ = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: sunrise)
        let sunsetInStationTZ = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: sunset)
        
        // Create comparable times (same date, different times)
        guard let nowTime = calendar.date(from: nowInStationTZ),
              let sunriseTime = calendar.date(from: sunriseInStationTZ),
              let sunsetTime = calendar.date(from: sunsetInStationTZ) else {
            // Fallback to simple comparison
            return now >= sunrise && now <= sunset
        }
        
        return nowTime >= sunriseTime && nowTime <= sunsetTime
    }
}

class SunCalculator {
    
    /// Calculate sunrise and sunset times using the accurate astronomical formula
    /// Based on NOAA's sunrise/sunset calculation algorithm
    static func calculateSunTimes(for date: Date, latitude: Double, longitude: Double, timeZone: TimeZone = TimeZone.current) -> SunTimes? {
        // Use GMT calendar for calculations
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        
        // Get day of year (1-365/366)
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
        
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
            let noon = calendar.startOfDay(for: date).addingTimeInterval(12 * 3600)
            return SunTimes(sunrise: noon.addingTimeInterval(-12 * 3600), 
                          sunset: noon.addingTimeInterval(12 * 3600), 
                          dayLength: 24 * 3600,
                          timeZone: timeZone)
        } else if cosH > 1.0 {
            let midnight = calendar.startOfDay(for: date)
            return SunTimes(sunrise: midnight, sunset: midnight, dayLength: 0, timeZone: timeZone)
        }
        
        let hourAngle = acos(cosH) * 180.0 / .pi  // Convert back to degrees
        
        // Calculate sunrise and sunset in minutes from midnight UTC
        let sunriseUTC = 720.0 - 4.0 * (lng + hourAngle) - eqtime
        let sunsetUTC = 720.0 - 4.0 * (lng - hourAngle) - eqtime
        
        // Create UTC dates
        let utcStartOfDay = calendar.startOfDay(for: date)
        let sunriseUTCDate = utcStartOfDay.addingTimeInterval(sunriseUTC * 60.0)
        let sunsetUTCDate = utcStartOfDay.addingTimeInterval(sunsetUTC * 60.0)
        
        // Convert to target timezone by creating equivalent local times
        // For proper timezone conversion, we need to find the local time that corresponds to the same moment
        var localCalendar = Calendar.current
        localCalendar.timeZone = timeZone
        
        // Convert UTC times to local timezone
        let localSunrise = sunriseUTCDate
        let localSunset = sunsetUTCDate
        
        // Calculate day length
        let dayLength = localSunset.timeIntervalSince(localSunrise)
        
        return SunTimes(sunrise: localSunrise, sunset: localSunset, dayLength: max(0, dayLength), timeZone: timeZone)
    }
    
    /// Convert a UTC time to equivalent time in target timezone
    private static func convertUTCToTimezone(_ utcDate: Date, targetTimeZone: TimeZone) -> Date {
        let utcOffsetSeconds = targetTimeZone.secondsFromGMT(for: utcDate)
        return utcDate.addingTimeInterval(TimeInterval(utcOffsetSeconds))
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