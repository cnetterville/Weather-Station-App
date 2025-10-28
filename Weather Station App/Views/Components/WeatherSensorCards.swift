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
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                    HStack(spacing: 12) {
                        Text("Feels like \(TemperatureConverter.formatTemperature(data.outdoor.feelsLike.value, originalUnit: data.outdoor.feelsLike.unit))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        // Outdoor Humidity
                        HStack(spacing: 4) {
                            Text("Humidity")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
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

struct TemperatureRangeArc: View {
    let currentTemp: Double
    let tempStats: DailyTemperatureStats
    let unit: String
    
    private var temperatureRange: (min: Double, max: Double) {
        // Use a comfortable display range around the daily high/low
        let buffer = max(5.0, (tempStats.highTemp - tempStats.lowTemp) * 0.2) // At least 5° buffer
        return (
            min: tempStats.lowTemp - buffer,
            max: tempStats.highTemp + buffer
        )
    }
    
    private var currentPosition: CGFloat {
        let range = temperatureRange
        let totalRange = range.max - range.min
        guard totalRange > 0 else { return 0.5 }
        
        let position = (currentTemp - range.min) / totalRange
        return CGFloat(max(0, min(1, position))) // Clamp between 0 and 1
    }
    
    private var lowPosition: CGFloat {
        let range = temperatureRange
        let totalRange = range.max - range.min
        guard totalRange > 0 else { return 0.2 }
        
        let position = (tempStats.lowTemp - range.min) / totalRange
        return CGFloat(max(0, min(1, position)))
    }
    
    private var highPosition: CGFloat {
        let range = temperatureRange
        let totalRange = range.max - range.min
        guard totalRange > 0 else { return 0.8 }
        
        let position = (tempStats.highTemp - range.min) / totalRange
        return CGFloat(max(0, min(1, position)))
    }
    
    private var currentTempColor: Color {
        let normalizedTemp = (currentTemp - tempStats.lowTemp) / max(1, tempStats.highTemp - tempStats.lowTemp)
        
        switch normalizedTemp {
        case ...0.2: return .blue
        case 0.2...0.4: return .cyan
        case 0.4...0.6: return .green
        case 0.6...0.8: return .orange
        default: return .red
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let arcHeight = height * 0.7
            
            ZStack {
                // Background arc representing the temperature range
                Path { path in
                    path.move(to: CGPoint(x: 0, y: height))
                    path.addQuadCurve(
                        to: CGPoint(x: width, y: height),
                        control: CGPoint(x: width / 2, y: height - arcHeight)
                    )
                }
                .stroke(Color.secondary.opacity(0.3), lineWidth: 6)
                
                // Temperature range arc (low to high)
                Path { path in
                    path.move(to: CGPoint(x: width * lowPosition, y: height))
                    
                    let startX = width * lowPosition
                    let endX = width * highPosition
                    let controlX = (startX + endX) / 2
                    let controlY = height - (arcHeight * sin(.pi * ((lowPosition + highPosition) / 2)))
                    
                    path.addQuadCurve(
                        to: CGPoint(x: endX, y: height),
                        control: CGPoint(x: controlX, y: controlY)
                    )
                }
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [.blue, .cyan, .green, .orange, .red]),
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 6
                )
                
                // Low temperature marker
                let lowX = width * lowPosition
                let lowY = height - (arcHeight * sin(.pi * lowPosition))
                
                TemperatureMarker(
                    temperature: tempStats.formattedLow,
                    color: .blue,
                    isLow: true
                )
                .position(x: lowX, y: lowY - 15)
                
                // High temperature marker
                let highX = width * highPosition
                let highY = height - (arcHeight * sin(.pi * highPosition))
                
                TemperatureMarker(
                    temperature: tempStats.formattedHigh,
                    color: .red,
                    isLow: false
                )
                .position(x: highX, y: highY - 15)
                
                // Current temperature indicator
                let currentX = width * currentPosition
                let currentY = height - (arcHeight * sin(.pi * currentPosition))
                
                Circle()
                    .fill(currentTempColor)
                    .frame(width: 12, height: 12)
                    .position(x: currentX, y: currentY)
                    .shadow(color: currentTempColor.opacity(0.6), radius: 3)
                    .overlay(
                        Circle()
                            .stroke(.white, lineWidth: 2)
                            .frame(width: 12, height: 12)
                            .position(x: currentX, y: currentY)
                    )
                
                // Current temperature label
                Text(TemperatureConverter.formatTemperature(String(currentTemp), originalUnit: unit))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(currentTempColor)
                    .position(x: currentX, y: currentY - 20)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.background)
                            .opacity(0.8)
                            .padding(.horizontal, -4)
                            .padding(.vertical, -2)
                    )
                
                // Range indicators
                HStack {
                    VStack(spacing: 2) {
                        Text("Low")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(String(format: "%.0f°", temperatureRange.min))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .position(x: 30, y: height + 15)
                    
                    Spacer()
                    
                    VStack(spacing: 2) {
                        Text("High")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(String(format: "%.0f°", temperatureRange.max))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .position(x: width - 30, y: height + 15)
                }
            }
        }
    }
}

struct TemperatureMarker: View {
    let temperature: String
    let color: Color
    let isLow: Bool
    
    var body: some View {
        VStack(spacing: 2) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .stroke(.white, lineWidth: 1)
                )
            
            Text(temperature)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(color)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.background)
                        .opacity(0.8)
                        .padding(.horizontal, -2)
                        .padding(.vertical, -1)
                )
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
                        .font(.system(size: 32, weight: .bold, design: .rounded))
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