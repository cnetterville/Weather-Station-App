//
//  WeatherSensorCards.swift
//  Weather Station App
//
//  Created by Curtis Netterville on 10/25/25.
//

import SwiftUI

struct OutdoorTemperatureCard: View {
    let station: WeatherStation
    let data: WeatherStationData
    let onTitleChange: (String) -> Void
    let getDailyTemperatureStats: () -> DailyTemperatureStats?
    let getDailyHumidityStats: () -> DailyHumidityStats?
    
    var body: some View {
        EditableWeatherCard(
            title: .constant(station.customLabels.outdoorTemp),
            systemImage: "thermometer",
            onTitleChange: onTitleChange
        ) {
            VStack(alignment: .leading, spacing: 12) {
                // Current Temperature - Main Display
                VStack(alignment: .leading, spacing: 4) {
                    Text(TemperatureConverter.formatTemperature(data.outdoor.temperature.value, originalUnit: data.outdoor.temperature.unit))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                    HStack(spacing: 12) {
                        Text("Feels like \(TemperatureConverter.formatTemperature(data.outdoor.feelsLike.value, originalUnit: data.outdoor.feelsLike.unit))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        // Outdoor Humidity
                        HStack(spacing: 4) {
                            Image(systemName: "humidity.fill")
                                .foregroundColor(.blue)
                                .font(.caption)
                            Text("\(data.outdoor.humidity.value)\(data.outdoor.humidity.unit)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Divider()
                
                // Daily High/Low Section - Temperature
                if let tempStats = getDailyTemperatureStats() {
                    DailyHighLowView(
                        tempStats: tempStats,
                        humidityStats: getDailyHumidityStats()
                    )
                } else {
                    // Fallback when no high/low data available
                    HStack {
                        Text("Daily High/Low:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("Loading...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

struct IndoorTemperatureCard: View {
    let station: WeatherStation
    let data: WeatherStationData
    let onTitleChange: (String) -> Void
    let getDailyTemperatureStats: () -> DailyTemperatureStats?
    let getDailyHumidityStats: () -> DailyHumidityStats?
    
    var body: some View {
        EditableWeatherCard(
            title: .constant(station.customLabels.indoorTemp),
            systemImage: "house.fill",
            onTitleChange: onTitleChange
        ) {
            VStack(alignment: .leading, spacing: 12) {
                // Current Temperature - Main Display
                VStack(alignment: .leading, spacing: 4) {
                    Text(TemperatureConverter.formatTemperature(data.indoor.temperature.value, originalUnit: data.indoor.temperature.unit))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                    Text("Humidity \(data.indoor.humidity.value)\(data.indoor.humidity.unit)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // Daily High/Low Section - Temperature
                if let tempStats = getDailyTemperatureStats() {
                    DailyHighLowView(
                        tempStats: tempStats,
                        humidityStats: getDailyHumidityStats()
                    )
                } else {
                    // Fallback when no high/low data available
                    HStack {
                        Text("Daily High/Low:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("Loading...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

struct DailyHighLowView: View {
    let tempStats: DailyTemperatureStats
    let humidityStats: DailyHumidityStats?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Temperature High/Low
            HStack(spacing: 16) {
                // Daily High Temp
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "thermometer.sun.fill")
                            .foregroundColor(.orange)
                            .font(.caption2)
                        Text("High")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text(tempStats.formattedHigh)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.orange)
                    if tempStats.isReliable && tempStats.highTempTime != nil {
                        Text("at \(tempStats.formattedHighTime)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Daily Low Temp
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("Low")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Image(systemName: "thermometer.snowflake")
                            .foregroundColor(.blue)
                            .font(.caption2)
                    }
                    Text(tempStats.formattedLow)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.blue)
                    if tempStats.isReliable && tempStats.lowTempTime != nil {
                        Text("at \(tempStats.formattedLowTime)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Humidity High/Low
            if let humidityStats = humidityStats {
                HStack(spacing: 16) {
                    // Daily High Humidity
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: "humidity.fill")
                                .foregroundColor(.teal)
                                .font(.caption2)
                            Text("High")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Text(humidityStats.formattedHigh)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(.teal)
                        if humidityStats.isReliable && humidityStats.highHumidityTime != nil {
                            Text("at \(humidityStats.formattedHighTime)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Daily Low Humidity
                    VStack(alignment: .trailing, spacing: 2) {
                        HStack(spacing: 4) {
                            Text("Low")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Image(systemName: "humidity")
                                .foregroundColor(.brown)
                                .font(.caption2)
                        }
                        Text(humidityStats.formattedLow)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(.brown)
                        if humidityStats.isReliable && humidityStats.lowHumidityTime != nil {
                            Text("at \(humidityStats.formattedLowTime)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }
}

struct ChannelTemperatureCard: View {
    let station: WeatherStation
    let data: TempHumidityData
    let title: String
    let onTitleChange: (String) -> Void
    let getDailyTemperatureStats: () -> DailyTemperatureStats?
    let getDailyHumidityStats: () -> DailyHumidityStats?
    
    var body: some View {
        EditableWeatherCard(
            title: .constant(title),
            systemImage: "thermometer",
            onTitleChange: onTitleChange
        ) {
            VStack(alignment: .leading, spacing: 12) {
                // Current Temperature - Main Display
                VStack(alignment: .leading, spacing: 4) {
                    Text(TemperatureConverter.formatTemperature(data.temperature.value, originalUnit: data.temperature.unit))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    if let humidity = data.humidity {
                        Text("Humidity: \(humidity.value)\(humidity.unit)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Divider()
                
                // Daily High/Low Section - Temperature
                if let tempStats = getDailyTemperatureStats() {
                    DailyHighLowView(
                        tempStats: tempStats,
                        humidityStats: getDailyHumidityStats()
                    )
                } else {
                    // Fallback when no high/low data available
                    HStack {
                        Text("Daily High/Low:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("Estimated from current")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}