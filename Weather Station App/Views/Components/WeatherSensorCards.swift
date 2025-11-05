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
            return WeatherIconHelper.adaptIconForTimeOfDay("sun.max.fill", station: station)
        }
        
        // Find today's forecast
        if let todaysForecast = forecast.dailyForecasts.first(where: { $0.isToday }) {
            let baseIcon = todaysForecast.weatherIcon
            return WeatherIconHelper.adaptIconForTimeOfDay(baseIcon, station: station)
        }
        
        // Fallback to first available forecast
        let baseIcon = forecast.dailyForecasts.first?.weatherIcon ?? "sun.max.fill"
        return WeatherIconHelper.adaptIconForTimeOfDay(baseIcon, station: station)
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
    
    // Get today's precipitation probability
    private func getTodaysPrecipitationProbability() -> Int? {
        guard let forecast = WeatherForecastService.shared.getForecast(for: station) else {
            return nil
        }
        
        // Find today's forecast
        if let todaysForecast = forecast.dailyForecasts.first(where: { $0.isToday }) {
            return todaysForecast.precipitationProbability > 0 ? todaysForecast.precipitationProbability : nil
        }
        
        // Fallback to first available forecast
        if let firstForecast = forecast.dailyForecasts.first {
            return firstForecast.precipitationProbability > 0 ? firstForecast.precipitationProbability : nil
        }
        
        return nil
    }
    
    // Get today's precipitation amount
    private func getTodaysPrecipitation() -> Double? {
        guard let forecast = WeatherForecastService.shared.getForecast(for: station) else {
            return nil
        }
        
        // Find today's forecast
        if let todaysForecast = forecast.dailyForecasts.first(where: { $0.isToday }) {
            return todaysForecast.precipitation > 0.1 ? todaysForecast.precipitation : nil
        }
        
        // Fallback to first available forecast
        if let firstForecast = forecast.dailyForecasts.first {
            return firstForecast.precipitation > 0.1 ? firstForecast.precipitation : nil
        }
        
        return nil
    }
    
    // Format precipitation amount using the same logic as DailyWeatherForecast
    private func formatPrecipitation(_ precipitation: Double) -> String {
        let displayMode = UserDefaults.standard.unitSystemDisplayMode
        
        switch displayMode {
        case .imperial:
            let inches = precipitation * 0.0393701
            if inches < 0.05 {
                return "0.00in"
            } else {
                return String(format: "%.2fin", inches)
            }
            
        case .metric:
            if precipitation < 0.5 {
                return "0.0mm"
            } else {
                return String(format: "%.1fmm", precipitation)
            }
            
        case .both:
            let inches = precipitation * 0.0393701
            if precipitation < 0.5 && inches < 0.05 {
                return "0.0mm/0.00in"
            } else {
                return String(format: "%.1fmm/%.2fin", precipitation, inches)
            }
        }
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
                        
                        // Precipitation info - amount and/or probability
                        if let precipitation = getTodaysPrecipitation() {
                            // Show both amount and probability if probability > 0
                            HStack(spacing: 2) {
                                Image(systemName: "drop.fill")
                                    .font(.system(size: 8))
                                    .foregroundColor(.blue)
                                Text(formatPrecipitation(precipitation))
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                                
                                if let precipProb = getTodaysPrecipitationProbability() {
                                    Text("(\(precipProb)%)")
                                        .font(.caption2)
                                        .foregroundColor(.blue.opacity(0.8))
                                }
                            }
                            .padding(.top, 2)
                        } else if let precipProb = getTodaysPrecipitationProbability(), precipProb > 20 {
                            // Show only probability if there's a chance but minimal amount
                            HStack(spacing: 2) {
                                Image(systemName: "drop.fill")
                                    .font(.system(size: 8))
                                    .foregroundColor(.blue.opacity(0.7))
                                Text("\(precipProb)%")
                                    .font(.caption2)
                                    .foregroundColor(.blue.opacity(0.7))
                            }
                            .padding(.top, 2)
                        }
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
                // Current Temperature - Main Display with comfort gauge
                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Temperature")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(TemperatureConverter.formatTemperature(data.indoor.temperature.value, originalUnit: data.indoor.temperature.unit))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                        Text("Humidity \(data.indoor.humidity.value)\(data.indoor.humidity.unit)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Indoor Comfort Gauge
                    IndoorComfortGauge(
                        currentTemp: Double(data.indoor.temperature.value) ?? 70.0,
                        unit: data.indoor.temperature.unit
                    )
                    .frame(width: 90, height: 90)
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

struct IndoorComfortGauge: View {
    let currentTemp: Double
    let unit: String
    
    @State private var needleRotation: Double = 0
    @State private var iconScale: Double = 1.0
    
    // Comfort zones (in Fahrenheit, will adjust for Celsius)
    private var comfortZones: [(range: ClosedRange<Double>, color: Color, label: String)] {
        if unit.lowercased().contains("c") {
            return [
                (10.0...16.0, .blue, "Cold"),
                (16.1...20.0, .cyan, "Cool"),
                (20.1...24.0, .green, "Ideal"),
                (24.1...27.0, .yellow, "Warm"),
                (27.1...35.0, .orange, "Hot")
            ]
        } else {
            return [
                (50.0...60.0, .blue, "Cold"),
                (60.1...68.0, .cyan, "Cool"),
                (68.1...75.0, .green, "Ideal"),
                (75.1...80.0, .yellow, "Warm"),
                (80.1...95.0, .orange, "Hot")
            ]
        }
    }
    
    private var currentZone: (range: ClosedRange<Double>, color: Color, label: String) {
        for zone in comfortZones {
            if zone.range.contains(currentTemp) {
                return zone
            }
        }
        // Default to last zone if temp is outside ranges
        if currentTemp < comfortZones.first!.range.lowerBound {
            return comfortZones.first!
        }
        return comfortZones.last!
    }
    
    private var tempRange: (min: Double, max: Double) {
        if unit.lowercased().contains("c") {
            return (10.0, 35.0)
        } else {
            return (50.0, 95.0)
        }
    }
    
    private var normalizedTemp: Double {
        let range = tempRange
        let normalized = (currentTemp - range.min) / (range.max - range.min)
        return max(0, min(1, normalized))
    }
    
    private var needleAngle: Double {
        -90 + (normalizedTemp * 180)
    }
    
    var body: some View {
        ZStack {
            // Outer ring with comfort zone gradient
            Circle()
                .trim(from: 0.25, to: 0.75)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            .blue,
                            .cyan,
                            .green,
                            .yellow,
                            .orange
                        ]),
                        center: .center,
                        startAngle: .degrees(180),
                        endAngle: .degrees(360)
                    ),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .frame(width: 70, height: 70)
                .rotationEffect(.degrees(90))
            
            // Inner background circle
            Circle()
                .fill(Color(.windowBackgroundColor))
                .frame(width: 52, height: 52)
            
            // House icon with comfort color
            Image(systemName: "house.fill")
                .font(.system(size: 24))
                .foregroundStyle(
                    LinearGradient(
                        colors: [currentZone.color.opacity(0.8), currentZone.color],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .scaleEffect(iconScale)
                .shadow(color: currentZone.color.opacity(0.3), radius: 2)
            
            // Comfort zone label
            VStack {
                Spacer()
                Text(currentZone.label)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(currentZone.color)
                    .padding(.bottom, 4)
            }
            .frame(height: 90)
        }
        .onAppear {
            animateGauge()
        }
        .onChange(of: currentTemp) { _, _ in
            animateGauge()
        }
    }
    
    private func animateGauge() {
        withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
            needleRotation = needleAngle
        }
        
        // Subtle pulse for icon
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            iconScale = 1.08
        }
    }
}

struct IndoorThermometerView: View {
    let currentTemp: Double
    let unit: String
    let stats: DailyTemperatureStats?
    
    @State private var mercuryLevel: Double = 0.0
    @State private var pulseScale: Double = 1.0
    
    // Temperature range for indoor (typically 50-90°F or equivalent)
    private var tempRange: (min: Double, max: Double) {
        if unit.lowercased().contains("c") {
            return (10.0, 32.0) // Celsius range
        } else {
            return (50.0, 90.0) // Fahrenheit range
        }
    }
    
    private var normalizedTemp: Double {
        let range = tempRange
        let normalized = (currentTemp - range.min) / (range.max - range.min)
        return max(0, min(1, normalized))
    }
    
    private var tempColor: Color {
        switch currentTemp {
        case ..<60: return .blue     // Cold (if in Fahrenheit)
        case 60..<68: return .cyan   // Cool
        case 68..<76: return .green  // Comfortable
        case 76..<82: return .yellow // Warm
        default: return .orange      // Hot
        }
    }
    
    private var comfortIcon: String {
        switch currentTemp {
        case ..<60: return "snowflake"
        case 60..<68: return "wind"
        case 68..<76: return "house.fill"
        case 76..<82: return "flame"
        default: return "flame.fill"
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            
            ZStack {
                // Thermometer background outline
                RoundedRectangle(cornerRadius: 15)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 2)
                    .frame(width: 30, height: height - 20)
                    .position(x: width / 2, y: height / 2)
                
                // Thermometer fill background
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color(.windowBackgroundColor))
                    .frame(width: 26, height: height - 24)
                    .position(x: width / 2, y: height / 2)
                
                // Temperature scale markers
                VStack {
                    ForEach([0.75, 0.5, 0.25], id: \.self) { position in
                        HStack(spacing: 2) {
                            Rectangle()
                                .fill(Color.secondary.opacity(0.4))
                                .frame(width: 6, height: 1)
                            Spacer()
                            Rectangle()
                                .fill(Color.secondary.opacity(0.4))
                                .frame(width: 6, height: 1)
                        }
                        .frame(width: 30)
                        if position != 0.25 {
                            Spacer()
                        }
                    }
                }
                .frame(height: height - 40)
                .position(x: width / 2, y: (height - 20) / 2)
                
                // Mercury column (temperature fill)
                VStack {
                    Spacer()
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [tempColor.opacity(0.8), tempColor],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 22, height: (height - 40) * mercuryLevel)
                        .shadow(color: tempColor.opacity(0.4), radius: 2)
                }
                .frame(height: height - 40)
                .position(x: width / 2, y: (height - 20) / 2 + 5)
                
                // Bulb at bottom
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [tempColor.opacity(0.9), tempColor],
                            center: .center,
                            startRadius: 0,
                            endRadius: 15
                        )
                    )
                    .frame(width: 30, height: 30)
                    .position(x: width / 2, y: height - 10)
                    .shadow(color: tempColor.opacity(0.5), radius: 3)
                
                // Comfort icon inside bulb
                Image(systemName: comfortIcon)
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .scaleEffect(pulseScale)
                    .position(x: width / 2, y: height - 10)
                
                // High/Low markers if available
                if let stats = stats {
                    let highPosition = calculatePosition(for: stats.highTemp)
                    let lowPosition = calculatePosition(for: stats.lowTemp)
                    
                    // High marker
                    HStack(spacing: 2) {
                        Image(systemName: "triangle.fill")
                            .font(.system(size: 6))
                            .foregroundColor(.orange)
                            .rotationEffect(.degrees(90))
                        Spacer()
                    }
                    .frame(width: 40)
                    .position(x: width / 2 + 10, y: (height - 40) * (1 - highPosition) + 20)
                    
                    // Low marker
                    HStack(spacing: 2) {
                        Spacer()
                        Image(systemName: "triangle.fill")
                            .font(.system(size: 6))
                            .foregroundColor(.blue)
                            .rotationEffect(.degrees(-90))
                    }
                    .frame(width: 40)
                    .position(x: width / 2 - 10, y: (height - 40) * (1 - lowPosition) + 20)
                }
            }
        }
        .onAppear {
            animateMercury()
        }
        .onChange(of: currentTemp) { _, _ in
            animateMercury()
        }
    }
    
    private func calculatePosition(for temp: Double) -> Double {
        let range = tempRange
        let normalized = (temp - range.min) / (range.max - range.min)
        return max(0, min(1, normalized))
    }
    
    private func animateMercury() {
        withAnimation(.spring(response: 1.2, dampingFraction: 0.7)) {
            mercuryLevel = normalizedTemp
        }
        
        // Subtle pulse for the comfort icon
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            pulseScale = 1.1
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
                    
                    // Show timestamp if available
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
                    
                    // Show timestamp if available
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
            
            // Data confidence indicator with clearer context
            HStack(spacing: 4) {
                Image(systemName: tempStats.isReliable ? "checkmark.circle.fill" : "clock.fill")
                    .foregroundColor(tempStats.isReliable ? .green : .orange)
                    .font(.caption2)
                
                // Show when the high/low was last recorded
                if tempStats.isFromHistoricalData {
                    Text(getLastRecordedTimeString())
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
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
    
    /// Returns a clearer description of when the high/low was last recorded
    private func getLastRecordedTimeString() -> String {
        // Find the most recent timestamp from high or low
        let times = [tempStats.highTempTime, tempStats.lowTempTime].compactMap { $0 }
        
        guard let mostRecent = times.max() else {
            return "High/low recorded today"
        }
        
        let now = Date()
        let timeInterval = now.timeIntervalSince(mostRecent)
        let minutes = Int(timeInterval / 60)
        
        if minutes < 1 {
            return "High/low just recorded"
        } else if minutes < 60 {
            return "Last high/low \(minutes)m ago"
        } else {
            let hours = Int(timeInterval / 3600)
            if hours < 24 {
                return "Last high/low \(hours)h ago"
            } else {
                let days = Int(timeInterval / 86400)
                return "Last high/low \(days)d ago"
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