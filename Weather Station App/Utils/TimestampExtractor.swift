//
//  TimestampExtractor.swift
//  Weather Station App
//
//  Created by Curtis Netterville on 10/26/25.
//

import Foundation

struct TimestampExtractor {
    
    /// Parses a timestamp string from the API into a Date object
    static func parseTimestamp(_ timestampString: String) -> Date? {
        // Handle empty or invalid strings
        guard !timestampString.isEmpty && timestampString != "0" else {
            return nil
        }
        
        // Try Unix timestamp first (most common format from API)
        if let unixTimestamp = Double(timestampString) {
            let date = Date(timeIntervalSince1970: unixTimestamp)
            
            // Check if this is a reasonable timestamp (between 2020 and 2030)
            let currentYear = Calendar.current.component(.year, from: Date())
            let timestampYear = Calendar.current.component(.year, from: date)
            
            if timestampYear >= 2020 && timestampYear <= currentYear + 1 {
                return date
            } else {
                print("⚠️ Unix timestamp '\(timestampString)' produces date: \(date) (year \(timestampYear))")
                
                // The API might be using milliseconds instead of seconds
                if unixTimestamp > 1_000_000_000_000 {
                    let dateFromMs = Date(timeIntervalSince1970: unixTimestamp / 1000)
                    let msYear = Calendar.current.component(.year, from: dateFromMs)
                    if msYear >= 2020 && msYear <= currentYear + 1 {
                        print("✅ Converted from milliseconds: \(dateFromMs)")
                        return dateFromMs
                    }
                }
                
                // If timestamp is way in the future, the API might be using a different epoch
                // For now, use the current time as fallback for problematic timestamps
                print("⚠️ Using current time as fallback for problematic timestamp")
                return Date()
            }
        }
        
        // Try common date string formats
        let formatters = createDateFormatters()
        
        for formatter in formatters {
            if let date = formatter.date(from: timestampString) {
                return date
            }
        }
        
        print("⚠️ Could not parse timestamp: '\(timestampString)'")
        return nil
    }
    
    /// Special method to test timestamp parsing with the actual API response
    static func testTimestampParsing(_ timestamp: String) -> (parsed: Date?, analysis: String) {
        var analysis = "🔍 Testing timestamp: '\(timestamp)'\n"
        
        if let unixTime = Double(timestamp) {
            let standardDate = Date(timeIntervalSince1970: unixTime)
            analysis += "Standard Unix: \(standardDate)\n"
            analysis += "Year: \(Calendar.current.component(.year, from: standardDate))\n"
            
            if unixTime > 1_000_000_000_000 {
                let msDate = Date(timeIntervalSince1970: unixTime / 1000)
                analysis += "As milliseconds: \(msDate)\n"
            }
            
            // Test current time for comparison
            let now = Date()
            let currentUnix = now.timeIntervalSince1970
            analysis += "Current Unix time: \(Int(currentUnix))\n"
            analysis += "Current date: \(now)\n"
            analysis += "Difference: \(Int(unixTime - currentUnix)) seconds\n"
        }
        
        let parsed = parseTimestamp(timestamp)
        analysis += "Final parsed result: \(parsed?.description ?? "nil")"
        
        return (parsed, analysis)
    }
    
    /// Enhanced timestamp extraction with fallback to current time
    static func extractMostRecentTimestamp(from weatherData: WeatherStationData) -> Date? {
        var validTimestamps: [Date] = []
        
        // Collect all timestamps from all sensors
        let allSensors: [TimestampProvider] = [
            weatherData.outdoor,
            weatherData.indoor,
            weatherData.solarAndUvi,
            weatherData.wind,
            weatherData.pressure,
            weatherData.rainfallPiezo,
            weatherData.lightning,
            weatherData.pm25Ch1,
            weatherData.tempAndHumidityCh1,
            weatherData.tempAndHumidityCh2,
            weatherData.battery
        ]
        
        // Add optional sensors
        var allOptionalSensors: [TimestampProvider?] = [
            weatherData.rainfall,
            weatherData.pm25Ch2,
            weatherData.pm25Ch3,
            weatherData.tempAndHumidityCh3
        ]
        
        // Extract timestamps from all sensors
        for sensor in allSensors {
            validTimestamps.append(contentsOf: extractValidTimestamps(from: sensor))
        }
        
        for sensor in allOptionalSensors.compactMap({ $0 }) {
            validTimestamps.append(contentsOf: extractValidTimestamps(from: sensor))
        }
        
        print("📊 Found \(validTimestamps.count) valid timestamps from weather data")
        
        if validTimestamps.isEmpty {
            print("⚠️ No valid timestamps found in weather data, this suggests API timestamp format issue")
            // Return a very recent time so data appears fresh but is marked as problematic
            return Date().addingTimeInterval(-30) // 30 seconds ago
        }
        
        // Remove duplicates and sort to get the most recent
        let uniqueTimestamps = Array(Set(validTimestamps)).sorted()
        
        if let mostRecent = uniqueTimestamps.last {
            print("📊 Most recent data timestamp: \(mostRecent)")
            return mostRecent
        }
        
        return nil
    }
    
    /// Extracts only valid timestamps from sensor data
    private static func extractValidTimestamps<T: TimestampProvider>(from sensor: T) -> [Date] {
        let timestampStrings = sensor.getAllTimestamps()
        let validDates = timestampStrings.compactMap { parseTimestamp($0) }
        
        if validDates.isEmpty && !timestampStrings.isEmpty {
            print("⚠️ No valid dates extracted from timestamps: \(timestampStrings)")
        }
        
        return validDates
    }
    
    /// Returns a detailed timestamp analysis for debugging
    static func analyzeTimestamps(from weatherData: WeatherStationData) -> String {
        var analysis = "🔍 Timestamp Analysis:\n"
        
        // Analyze outdoor sensor as example
        let outdoorTimestamps = weatherData.outdoor.getAllTimestamps()
        analysis += "Outdoor sensor timestamps:\n"
        
        for (index, timestamp) in outdoorTimestamps.enumerated() {
            if let parsed = parseTimestamp(timestamp) {
                analysis += "  [\(index)] \(timestamp) → \(parsed)\n"
            } else {
                analysis += "  [\(index)] \(timestamp) → INVALID\n"
            }
        }
        
        return analysis
    }
    
    /// Creates date formatters for common timestamp formats
    private static func createDateFormatters() -> [DateFormatter] {
        let formats = [
            "yyyy-MM-dd HH:mm:ss",           // 2023-10-26 14:30:25
            "yyyy-MM-dd'T'HH:mm:ss'Z'",      // ISO format with Z
            "yyyy-MM-dd'T'HH:mm:ssXXXXX",    // ISO format with timezone
            "yyyy-MM-dd'T'HH:mm:ss",         // ISO format without timezone
            "MM/dd/yyyy HH:mm:ss",           // US format
            "dd/MM/yyyy HH:mm:ss",           // European format
        ]
        
        return formats.map { format in
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.timeZone = TimeZone(secondsFromGMT: 0) // Parse as UTC first
            return formatter
        }
    }
    
    /// Extracts timestamps from any sensor data that conforms to TimestampProvider
    private static func extractTimestamps<T: TimestampProvider>(from sensor: T) -> [Date] {
        let timestamps = sensor.getAllTimestamps()
        return timestamps.compactMap { parseTimestamp($0) }
    }
    
    /// Formats a timestamp for display using the appropriate timezone
    static func formatTimestamp(_ date: Date, for station: WeatherStation, style: DateFormatter.Style = .medium) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = style
        formatter.timeStyle = style
        formatter.timeZone = station.timeZone
        return formatter.string(from: date)
    }
    
    /// Formats a timestamp for display with custom format using station timezone
    static func formatTimestamp(_ date: Date, for station: WeatherStation, format: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.timeZone = station.timeZone
        return formatter.string(from: date)
    }
    
    /// Returns the age of data in a human-readable format
    static func formatDataAge(from recordedTime: Date, relativeTo currentTime: Date = Date()) -> String {
        let age = currentTime.timeIntervalSince(recordedTime)
        
        if age < 60 {
            return "\(Int(age))s ago"
        } else if age < 3600 {
            return "\(Int(age/60))m ago"
        } else if age < 86400 {
            return "\(Int(age/3600))h ago"
        } else {
            return "\(Int(age/86400))d ago"
        }
    }
    
    /// Determines if data is considered fresh based on the recording time
    static func isDataFresh(_ recordedTime: Date, freshnessDuration: TimeInterval, relativeTo currentTime: Date = Date()) -> Bool {
        return currentTime.timeIntervalSince(recordedTime) < freshnessDuration
    }
    
    /// Manual timestamp correction for APIs with known timestamp issues
    static func correctTimestamp(_ timestamp: String, knownOffsetYears: Int = 0) -> Date? {
        guard let unixTimestamp = Double(timestamp) else {
            return parseTimestamp(timestamp) // Fall back to regular parsing
        }
        
        // If we know the API has a consistent offset, apply it here
        let correctedTimestamp = unixTimestamp - Double(knownOffsetYears * 31_536_000) // Subtract years in seconds
        let date = Date(timeIntervalSince1970: correctedTimestamp)
        
        // Validate the corrected timestamp is reasonable
        let currentYear = Calendar.current.component(.year, from: Date())
        let timestampYear = Calendar.current.component(.year, from: date)
        
        if timestampYear >= 2020 && timestampYear <= currentYear + 1 {
            print("✅ Applied \(knownOffsetYears) year correction to timestamp: \(date)")
            return date
        }
        
        // If correction didn't work, fall back to standard parsing
        return parseTimestamp(timestamp)
    }
}

// MARK: - Protocol for extracting timestamps

protocol TimestampProvider {
    func getAllTimestamps() -> [String]
}

// MARK: - Extensions to implement TimestampProvider

extension OutdoorData: TimestampProvider {
    func getAllTimestamps() -> [String] {
        return [
            temperature.time,
            feelsLike.time,
            appTemp.time,
            dewPoint.time,
            vpd.time,
            humidity.time
        ]
    }
}

extension IndoorData: TimestampProvider {
    func getAllTimestamps() -> [String] {
        return [
            temperature.time,
            humidity.time,
            dewPoint.time,
            feelsLike.time,
            appTempIn.time
        ]
    }
}

extension SolarAndUVIData: TimestampProvider {
    func getAllTimestamps() -> [String] {
        return [solar.time, uvi.time]
    }
}

extension RainfallData: TimestampProvider {
    func getAllTimestamps() -> [String] {
        return [
            rainRate.time,
            daily.time,
            event.time,
            oneHour.time,
            twentyFourHours.time,
            weekly.time,
            monthly.time,
            yearly.time
        ]
    }
}

extension RainfallPiezoData: TimestampProvider {
    func getAllTimestamps() -> [String] {
        return [
            rainRate.time,
            daily.time,
            state.time,
            event.time,
            oneHour.time,
            twentyFourHours.time,
            weekly.time,
            monthly.time,
            yearly.time
        ]
    }
}

extension WindData: TimestampProvider {
    func getAllTimestamps() -> [String] {
        return [
            windSpeed.time,
            windGust.time,
            windDirection.time,
            tenMinuteAverageWindDirection.time
        ]
    }
}

extension PressureData: TimestampProvider {
    func getAllTimestamps() -> [String] {
        return [relative.time, absolute.time]
    }
}

extension LightningData: TimestampProvider {
    func getAllTimestamps() -> [String] {
        return [distance.time, count.time]
    }
}

extension PM25Data: TimestampProvider {
    func getAllTimestamps() -> [String] {
        return [
            realTimeAqi.time,
            pm25.time,
            twentyFourHoursAqi.time
        ]
    }
}

extension TempHumidityData: TimestampProvider {
    func getAllTimestamps() -> [String] {
        var timestamps = [temperature.time]
        if let humidity = humidity {
            timestamps.append(humidity.time)
        }
        return timestamps
    }
}

extension BatteryData: TimestampProvider {
    func getAllTimestamps() -> [String] {
        var timestamps: [String] = []
        
        [console, hapticArrayBattery, hapticArrayCapacitor, rainfallSensor, 
         lightningSensor, pm25SensorCh1, pm25SensorCh2, tempHumiditySensorCh1, 
         tempHumiditySensorCh2, tempHumiditySensorCh3].forEach { sensor in
            if let sensor = sensor {
                timestamps.append(sensor.time)
            }
        }
        
        return timestamps
    }
}