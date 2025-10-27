//
//  DailyTemperatureCalculator.swift
//  Weather Station App
//
//  Created by Curtis Netterville on 10/25/25.
//

import Foundation

struct DailyTemperatureStats {
    let highTemp: Double
    let lowTemp: Double
    let highTempTime: Date?
    let lowTempTime: Date?
    let unit: String
    let dataPointCount: Int
    let isFromHistoricalData: Bool
    
    var formattedHigh: String {
        TemperatureConverter.formatTemperature(String(format: "%.1f", highTemp), originalUnit: unit)
    }
    
    var formattedLow: String {
        TemperatureConverter.formatTemperature(String(format: "%.1f", lowTemp), originalUnit: unit)
    }
    
    var formattedHighTime: String {
        guard let time = highTempTime else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: time)
    }
    
    var formattedLowTime: String {
        guard let time = lowTempTime else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: time)
    }
    
    var isReliable: Bool {
        return isFromHistoricalData && dataPointCount >= 2
    }
    
    var confidenceDescription: String {
        if isFromHistoricalData {
            switch dataPointCount {
            case 0...1: return "Limited data"
            case 2...5: return "Based on \(dataPointCount) readings"
            case 6...12: return "Good data coverage"
            default: return "Excellent data coverage"
            }
        } else {
            return "Estimated from current conditions"
        }
    }
}

struct DailyHumidityStats {
    let highHumidity: Double
    let lowHumidity: Double
    let highHumidityTime: Date?
    let lowHumidityTime: Date?
    let unit: String
    let dataPointCount: Int
    let isFromHistoricalData: Bool
    
    var formattedHigh: String {
        String(format: "%.0f", highHumidity) + unit
    }
    
    var formattedLow: String {
        String(format: "%.0f", lowHumidity) + unit
    }
    
    var formattedHighTime: String {
        guard let time = highHumidityTime else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: time)
    }
    
    var formattedLowTime: String {
        guard let time = lowHumidityTime else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: time)
    }
    
    var isReliable: Bool {
        return isFromHistoricalData && dataPointCount >= 2
    }
    
    var confidenceDescription: String {
        if isFromHistoricalData {
            switch dataPointCount {
            case 0...1: return "Limited data"
            case 2...5: return "Based on \(dataPointCount) readings"
            case 6...12: return "Good data coverage"
            default: return "Excellent data coverage"
            }
        } else {
            return "Estimated from current conditions"
        }
    }
}

struct DailyWindStats {
    let maxWindSpeed: Double
    let maxWindGust: Double
    let maxWindSpeedTime: Date?
    let maxWindGustTime: Date?
    let unit: String
    let dataPointCount: Int
    let isFromHistoricalData: Bool
    
    var formattedMaxSpeed: String {
        MeasurementConverter.formatWindSpeed(String(format: "%.1f", maxWindSpeed), originalUnit: unit)
    }
    
    var formattedMaxGust: String {
        MeasurementConverter.formatWindSpeed(String(format: "%.1f", maxWindGust), originalUnit: unit)
    }
    
    var formattedMaxSpeedTime: String {
        guard let time = maxWindSpeedTime else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: time)
    }
    
    var formattedMaxGustTime: String {
        guard let time = maxWindGustTime else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: time)
    }
    
    var isReliable: Bool {
        return isFromHistoricalData && dataPointCount >= 2
    }
    
    var confidenceDescription: String {
        if isFromHistoricalData {
            switch dataPointCount {
            case 0...1: return "Limited data"
            case 2...5: return "Based on \(dataPointCount) readings"
            case 6...12: return "Good data coverage"
            default: return "Excellent data coverage"
            }
        } else {
            return "Estimated from current conditions"
        }
    }
}

struct LastLightningStats {
    let lastDetectionTime: Date?
    let isFromHistoricalData: Bool
    let searchedDaysBack: Int
    
    var formattedLastDetection: String {
        guard let lastTime = lastDetectionTime else {
            return "No recent lightning detected"
        }
        
        return formatTimeAgo(from: lastTime)
    }
    
    var confidenceDescription: String {
        if isFromHistoricalData {
            if searchedDaysBack >= 7 {
                return "Searched last \(searchedDaysBack) days"
            } else {
                return "Searched today only"
            }
        } else {
            return "Based on current data only"
        }
    }
    
    private func formatTimeAgo(from date: Date) -> String {
        let now = Date()
        let timeInterval = now.timeIntervalSince(date)
        
        let minutes = Int(timeInterval / 60)
        let hours = Int(timeInterval / 3600)
        let days = Int(timeInterval / 86400)
        
        if days > 0 {
            return days == 1 ? "1 Day Ago" : "\(days) Days Ago"
        } else if hours > 0 {
            return hours == 1 ? "1 Hour Ago" : "\(hours) Hours Ago"
        } else if minutes > 0 {
            return minutes == 1 ? "1 Minute Ago" : "\(minutes) Minutes Ago"
        } else {
            return "Just Now"
        }
    }
}

class DailyTemperatureCalculator {
    
    // MARK: - Temperature Calculations
    
    static func calculateDailyStats(from historicalData: HistoricalOutdoorData?, for date: Date = Date(), timeZone: TimeZone = .current) -> DailyTemperatureStats? {
        guard let temperatureData = historicalData?.temperature else {
            return nil
        }
        
        let unit = temperatureData.unit
        var tempReadings: [(temp: Double, time: Date)] = []
        
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: date)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: targetDay) ?? targetDay
        
        for (timestampString, valueString) in temperatureData.list {
            guard let timestamp = Double(timestampString),
                  let temperature = Double(valueString) else {
                continue
            }
            
            let readingDate = Date(timeIntervalSince1970: timestamp)
            
            if readingDate >= targetDay && readingDate < nextDay {
                tempReadings.append((temp: temperature, time: readingDate))
            }
        }
        
        guard !tempReadings.isEmpty else {
            return nil
        }
        
        let sortedByTemp = tempReadings.sorted { $0.temp < $1.temp }
        let lowestReading = sortedByTemp.first!
        let highestReading = sortedByTemp.last!
        
        return DailyTemperatureStats(
            highTemp: highestReading.temp,
            lowTemp: lowestReading.temp,
            highTempTime: highestReading.time,
            lowTempTime: lowestReading.time,
            unit: unit,
            dataPointCount: tempReadings.count,
            isFromHistoricalData: true
        )
    }
    
    static func calculateIndoorDailyStats(from historicalData: HistoricalIndoorData?, for date: Date = Date(), timeZone: TimeZone = .current) -> DailyTemperatureStats? {
        guard let temperatureData = historicalData?.temperature else {
            return nil
        }
        
        let unit = temperatureData.unit
        var tempReadings: [(temp: Double, time: Date)] = []
        
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: date)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: targetDay) ?? targetDay
        
        for (timestampString, valueString) in temperatureData.list {
            guard let timestamp = Double(timestampString),
                  let temperature = Double(valueString) else {
                continue
            }
            
            let readingDate = Date(timeIntervalSince1970: timestamp)
            
            if readingDate >= targetDay && readingDate < nextDay {
                tempReadings.append((temp: temperature, time: readingDate))
            }
        }
        
        guard !tempReadings.isEmpty else {
            return nil
        }
        
        let sortedByTemp = tempReadings.sorted { $0.temp < $1.temp }
        let lowestReading = sortedByTemp.first!
        let highestReading = sortedByTemp.last!
        
        return DailyTemperatureStats(
            highTemp: highestReading.temp,
            lowTemp: lowestReading.temp,
            highTempTime: highestReading.time,
            lowTempTime: lowestReading.time,
            unit: unit,
            dataPointCount: tempReadings.count,
            isFromHistoricalData: true
        )
    }
    
    static func estimateFromCurrentData(currentTemp: String, unit: String, station: WeatherStation) -> DailyTemperatureStats? {
        guard let temp = Double(currentTemp) else { return nil }
        
        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: now) ?? 180
        
        let dailyRange = estimateDailyRange(dayOfYear: dayOfYear)
        
        if hour >= 4 && hour <= 8 {
            let estimatedHigh = temp + dailyRange
            return DailyTemperatureStats(
                highTemp: estimatedHigh,
                lowTemp: temp,
                highTempTime: nil,
                lowTempTime: now,
                unit: unit,
                dataPointCount: 1,
                isFromHistoricalData: false
            )
        }
        
        if hour >= 11 && hour <= 17 {
            let estimatedLow = temp - dailyRange
            return DailyTemperatureStats(
                highTemp: temp,
                lowTemp: estimatedLow,
                highTempTime: now,
                lowTempTime: nil,
                unit: unit,
                dataPointCount: 1,
                isFromHistoricalData: false
            )
        }
        
        let timePositionFactor = sin(Double(hour - 6) * .pi / 12)
        let currentPositionInRange = max(0, min(1, (timePositionFactor + 1) / 2))
        
        let estimatedHigh = temp + (dailyRange * (1 - currentPositionInRange))
        let estimatedLow = temp - (dailyRange * currentPositionInRange)
        
        return DailyTemperatureStats(
            highTemp: estimatedHigh,
            lowTemp: estimatedLow,
            highTempTime: nil,
            lowTempTime: nil,
            unit: unit,
            dataPointCount: 1,
            isFromHistoricalData: false
        )
    }
    
    // MARK: - Humidity Calculations
    
    static func calculateDailyHumidityStats(from historicalData: HistoricalOutdoorData?, for date: Date = Date(), timeZone: TimeZone = .current) -> DailyHumidityStats? {
        guard let humidityData = historicalData?.humidity else {
            return nil
        }
        
        let unit = humidityData.unit
        var humidityReadings: [(humidity: Double, time: Date)] = []
        
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: date)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: targetDay) ?? targetDay
        
        for (timestampString, valueString) in humidityData.list {
            guard let timestamp = Double(timestampString),
                  let humidity = Double(valueString) else {
                continue
            }
            
            let readingDate = Date(timeIntervalSince1970: timestamp)
            
            if readingDate >= targetDay && readingDate < nextDay {
                humidityReadings.append((humidity: humidity, time: readingDate))
            }
        }
        
        guard !humidityReadings.isEmpty else {
            return nil
        }
        
        let sortedByHumidity = humidityReadings.sorted { $0.humidity < $1.humidity }
        let lowestReading = sortedByHumidity.first!
        let highestReading = sortedByHumidity.last!
        
        return DailyHumidityStats(
            highHumidity: highestReading.humidity,
            lowHumidity: lowestReading.humidity,
            highHumidityTime: highestReading.time,
            lowHumidityTime: lowestReading.time,
            unit: unit,
            dataPointCount: humidityReadings.count,
            isFromHistoricalData: true
        )
    }
    
    static func calculateIndoorDailyHumidityStats(from historicalData: HistoricalIndoorData?, for date: Date = Date(), timeZone: TimeZone = .current) -> DailyHumidityStats? {
        guard let humidityData = historicalData?.humidity else {
            return nil
        }
        
        let unit = humidityData.unit
        var humidityReadings: [(humidity: Double, time: Date)] = []
        
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: date)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: targetDay) ?? targetDay
        
        for (timestampString, valueString) in humidityData.list {
            guard let timestamp = Double(timestampString),
                  let humidity = Double(valueString) else {
                continue
            }
            
            let readingDate = Date(timeIntervalSince1970: timestamp)
            
            if readingDate >= targetDay && readingDate < nextDay {
                humidityReadings.append((humidity: humidity, time: readingDate))
            }
        }
        
        guard !humidityReadings.isEmpty else {
            return nil
        }
        
        let sortedByHumidity = humidityReadings.sorted { $0.humidity < $1.humidity }
        let lowestReading = sortedByHumidity.first!
        let highestReading = sortedByHumidity.last!
        
        return DailyHumidityStats(
            highHumidity: highestReading.humidity,
            lowHumidity: lowestReading.humidity,
            highHumidityTime: highestReading.time,
            lowHumidityTime: lowestReading.time,
            unit: unit,
            dataPointCount: humidityReadings.count,
            isFromHistoricalData: true
        )
    }
    
    static func estimateHumidityFromCurrentData(currentHumidity: String, unit: String, station: WeatherStation) -> DailyHumidityStats? {
        guard let humidity = Double(currentHumidity) else { return nil }
        
        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)
        
        if hour >= 4 && hour <= 8 {
            let estimatedLow = max(humidity - 25, 20)
            return DailyHumidityStats(
                highHumidity: humidity,
                lowHumidity: estimatedLow,
                highHumidityTime: now,
                lowHumidityTime: nil,
                unit: unit,
                dataPointCount: 1,
                isFromHistoricalData: false
            )
        }
        
        if hour >= 14 && hour <= 18 {
            let estimatedHigh = min(humidity + 25, 100)
            return DailyHumidityStats(
                highHumidity: estimatedHigh,
                lowHumidity: humidity,
                highHumidityTime: nil,
                lowHumidityTime: now,
                unit: unit,
                dataPointCount: 1,
                isFromHistoricalData: false
            )
        }
        
        let dailyRange = 25.0
        let estimatedHigh = min(humidity + dailyRange/2, 100)
        let estimatedLow = max(humidity - dailyRange/2, 20)
        
        return DailyHumidityStats(
            highHumidity: estimatedHigh,
            lowHumidity: estimatedLow,
            highHumidityTime: nil,
            lowHumidityTime: nil,
            unit: unit,
            dataPointCount: 1,
            isFromHistoricalData: false
        )
    }
    
    // MARK: - Wind Calculations
    
    static func calculateDailyWindStats(from historicalData: HistoricalWeatherData?, for date: Date = Date(), timeZone: TimeZone = .current) -> DailyWindStats? {
        guard let windData = historicalData?.wind else {
            return nil
        }
        
        let windSpeedUnit = windData.windSpeed?.unit ?? "mph"
        _ = windData.windGust?.unit ?? "mph" // Acknowledge but don't use windGustUnit
        
        var windSpeedReadings: [(speed: Double, time: Date)] = []
        var windGustReadings: [(gust: Double, time: Date)] = []
        
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: date)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: targetDay) ?? targetDay
        
        // Process wind speed readings
        if let windSpeedData = windData.windSpeed {
            for (timestampString, valueString) in windSpeedData.list {
                guard let timestamp = Double(timestampString),
                      let windSpeed = Double(valueString) else {
                    continue
                }
                
                let readingDate = Date(timeIntervalSince1970: timestamp)
                
                if readingDate >= targetDay && readingDate < nextDay {
                    windSpeedReadings.append((speed: windSpeed, time: readingDate))
                }
            }
        }
        
        // Process wind gust readings
        if let windGustData = windData.windGust {
            for (timestampString, valueString) in windGustData.list {
                guard let timestamp = Double(timestampString),
                      let windGust = Double(valueString) else {
                    continue
                }
                
                let readingDate = Date(timeIntervalSince1970: timestamp)
                
                if readingDate >= targetDay && readingDate < nextDay {
                    windGustReadings.append((gust: windGust, time: readingDate))
                }
            }
        }
        
        guard !windSpeedReadings.isEmpty || !windGustReadings.isEmpty else {
            return nil
        }
        
        // Find maximum wind speed
        let maxSpeedReading = windSpeedReadings.max { $0.speed < $1.speed }
        let maxGustReading = windGustReadings.max { $0.gust < $1.gust }
        
        let maxWindSpeed = maxSpeedReading?.speed ?? 0
        let maxWindGust = maxGustReading?.gust ?? 0
        let maxWindSpeedTime = maxSpeedReading?.time
        let maxWindGustTime = maxGustReading?.time
        
        // Use the more common unit (prefer wind speed unit over gust unit)
        let unit = windSpeedUnit
        
        return DailyWindStats(
            maxWindSpeed: maxWindSpeed,
            maxWindGust: maxWindGust,
            maxWindSpeedTime: maxWindSpeedTime,
            maxWindGustTime: maxWindGustTime,
            unit: unit,
            dataPointCount: windSpeedReadings.count + windGustReadings.count,
            isFromHistoricalData: true
        )
    }
    
    static func estimateWindFromCurrentData(currentWindSpeed: String, currentWindGust: String, unit: String, station: WeatherStation) -> DailyWindStats? {
        guard let windSpeed = Double(currentWindSpeed),
              let windGust = Double(currentWindGust) else { return nil }
        
        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)
        
        // Estimate daily max based on time of day
        // Wind typically picks up during the day and calms at night
        let dailyWindFactor: Double
        if hour >= 6 && hour <= 18 {
            // During the day, current readings might be close to daily max
            dailyWindFactor = 1.2
        } else {
            // At night, winds are typically calmer, so daily max might be higher
            dailyWindFactor = 1.8
        }
        
        let estimatedMaxSpeed = max(windSpeed * dailyWindFactor, windSpeed)
        let estimatedMaxGust = max(windGust * dailyWindFactor, windGust)
        
        return DailyWindStats(
            maxWindSpeed: estimatedMaxSpeed,
            maxWindGust: estimatedMaxGust,
            maxWindSpeedTime: nil,
            maxWindGustTime: nil,
            unit: unit,
            dataPointCount: 1,
            isFromHistoricalData: false
        )
    }
    
    // MARK: - Lightning Calculations
    
    static func calculateLastLightningDetection(from historicalData: HistoricalWeatherData?, currentLightningCount: String, daysToSearch: Int = 7) -> LastLightningStats? {
        // First, check if there's any current lightning activity
        if let currentCount = Int(currentLightningCount), currentCount > 0 {
            // Lightning detected recently (within current reading period)
            return LastLightningStats(
                lastDetectionTime: Date(), // Very recent
                isFromHistoricalData: false,
                searchedDaysBack: 0
            )
        }
        
        // Search historical lightning data
        guard let lightningData = historicalData?.lightning,
              let countData = lightningData.count else {
            return LastLightningStats(
                lastDetectionTime: nil,
                isFromHistoricalData: false,
                searchedDaysBack: 0
            )
        }
        
        let calendar = Calendar.current
        let now = Date()
        let searchStartDate = calendar.date(byAdding: .day, value: -daysToSearch, to: now) ?? now
        
        var mostRecentLightningTime: Date?
        var actualDaysSearched = 0
        
        // Sort lightning count readings by timestamp (most recent first)
        let sortedReadings = countData.list.compactMap { (timestampString, countString) -> (Date, Int)? in
            guard let timestamp = Double(timestampString),
                  let count = Int(countString) else {
                return nil
            }
            
            let readingDate = Date(timeIntervalSince1970: timestamp)
            
            // Only consider readings within our search window
            guard readingDate >= searchStartDate && readingDate <= now else {
                return nil
            }
            
            return (readingDate, count)
        }.sorted { $0.0 > $1.0 } // Sort by date, most recent first
        
        if !sortedReadings.isEmpty {
            let oldestReading = sortedReadings.last!.0
            let daysDifference = calendar.dateComponents([.day], from: oldestReading, to: now).day ?? 0
            actualDaysSearched = min(daysToSearch, daysDifference + 1)
        }
        
        // Look for the most recent non-zero lightning count
        // Lightning count represents cumulative count, so we need to find when it last increased
        var previousCount: Int?
        
        for (readingDate, count) in sortedReadings {
            if let prevCount = previousCount {
                // If current count is higher than previous count, lightning was detected at this time
                if count > prevCount {
                    mostRecentLightningTime = readingDate
                    break
                }
            }
            previousCount = count
        }
        
        // If we didn't find an increase, but we have a non-zero count in our search period,
        // lightning was detected before our search window
        if mostRecentLightningTime == nil {
            for (_, count) in sortedReadings {
                if count > 0 {
                    // Lightning was detected, but before our search window
                    // Set the time to the beginning of our search window as a conservative estimate
                    mostRecentLightningTime = searchStartDate
                    break
                }
            }
        }
        
        return LastLightningStats(
            lastDetectionTime: mostRecentLightningTime,
            isFromHistoricalData: true,
            searchedDaysBack: actualDaysSearched
        )
    }
    
    // MARK: - Helper Methods
    
    private static func estimateDailyRange(dayOfYear: Int) -> Double {
        let seasonalFactor = sin(Double(dayOfYear - 80) * 2 * .pi / 365)
        return 12.0 + (seasonalFactor * 8.0)
    }
    
    // MARK: - Public API
    
    static func getDailyStats(weatherData: WeatherStationData, historicalData: HistoricalWeatherData?, station: WeatherStation, for date: Date = Date()) -> DailyTemperatureStats? {
        if let historical = historicalData,
           let stats = calculateDailyStats(from: historical.outdoor, for: date, timeZone: station.timeZone) {
            return stats
        }
        
        return estimateFromCurrentData(
            currentTemp: weatherData.outdoor.temperature.value,
            unit: weatherData.outdoor.temperature.unit,
            station: station
        )
    }
    
    static func getDailyHumidityStats(weatherData: WeatherStationData, historicalData: HistoricalWeatherData?, station: WeatherStation, for date: Date = Date()) -> DailyHumidityStats? {
        if let historical = historicalData,
           let stats = calculateDailyHumidityStats(from: historical.outdoor, for: date, timeZone: station.timeZone) {
            return stats
        }
        
        return estimateHumidityFromCurrentData(
            currentHumidity: weatherData.outdoor.humidity.value,
            unit: weatherData.outdoor.humidity.unit,
            station: station
        )
    }
    
    static func getDailyWindStats(weatherData: WeatherStationData, historicalData: HistoricalWeatherData?, station: WeatherStation, for date: Date = Date()) -> DailyWindStats? {
        if let historical = historicalData,
           let stats = calculateDailyWindStats(from: historical, for: date, timeZone: station.timeZone) {
            return stats
        }
        
        return estimateWindFromCurrentData(
            currentWindSpeed: weatherData.wind.windSpeed.value,
            currentWindGust: weatherData.wind.windGust.value,
            unit: weatherData.wind.windSpeed.unit,
            station: station
        )
    }
    
    static func getLastLightningStats(weatherData: WeatherStationData, historicalData: HistoricalWeatherData?, station: WeatherStation, daysToSearch: Int = 7) -> LastLightningStats? {
        return calculateLastLightningDetection(
            from: historicalData,
            currentLightningCount: weatherData.lightning.count.value,
            daysToSearch: daysToSearch
        )
    }
    
    // MARK: - Indoor Temperature Stats
    
    static func getIndoorDailyStats(weatherData: WeatherStationData, historicalData: HistoricalWeatherData?, station: WeatherStation, for date: Date = Date()) -> DailyTemperatureStats? {
        if let historical = historicalData,
           let stats = calculateIndoorDailyStats(from: historical.indoor, for: date, timeZone: station.timeZone) {
            return stats
        }
        
        return estimateFromCurrentData(
            currentTemp: weatherData.indoor.temperature.value,
            unit: weatherData.indoor.temperature.unit,
            station: station
        )
    }
    
    static func getIndoorDailyHumidityStats(weatherData: WeatherStationData, historicalData: HistoricalWeatherData?, station: WeatherStation, for date: Date = Date()) -> DailyHumidityStats? {
        if let historical = historicalData,
           let stats = calculateIndoorDailyHumidityStats(from: historical.indoor, for: date, timeZone: station.timeZone) {
            return stats
        }
        
        return estimateHumidityFromCurrentData(
            currentHumidity: weatherData.indoor.humidity.value,
            unit: weatherData.indoor.humidity.unit,
            station: station
        )
    }
    
    // MARK: - Channel Temperature Stats (Estimated only, no historical data available)
    
    static func getTempHumidityCh1DailyStats(weatherData: WeatherStationData, historicalData: HistoricalWeatherData?, station: WeatherStation, for date: Date = Date()) -> DailyTemperatureStats? {
        // Note: Channel sensors typically don't have historical data in the API
        // So we'll estimate based on current conditions
        return estimateFromCurrentData(
            currentTemp: weatherData.tempAndHumidityCh1.temperature.value,
            unit: weatherData.tempAndHumidityCh1.temperature.unit,
            station: station
        )
    }
    
    static func getTempHumidityCh1DailyHumidityStats(weatherData: WeatherStationData, historicalData: HistoricalWeatherData?, station: WeatherStation, for date: Date = Date()) -> DailyHumidityStats? {
        // Note: Channel sensors typically don't have historical data in the API
        // So we'll estimate based on current conditions
        if let humidity = weatherData.tempAndHumidityCh1.humidity {
            return estimateHumidityFromCurrentData(
                currentHumidity: humidity.value,
                unit: humidity.unit,
                station: station
            )
        }
        
        return nil
    }
    
    static func getTempHumidityCh2DailyStats(weatherData: WeatherStationData, historicalData: HistoricalWeatherData?, station: WeatherStation, for date: Date = Date()) -> DailyTemperatureStats? {
        // Note: Channel sensors typically don't have historical data in the API
        // So we'll estimate based on current conditions
        return estimateFromCurrentData(
            currentTemp: weatherData.tempAndHumidityCh2.temperature.value,
            unit: weatherData.tempAndHumidityCh2.temperature.unit,
            station: station
        )
    }
    
    static func getTempHumidityCh2DailyHumidityStats(weatherData: WeatherStationData, historicalData: HistoricalWeatherData?, station: WeatherStation, for date: Date = Date()) -> DailyHumidityStats? {
        // Note: Channel sensors typically don't have historical data in the API
        // So we'll estimate based on current conditions
        if let humidity = weatherData.tempAndHumidityCh2.humidity {
            return estimateHumidityFromCurrentData(
                currentHumidity: humidity.value,
                unit: humidity.unit,
                station: station
            )
        }
        
        return nil
    }
    
    static func getTempHumidityCh3DailyStats(weatherData: WeatherStationData, historicalData: HistoricalWeatherData?, station: WeatherStation, for date: Date = Date()) -> DailyTemperatureStats? {
        // Note: Channel sensors typically don't have historical data in the API
        // So we'll estimate based on current conditions
        if let tempHumCh3 = weatherData.tempAndHumidityCh3 {
            return estimateFromCurrentData(
                currentTemp: tempHumCh3.temperature.value,
                unit: tempHumCh3.temperature.unit,
                station: station
            )
        }
        
        return nil
    }
    
    static func getTempHumidityCh3DailyHumidityStats(weatherData: WeatherStationData, historicalData: HistoricalWeatherData?, station: WeatherStation, for date: Date = Date()) -> DailyHumidityStats? {
        // Note: Channel sensors typically don't have historical data in the API
        // So we'll estimate based on current conditions
        if let tempHumCh3 = weatherData.tempAndHumidityCh3,
           let humidity = tempHumCh3.humidity {
            return estimateHumidityFromCurrentData(
                currentHumidity: humidity.value,
                unit: humidity.unit,
                station: station
            )
        }
        
        return nil
    }
}