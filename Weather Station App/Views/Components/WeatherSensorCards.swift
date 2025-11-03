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
    
    // Get today's forecast SF symbol
    private func getTodaysForecastIcon() -> String {
        guard let forecast = WeatherForecastService.shared.getForecast(for: station) else {
            return "sun.max.fill" // Default fallback
        }
        
        // Find today's forecast
        if let todaysForecast = forecast.dailyForecasts.first(where: { $0.isToday }) {
            return todaysForecast.weatherIcon
        }
        
        // Fallback to first available forecast
        return forecast.dailyForecasts.first?.weatherIcon ?? "sun.max.fill"
    }
    
    // Get today's forecast description
    private func getTodaysForecastDescription() -> String {
        guard let forecast = WeatherForecastService.shared.getForecast(for: station) else {
            return "Clear sky" // Default fallback
        }
        
        // Find today's forecast
        if let todaysForecast = forecast.dailyForecasts.first(where: { $0.isToday }) {
            return todaysForecast.weatherDescription
        }
        
        // Fallback to first available forecast
        return forecast.dailyForecasts.first?.weatherDescription ?? "Clear sky"
    }
    
    // Get temperature emoji based on actual temperature value
    private func getTemperatureEmoji(for tempString: String) -> String {
        guard let temp = Double(tempString) else { return "🌡️" }
        
        // Convert to Fahrenheit if needed for consistent emoji logic
        let tempInF = data.outdoor.temperature.unit.lowercased().contains("c") ? 
            (temp * 9/5) + 32 : temp
        
        switch tempInF {
        case ..<20: return "🥶"      // Freezing cold
        case 20..<32: return "❄️"    // Very cold
        case 32..<50: return "🧊"    // Cold
        case 50..<65: return "😊"    // Pleasant
        case 65..<75: return "😌"    // Comfortable
        case 75..<85: return "☀️"    // Warm
        case 85..<95: return "😅"    // Hot
        case 95..<105: return "🔥"   // Very hot
        default: return "🌋"         // Extremely hot
        }
    }
    
    var body: some View {
        EditableWeatherCard(
            title: .constant(station.customLabels.outdoorTemp),
            systemImage: "thermometer",
            onTitleChange: onTitleChange
        ) {
            VStack(alignment: .leading, spacing: 12) {
                // Temperature display with forecast
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Temperature")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(TemperatureConverter.formatTemperature(data.outdoor.temperature.value, originalUnit: data.outdoor.temperature.unit))
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                    }
                    
                    Spacer()
                    
                    // Today's Forecast - centered
                    VStack(alignment: .center, spacing: 4) {
                        Text("Today's Forecast")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Image(systemName: getTodaysForecastIcon())
                            .font(.system(size: 32))
                            .foregroundColor(.blue)
                        Text(getTodaysForecastDescription())
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Feels Like")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(TemperatureConverter.formatTemperature(data.outdoor.feelsLike.value, originalUnit: data.outdoor.feelsLike.unit))
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
                
                // Humidity display
                HStack {
                    Text("Humidity:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(data.outdoor.humidity.value)\(data.outdoor.humidity.unit)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
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

struct ThermometerGauge: View {
    let temperature: Double
    let feelsLike: Double
    
    @State private var animatedLevel: Double = 0.0
    @State private var animatedFeelsLikeLevel: Double = 0.0
    
    private func getTemperatureColor(_ temp: Double) -> Color {
        switch temp {
        case ..<32: return .blue      // Freezing
        case 32..<60: return .cyan    // Cold
        case 60..<75: return .green   // Comfortable
        case 75..<85: return .yellow  // Warm
        case 85..<95: return .orange  // Hot
        default: return .red          // Very hot
        }
    }
    
    // Convert temperature to gauge level (0.0 to 1.0)
    private func temperatureToLevel(_ temp: Double) -> Double {
        let minTemp = 0.0   // Minimum gauge temperature
        let maxTemp = 100.0 // Maximum gauge temperature
        let clampedTemp = max(minTemp, min(maxTemp, temp))
        return (clampedTemp - minTemp) / (maxTemp - minTemp)
    }
    
    var body: some View {
        ZStack {
            // Horizontal glass tube
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 1, y: 1)
            
            // Temperature scale marks (vertical lines for horizontal thermometer)
            HStack {
                ForEach([0, 25, 50, 75, 100], id: \.self) { temp in
                    VStack {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.4))
                            .frame(width: 0.5, height: 4)
                        Spacer()
                        if temp % 50 == 0 { // Only show labels for 0, 50, 100
                            Text("\(temp)°")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        } else {
                            Spacer()
                        }
                    }
                    if temp != 100 {
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            
            // Horizontal mercury column
            HStack {
                ZStack {
                    // Main mercury
                    Rectangle()
                        .fill(getTemperatureColor(temperature))
                        .frame(width: 75 * animatedLevel) // Increased from 60 to 75 for larger frame
                        .frame(height: 10) // Slightly taller mercury column
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                    
                    // Glass reflection on mercury
                    Rectangle()
                        .fill(Color.white.opacity(0.4))
                        .frame(width: 75 * animatedLevel)
                        .frame(height: 2)
                        .clipShape(RoundedRectangle(cornerRadius: 1))
                        .offset(y: -3) // Adjusted offset for taller mercury
                }
                .animation(.easeInOut(duration: 1.2), value: animatedLevel)
                Spacer()
            }
            .padding(.leading, 10) // Slightly more padding for larger size
            
            // Feels-like temperature indicator (vertical line)
            HStack {
                Rectangle()
                    .fill(Color.orange)
                    .frame(width: 2, height: 15) // Taller indicator line
                    .offset(x: 75 * animatedFeelsLikeLevel) // Updated to match new mercury width
                    .animation(.easeInOut(duration: 1.2), value: animatedFeelsLikeLevel)
                Spacer()
            }
            .padding(.leading, 10) // Match the mercury padding
            
            // Thermometer bulb on the left side
            HStack {
                Circle()
                    .fill(getTemperatureColor(temperature))
                    .frame(width: 16, height: 16) // Slightly larger bulb
                    .overlay(
                        Circle()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 4, height: 4) // Larger highlight
                            .offset(x: -2, y: -1)
                    )
                    .padding(.leading, 2)
                Spacer()
            }
        }
        .onAppear {
            updateGauge()
        }
        .onChange(of: temperature) { _, _ in
            updateGauge()
        }
        .onChange(of: feelsLike) { _, _ in
            updateGauge()
        }
    }
    
    private func updateGauge() {
        withAnimation(.easeInOut(duration: 1.2)) {
            animatedLevel = temperatureToLevel(temperature)
            animatedFeelsLikeLevel = temperatureToLevel(feelsLike)
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
                    
                    // Show timestamp if available, regardless of reliability status
                    if tempStats.highTempTime != nil {
                        Text("at \(tempStats.formattedHighTime)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } else if !tempStats.isFromHistoricalData {
                        Text("current reading")
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
                    
                    // Show timestamp if available, regardless of reliability status
                    if tempStats.lowTempTime != nil {
                        Text("at \(tempStats.formattedLowTime)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } else if !tempStats.isFromHistoricalData {
                        Text("current reading")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Data confidence indicator
            HStack {
                Image(systemName: tempStats.isReliable ? "checkmark.circle.fill" : "clock.fill")
                    .foregroundColor(tempStats.isReliable ? .green : .orange)
                    .font(.caption2)
                Text(tempStats.confidenceDescription)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Last update time
                if tempStats.isFromHistoricalData {
                    Text("Updated \(formatLastUpdateTime())")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 4)
            
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
                        
                        // Show timestamp if available
                        if humidityStats.highHumidityTime != nil {
                            Text("at \(humidityStats.formattedHighTime)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        } else if !humidityStats.isFromHistoricalData {
                            Text("current reading")
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
                        
                        // Show timestamp if available
                        if humidityStats.lowHumidityTime != nil {
                            Text("at \(humidityStats.formattedLowTime)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        } else if !humidityStats.isFromHistoricalData {
                            Text("current reading")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }
    
    private func formatLastUpdateTime() -> String {
        // Show the most recent timestamp from high or low
        let times = [tempStats.highTempTime, tempStats.lowTempTime].compactMap { $0 }
        
        guard let mostRecent = times.max() else {
            return "recently"
        }
        
        let now = Date()
        let timeInterval = now.timeIntervalSince(mostRecent)
        let minutes = Int(timeInterval / 60)
        
        if minutes < 1 {
            return "just now"
        } else if minutes < 60 {
            return "\(minutes)m ago"
        } else {
            let hours = Int(timeInterval / 3600)
            if hours < 24 {
                return "\(hours)h ago"
            } else {
                let days = Int(timeInterval / 86400)
                return "\(days)d ago"
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