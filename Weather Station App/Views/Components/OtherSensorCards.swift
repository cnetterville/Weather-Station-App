//
//  OtherSensorCards.swift
//  Weather Station App
//
//  Created by Curtis Netterville on 10/25/25.
//

import SwiftUI

struct WindCard: View {
    let station: WeatherStation
    let data: WeatherStationData
    let onTitleChange: (String) -> Void
    let getDailyWindStats: () -> DailyWindStats?
    
    var body: some View {
        EditableWeatherCard(
            title: .constant(station.customLabels.wind),
            systemImage: "wind",
            onTitleChange: onTitleChange
        ) {
            VStack(alignment: .leading, spacing: 12) {
                // Current Wind Speed and Direction with Compass
                HStack {
                    VStack(alignment: .leading) {
                        Text("Speed")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(MeasurementConverter.formatWindSpeed(data.wind.windSpeed.value, originalUnit: data.wind.windSpeed.unit))
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                    }
                    
                    Spacer()
                    
                    // Animated Wind Compass in center
                    WindCompass(
                        direction: Double(data.wind.windDirection.value) ?? 0,
                        speed: Double(data.wind.windSpeed.value) ?? 0
                    )
                    .frame(width: 45, height: 45)
                    
                    Spacer()
                    
                    // Wind Direction with Compass
                    VStack(alignment: .trailing) {
                        Text("Direction")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(MeasurementConverter.formatWindDirectionWithCompass(data.wind.windDirection.value))
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                    }
                }
                
                Divider()
                
                // Daily Wind Maximums Section
                if let windStats = getDailyWindStats() {
                    DailyWindMaximumsView(windStats: windStats)
                    Divider()
                }
                
                // Additional Wind Information
                AdditionalWindInfoView(data: data)
            }
        }
    }
}

struct WindCompass: View {
    let direction: Double // Wind direction in degrees (0-360)
    let speed: Double // Wind speed for animation intensity
    
    @State private var rotationAngle: Double = 0
    @State private var pulseScale: Double = 1.0
    
    var body: some View {
        ZStack {
            // Compass base circle
            Circle()
                .stroke(Color.secondary.opacity(0.3), lineWidth: 1.5)
                .background(
                    Circle()
                        .fill(Color.primary.opacity(0.05))
                )
            
            // Cardinal direction markers
            ForEach([0, 90, 180, 270], id: \.self) { angle in
                Rectangle()
                    .fill(Color.secondary.opacity(0.4))
                    .frame(width: 1, height: 6)
                    .offset(y: -17)
                    .rotationEffect(.degrees(Double(angle)))
            }
            
            // Cardinal direction labels using absolute positioning
            Text("N")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .position(x: 22.5, y: 6)
            
            Text("S")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .position(x: 22.5, y: 39)
                
            Text("W")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .position(x: 6, y: 22.5)
                
            Text("E")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .position(x: 39, y: 22.5)
            
            // Wind direction arrow
            Image(systemName: "location.north.fill")
                .foregroundColor(windArrowColor)
                .font(.system(size: 14, weight: .bold))
                .rotationEffect(.degrees(rotationAngle))
                .scaleEffect(pulseScale)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulseScale)
                .onAppear {
                    updateRotation()
                    startPulseAnimation()
                }
                .onChange(of: direction) { _, _ in
                    updateRotation()
                }
                .onChange(of: speed) { _, _ in
                    startPulseAnimation()
                }
        }
    }
    
    private var windArrowColor: Color {
        switch speed {
        case 0..<5: return .gray
        case 5..<15: return .green  
        case 15..<25: return .yellow
        case 25..<35: return .orange
        default: return .red
        }
    }
    
    private func updateRotation() {
        withAnimation(.easeInOut(duration: 1.0)) {
            rotationAngle = direction
        }
    }
    
    private func startPulseAnimation() {
        // More intense pulse for higher wind speeds
        let intensity = min(speed / 30.0, 1.0) // Normalize to 0-1
        pulseScale = 1.0 + (intensity * 0.3) // Scale between 1.0 and 1.3
        
        // Faster pulse for higher wind speeds
        if speed > 0 {
            withAnimation(.easeInOut(duration: max(0.5, 1.5 - intensity)).repeatForever(autoreverses: true)) {
                pulseScale = 1.0 + (intensity * 0.2)
            }
        }
    }
}

struct DailyWindMaximumsView: View {
    let windStats: DailyWindStats
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Today's Maximum")
                .font(.caption)
                .foregroundColor(.secondary)
                .fontWeight(.semibold)
            
            // Max Wind Speed and Gust
            HStack(spacing: 16) {
                // Daily Max Wind Speed
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "wind")
                            .foregroundColor(.cyan)
                            .font(.caption2)
                        Text("Max Speed")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text(windStats.formattedMaxSpeed)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.cyan)
                    if windStats.isReliable && windStats.maxWindSpeedTime != nil {
                        Text("at \(windStats.formattedMaxSpeedTime)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Daily Max Wind Gust
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("Max Gust")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Image(systemName: "tornado")
                            .foregroundColor(.orange)
                            .font(.caption2)
                    }
                    Text(windStats.formattedMaxGust)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.orange)
                    if windStats.isReliable && windStats.maxWindGustTime != nil {
                        Text("at \(windStats.formattedMaxGustTime)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Confidence indicator for wind data
            if !windStats.isReliable {
                Text(windStats.confidenceDescription)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
    }
}

struct AdditionalWindInfoView: View {
    let data: WeatherStationData
    
    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Current Gusts:")
                    .font(.subheadline)
                Spacer()
                Text(MeasurementConverter.formatWindSpeed(data.wind.windGust.value, originalUnit: data.wind.windGust.unit))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)
            }
            
            HStack {
                Text("10-Min Avg Direction:")
                    .font(.subheadline)
                Spacer()
                Text(MeasurementConverter.formatWindDirectionWithCompass(data.wind.tenMinuteAverageWindDirection.value))
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            
            // Beaufort Scale
            if let windSpeedValue = Double(data.wind.windSpeed.value) {
                // Convert wind speed to MPH for Beaufort Scale calculation
                let convertedSpeeds = MeasurementConverter.convertWindSpeed(data.wind.windSpeed.value, from: data.wind.windSpeed.unit)
                let windSpeedMph = Double(convertedSpeeds.mph) ?? windSpeedValue
                let beaufortScale = WindHelpers.getBeaufortScale(windSpeedMph: windSpeedMph)
                
                HStack {
                    Text("Beaufort Scale:")
                        .font(.subheadline)
                    Spacer()
                    Text("\(beaufortScale.number) - \(beaufortScale.description)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
                .onAppear {
                    // Debug logging
                    print("🌬️ Beaufort Debug:")
                    print("  Original value: \(data.wind.windSpeed.value)")
                    print("  Original unit: \(data.wind.windSpeed.unit)")  
                    print("  Converted MPH: \(convertedSpeeds.mph)")
                    print("  Parsed MPH: \(windSpeedMph)")
                    print("  Beaufort result: \(beaufortScale.number) - \(beaufortScale.description)")
                }
            }
        }
    }
}

struct PressureCard: View {
    let station: WeatherStation
    let data: WeatherStationData
    let onTitleChange: (String) -> Void
    let getDailyPressureStats: () -> DailyPressureStats?
    
    var body: some View {
        EditableWeatherCard(
            title: .constant(station.customLabels.pressure),
            systemImage: "barometer",
            onTitleChange: onTitleChange
        ) {
            VStack(alignment: .leading, spacing: 12) {
                // Current Pressure - Main Display
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(data.pressure.relative.value) \(data.pressure.relative.unit)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Text("Absolute: \(data.pressure.absolute.value) \(data.pressure.absolute.unit)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // Daily High/Low Section - Pressure
                if let pressureStats = getDailyPressureStats() {
                    DailyPressureRangeView(
                        pressureStats: pressureStats,
                        currentPressure: Double(data.pressure.relative.value) ?? 0.0
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

struct DailyPressureRangeView: View {
    let pressureStats: DailyPressureStats
    let currentPressure: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Today's Range")
                .font(.caption)
                .foregroundColor(.secondary)
                .fontWeight(.semibold)
            
            // Pressure High/Low
            HStack(spacing: 16) {
                // Daily High Pressure
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption2)
                        Text("High")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text(pressureStats.formattedHigh)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.green)
                    if pressureStats.isReliable && pressureStats.highPressureTime != nil {
                        Text("at \(pressureStats.formattedHighTime)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Daily Low Pressure
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("Low")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundColor(.red)
                            .font(.caption2)
                    }
                    Text(pressureStats.formattedLow)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.red)
                    if pressureStats.isReliable && pressureStats.lowPressureTime != nil {
                        Text("at \(pressureStats.formattedLowTime)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Pressure trend indicator
            let pressureTrend = PressureHelpers.getPressureTrend(current: currentPressure, stats: pressureStats)
            HStack {
                Image(systemName: pressureTrend.icon)
                    .foregroundColor(pressureTrend.color)
                    .font(.caption)
                Text(pressureTrend.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                if !pressureStats.isReliable {
                    Text(pressureStats.confidenceDescription)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
        }
    }
}

struct RainfallCard: View {
    let station: WeatherStation
    let data: WeatherStationData
    let onTitleChange: (String) -> Void
    
    var body: some View {
        EditableWeatherCard(
            title: .constant(station.customLabels.rainfallPiezo),
            systemImage: "cloud.rain.fill",
            onTitleChange: onTitleChange
        ) {
            let rainfallData = data.rainfallPiezo
            VStack(alignment: .leading, spacing: 8) {
                // Rain Status with Animation - made more prominent
                HStack {
                    Text("Status:")
                    Spacer()
                    HStack(spacing: 6) {
                        Text(WeatherStatusHelpers.rainStatusText(rainfallData.state.value))
                            .fontWeight(.semibold)
                            .foregroundColor(WeatherStatusHelpers.rainStatusColor(rainfallData.state.value))
                        
                        // Rain Animation - made larger and more prominent
                        if rainfallData.state.value == "1" {
                            RainIntensityAnimation(
                                rainRate: Double(rainfallData.rainRate.value) ?? 0.0,
                                isRaining: true
                            )
                            .frame(width: 30, height: 20)
                            .clipped()
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                
                Divider()
                
                RainfallDataView(rainfallData: rainfallData)
            }
            .font(.subheadline)
        }
    }
}

struct RainfallDataView: View {
    let rainfallData: RainfallPiezoData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Today:")
                Spacer()
                Text(MeasurementConverter.formatRainfall(rainfallData.daily.value, originalUnit: rainfallData.daily.unit))
                    .fontWeight(.semibold)
            }
            HStack {
                Text("This Hour:")
                Spacer()
                Text(MeasurementConverter.formatRainfall(rainfallData.oneHour.value, originalUnit: rainfallData.oneHour.unit))
            }
            HStack {
                Text("Rate:")
                Spacer()
                // Removed the rain animation from here
                Text(MeasurementConverter.formatRainRate(rainfallData.rainRate.value, originalUnit: rainfallData.rainRate.unit))
            }
            HStack {
                Text("24 Hours:")
                Spacer()
                Text(MeasurementConverter.formatRainfall(rainfallData.twentyFourHours.value, originalUnit: rainfallData.twentyFourHours.unit))
            }
            HStack {
                Text("Event Total:")
                Spacer()
                Text(MeasurementConverter.formatRainfall(rainfallData.event.value, originalUnit: rainfallData.event.unit))
            }
            HStack {
                Text("Weekly:")
                Spacer()
                Text(MeasurementConverter.formatRainfall(rainfallData.weekly.value, originalUnit: rainfallData.weekly.unit))
            }
            HStack {
                Text("Monthly:")
                Spacer()
                Text(MeasurementConverter.formatRainfall(rainfallData.monthly.value, originalUnit: rainfallData.monthly.unit))
            }
            HStack {
                Text("Yearly:")
                Spacer()
                Text(MeasurementConverter.formatRainfall(rainfallData.yearly.value, originalUnit: rainfallData.yearly.unit))
            }
        }
    }
}

struct TraditionalRainfallCard: View {
    let station: WeatherStation
    let data: WeatherStationData
    let rainfallData: RainfallData
    let onTitleChange: (String) -> Void
    
    var body: some View {
        EditableWeatherCard(
            title: .constant(station.customLabels.rainfall),
            systemImage: "cloud.rain.fill",
            onTitleChange: onTitleChange
        ) {
            VStack(alignment: .leading, spacing: 8) {
                // Traditional Rain Gauge Status (no piezo state detection)
                HStack {
                    Text("Status:")
                    Spacer()
                    Text("Traditional Gauge")
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
                
                Divider()
                
                TraditionalRainfallDataView(rainfallData: rainfallData)
            }
            .font(.subheadline)
        }
    }
}

struct TraditionalRainfallDataView: View {
    let rainfallData: RainfallData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Today:")
                Spacer()
                Text(MeasurementConverter.formatRainfall(rainfallData.daily.value, originalUnit: rainfallData.daily.unit))
                    .fontWeight(.semibold)
            }
            HStack {
                Text("This Hour:")
                Spacer()
                Text(MeasurementConverter.formatRainfall(rainfallData.oneHour.value, originalUnit: rainfallData.oneHour.unit))
            }
            HStack {
                Text("Rate:")
                Spacer()
                Text(MeasurementConverter.formatRainRate(rainfallData.rainRate.value, originalUnit: rainfallData.rainRate.unit))
            }
            HStack {
                Text("24 Hours:")
                Spacer()
                Text(MeasurementConverter.formatRainfall(rainfallData.twentyFourHours.value, originalUnit: rainfallData.twentyFourHours.unit))
            }
            HStack {
                Text("Event Total:")
                Spacer()
                Text(MeasurementConverter.formatRainfall(rainfallData.event.value, originalUnit: rainfallData.event.unit))
            }
            HStack {
                Text("Weekly:")
                Spacer()
                Text(MeasurementConverter.formatRainfall(rainfallData.weekly.value, originalUnit: rainfallData.weekly.unit))
            }
            HStack {
                Text("Monthly:")
                Spacer()
                Text(MeasurementConverter.formatRainfall(rainfallData.monthly.value, originalUnit: rainfallData.monthly.unit))
            }
            HStack {
                Text("Yearly:")
                Spacer()
                Text(MeasurementConverter.formatRainfall(rainfallData.yearly.value, originalUnit: rainfallData.yearly.unit))
            }
        }
    }
}

struct RainIntensityAnimation: View {
    let rainRate: Double
    let isRaining: Bool
    
    @State private var animationOffset: CGFloat = 0
    @State private var dropletOpacity: Double = 0.7
    
    private var rainIntensity: RainIntensity {
        if !isRaining { return .none }
        switch rainRate {
        case 0..<0.1: return .light
        case 0.1..<0.5: return .moderate
        case 0.5..<2.0: return .heavy
        default: return .extreme
        }
    }
    
    private enum RainIntensity: CaseIterable {
        case none, light, moderate, heavy, extreme
        
        var dropletCount: Int {
            switch self {
            case .none: return 0
            case .light: return 3
            case .moderate: return 5
            case .heavy: return 8
            case .extreme: return 12
            }
        }
        
        var animationSpeed: Double {
            switch self {
            case .none: return 0
            case .light: return 2.0
            case .moderate: return 1.5
            case .heavy: return 1.0
            case .extreme: return 0.7
            }
        }
        
        var dropletOpacity: Double {
            switch self {
            case .none: return 0
            case .light: return 0.4
            case .moderate: return 0.6
            case .heavy: return 0.8
            case .extreme: return 1.0
            }
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Multiple animated raindrops
                ForEach(0..<rainIntensity.dropletCount, id: \.self) { index in
                    RainDroplet(
                        index: index,
                        totalDroplets: rainIntensity.dropletCount,
                        containerSize: geometry.size,
                        animationSpeed: rainIntensity.animationSpeed,
                        opacity: rainIntensity.dropletOpacity
                    )
                }
            }
        }
        .clipped()
        .onAppear {
            if isRaining {
                startAnimation()
            }
        }
        .onChange(of: isRaining) { _, newValue in
            if newValue {
                startAnimation()
            }
        }
        .onChange(of: rainRate) { _, newRate in
            // Restart animation when rain rate changes significantly
            if isRaining {
                startAnimation()
            }
        }
        .onChange(of: rainIntensity) { _, newIntensity in
            // Restart animation when intensity level changes
            if isRaining {
                startAnimation()
            }
        }
    }
    
    private func startAnimation() {
        // Reset animation state
        animationOffset = 0
        
        withAnimation(.linear(duration: rainIntensity.animationSpeed).repeatForever(autoreverses: false)) {
            animationOffset = 1.0
        }
    }
}

struct RainDroplet: View {
    let index: Int
    let totalDroplets: Int
    let containerSize: CGSize
    let animationSpeed: Double
    let opacity: Double
    
    @State private var yOffset: CGFloat = 0
    @State private var isAnimating = false
    
    private var xPosition: CGFloat {
        let spacing = containerSize.width / CGFloat(max(totalDroplets, 1))
        return spacing * CGFloat(index) + spacing * 0.5
    }
    
    private var animationDelay: Double {
        Double(index) * 0.1
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [.blue.opacity(opacity), .cyan.opacity(opacity * 0.7)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 2, height: 6)
            .position(
                x: xPosition,
                y: yOffset
            )
            .onAppear {
                startDropletAnimation()
            }
    }
    
    private func startDropletAnimation() {
        // Start from above the container
        yOffset = -10
        
        // Add staggered delay for natural rainfall effect
        DispatchQueue.main.asyncAfter(deadline: .now() + animationDelay) {
            withAnimation(
                .linear(duration: animationSpeed)
                .repeatForever(autoreverses: false)
            ) {
                yOffset = containerSize.height + 10
            }
        }
    }
}

struct AirQualityCard: View {
    let title: String
    let data: PM25Data
    let systemImage: String
    let onTitleChange: (String) -> Void
    let getDailyPM25Stats: () -> DailyPM25Stats?
    
    var body: some View {
        EditableWeatherCard(
            title: .constant(title),
            systemImage: systemImage,
            onTitleChange: onTitleChange
        ) {
            VStack(alignment: .leading, spacing: 12) {
                // Current Air Quality - Main Display
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(data.pm25.value) \(data.pm25.unit)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    
                    let currentAQI = Int(data.realTimeAqi.value) ?? 0
                    let aqiCategory = AirQualityHelpers.getAQICategory(aqi: currentAQI)
                    
                    HStack(spacing: 8) {
                        Text("AQI: \(data.realTimeAqi.value)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(aqiCategory.color)
                        
                        Text("(\(aqiCategory.category))")
                            .font(.subheadline)
                            .foregroundColor(aqiCategory.color)
                    }
                }
                
                Divider()
                
                // Daily High/Low Section - Air Quality
                if let pm25Stats = getDailyPM25Stats() {
                    DailyAirQualityRangeView(
                        pm25Stats: pm25Stats,
                        currentPM25: Double(data.pm25.value) ?? 0.0,
                        currentAQI: Int(data.realTimeAqi.value) ?? 0
                    )
                } else {
                    // Enhanced fallback when no high/low data available
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Today's Range")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fontWeight(.semibold)
                        
                        HStack {
                            Text("Historical data:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("Loading...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        // Show current health impact while waiting for historical data
                        let currentAQI = Int(data.realTimeAqi.value) ?? 0
                        let aqiCategory = AirQualityHelpers.getAQICategory(aqi: currentAQI)
                        
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(aqiCategory.color)
                                .font(.caption)
                            Text("Current: \(aqiCategory.healthImpact)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                }
            }
        }
    }
}

struct DailyAirQualityRangeView: View {
    let pm25Stats: DailyPM25Stats
    let currentPM25: Double
    let currentAQI: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Today's Range")
                .font(.caption)
                .foregroundColor(.secondary)
                .fontWeight(.semibold)
            
            // PM2.5 High/Low
            HStack(spacing: 16) {
                // Daily High PM2.5
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundColor(.red)
                            .font(.caption2)
                        Text("High PM2.5")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text(pm25Stats.formattedHighPM25)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.red)
                    if pm25Stats.isReliable && pm25Stats.highPM25Time != nil {
                        Text("at \(pm25Stats.formattedHighPM25Time)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Daily Low PM2.5
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("Low PM2.5")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption2)
                    }
                    Text(pm25Stats.formattedLowPM25)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.green)
                    if pm25Stats.isReliable && pm25Stats.lowPM25Time != nil {
                        Text("at \(pm25Stats.formattedLowPM25Time)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // AQI High/Low
            HStack(spacing: 16) {
                // Daily High AQI
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.caption2)
                        Text("High AQI")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text(pm25Stats.formattedHighAQI)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(AirQualityHelpers.getAQICategory(aqi: pm25Stats.highAQI).color)
                    if pm25Stats.isReliable && pm25Stats.highAQITime != nil {
                        Text("at \(pm25Stats.formattedHighAQITime)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Daily Low AQI
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("Low AQI")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption2)
                    }
                    Text(pm25Stats.formattedLowAQI)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(AirQualityHelpers.getAQICategory(aqi: pm25Stats.lowAQI).color)
                    if pm25Stats.isReliable && pm25Stats.lowAQITime != nil {
                        Text("at \(pm25Stats.formattedLowAQITime)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Air quality trend indicator
            let airQualityTrend = AirQualityHelpers.getPM25Trend(current: currentPM25, currentAQI: currentAQI, stats: pm25Stats)
            HStack {
                Image(systemName: airQualityTrend.icon)
                    .foregroundColor(airQualityTrend.color)
                    .font(.caption)
                Text(airQualityTrend.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                if !pm25Stats.isReliable {
                    Text(pm25Stats.confidenceDescription)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
        }
    }
}