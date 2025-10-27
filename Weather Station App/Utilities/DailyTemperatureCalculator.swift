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