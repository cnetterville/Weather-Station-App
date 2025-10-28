//
//  SpecializedSensorCards.swift
//  Weather Station App
//
//  Created by Curtis Netterville on 10/25/25.
//

import SwiftUI

struct SolarUVCard: View {
    let station: WeatherStation
    let data: WeatherStationData
    let onTitleChange: (String) -> Void
    
    var body: some View {
        EditableWeatherCard(
            title: .constant(station.customLabels.solar),
            systemImage: "sun.max.fill",
            onTitleChange: onTitleChange
        ) {
            VStack(alignment: .leading, spacing: 12) {
                // Sun Strength Indicator
                if let solarValue = Double(data.solarAndUvi.solar.value) {
                    SunStrengthIndicator(solarRadiation: solarValue)
                        .frame(height: 60)
                        .padding(.vertical, 4)
                }
                
                // UV Index - Most prominent
                VStack(alignment: .leading, spacing: 4) {
                    Text("UV Index")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Text(data.solarAndUvi.uvi.value)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(SolarUVHelpers.getUVIndexColor(data.solarAndUvi.uvi.value))
                    Text(SolarUVHelpers.getUVIndexDescription(data.solarAndUvi.uvi.value))
                        .font(.subheadline)
                        .foregroundColor(SolarUVHelpers.getUVIndexColor(data.solarAndUvi.uvi.value))
                }
                
                Divider()
                
                // Solar Radiation Details
                SolarRadiationDetailsView(data: data)
            }
        }
    }
}

struct SunStrengthIndicator: View {
    let solarRadiation: Double
    
    private var maxSolarRadiation: Double {
        1200.0 // Peak solar radiation value for scaling
    }
    
    private var solarIntensityRatio: Double {
        min(solarRadiation / maxSolarRadiation, 1.0)
    }
    
    private var intensityLevel: SunStrengthIndicator.SolarIntensityLevel {
        switch solarRadiation {
        case 0...200: return .veryLow
        case 201...400: return .low
        case 401...600: return .moderate
        case 601...800: return .high
        case 801...1000: return .veryHigh
        default: return .extreme
        }
    }
    
    enum SolarIntensityLevel: CaseIterable {
        case veryLow, low, moderate, high, veryHigh, extreme
        
        var color: Color {
            switch self {
            case .veryLow: return .gray
            case .low: return .blue
            case .moderate: return .green
            case .high: return .orange
            case .veryHigh: return .red
            case .extreme: return .purple
            }
        }
        
        var description: String {
            switch self {
            case .veryLow: return "Very Low"
            case .low: return "Low"
            case .moderate: return "Moderate"
            case .high: return "High"
            case .veryHigh: return "Very High"
            case .extreme: return "Extreme"
            }
        }
        
        var sunSize: CGFloat {
            switch self {
            case .veryLow: return 20
            case .low: return 24
            case .moderate: return 28
            case .high: return 32
            case .veryHigh: return 36
            case .extreme: return 40
            }
        }
        
        var rayLength: CGFloat {
            switch self {
            case .veryLow: return 8
            case .low: return 10
            case .moderate: return 12
            case .high: return 14
            case .veryHigh: return 16
            case .extreme: return 18
            }
        }
        
        var glowRadius: CGFloat {
            switch self {
            case .veryLow: return 0
            case .low: return 1
            case .moderate: return 2
            case .high: return 4
            case .veryHigh: return 6
            case .extreme: return 8
            }
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            let centerX = geometry.size.width / 2
            let centerY = geometry.size.height / 2
            
            ZStack {
                // Background solar strength arc
                Path { path in
                    let radius = min(centerX, centerY) - 10
                    path.addArc(
                        center: CGPoint(x: centerX, y: centerY + 10),
                        radius: radius,
                        startAngle: .degrees(200),
                        endAngle: .degrees(340),
                        clockwise: false
                    )
                }
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            .gray.opacity(0.3),
                            .blue.opacity(0.3),
                            .green.opacity(0.3),
                            .orange.opacity(0.3),
                            .red.opacity(0.3),
                            .purple.opacity(0.3)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 8
                )
                
                // Active solar strength arc (shows current intensity)
                Path { path in
                    let radius = min(centerX, centerY) - 10
                    let startAngle: Double = 200
                    let totalAngle: Double = 140 // from 200 to 340 degrees
                    let currentAngle = startAngle + (totalAngle * solarIntensityRatio)
                    
                    path.addArc(
                        center: CGPoint(x: centerX, y: centerY + 10),
                        radius: radius,
                        startAngle: .degrees(startAngle),
                        endAngle: .degrees(currentAngle),
                        clockwise: false
                    )
                }
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            intensityLevel.color.opacity(0.8),
                            intensityLevel.color
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 8
                )
                
                // Animated sun icon at center
                AnimatedSunIcon(
                    intensity: intensityLevel,
                    solarRadiation: solarRadiation
                )
                .position(x: centerX, y: centerY - 5)
                
                // Intensity labels
                HStack {
                    VStack {
                        Text("Low")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("0")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .position(x: centerX - (min(centerX, centerY) - 10) * 0.7, y: centerY + 25)
                    
                    Spacer()
                    
                    VStack {
                        Text("Peak")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("1200")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .position(x: centerX + (min(centerX, centerY) - 10) * 0.7, y: centerY + 25)
                }
                
                // Current value display
                VStack(spacing: 2) {
                    Text("\(Int(solarRadiation)) W/m²")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(intensityLevel.color)
                    
                    Text(intensityLevel.description)
                        .font(.caption2)
                        .foregroundColor(intensityLevel.color.opacity(0.8))
                }
                .position(x: centerX, y: centerY + 35)
            }
        }
    }
}

struct AnimatedSunIcon: View {
    let intensity: SunStrengthIndicator.SolarIntensityLevel
    let solarRadiation: Double
    
    @State private var rotationAngle: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    
    private var animationSpeed: Double {
        switch intensity {
        case .veryLow: return 10.0
        case .low: return 8.0
        case .moderate: return 6.0
        case .high: return 4.0
        case .veryHigh: return 2.0
        case .extreme: return 1.0
        }
    }
    
    var body: some View {
        ZStack {
            // Sun rays (rotating)
            ForEach(0..<8, id: \.self) { index in
                Rectangle()
                    .fill(intensity.color)
                    .frame(width: 2, height: intensity.rayLength)
                    .offset(y: -(intensity.sunSize / 2 + intensity.rayLength / 2 + 2))
                    .rotationEffect(.degrees(Double(index) * 45 + rotationAngle))
                    .opacity(solarRadiation > 100 ? 0.8 : 0.3)
            }
            
            // Central sun circle
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            intensity.color.opacity(0.9),
                            intensity.color
                        ]),
                        center: .center,
                        startRadius: 0,
                        endRadius: intensity.sunSize / 2
                    )
                )
                .frame(width: intensity.sunSize, height: intensity.sunSize)
                .scaleEffect(pulseScale)
                .shadow(
                    color: intensity.color.opacity(0.6),
                    radius: intensity.glowRadius
                )
            
            // Sun face (optional cute detail)
            if intensity != .veryLow {
                VStack(spacing: 1) {
                    HStack(spacing: 3) {
                        Circle()
                            .fill(.white)
                            .frame(width: 3, height: 3)
                        Circle()
                            .fill(.white)
                            .frame(width: 3, height: 3)
                    }
                    
                    Capsule()
                        .fill(.white)
                        .frame(width: 6, height: 2)
                }
                .opacity(0.8)
            }
        }
        .onAppear {
            startAnimations()
        }
    }
    
    private func startAnimations() {
        // Rotation animation for sun rays
        withAnimation(.linear(duration: animationSpeed).repeatForever(autoreverses: false)) {
            rotationAngle = 360
        }
        
        // Pulse animation for intense sun
        if intensity.glowRadius > 0 {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseScale = 1.1
            }
        }
    }
}

struct SolarRadiationDetailsView: View {
    let data: WeatherStationData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Solar Radiation:")
                    .font(.subheadline)
                Spacer()
                Text("\(data.solarAndUvi.solar.value) \(data.solarAndUvi.solar.unit)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            
            // Solar intensity description
            if let solarValue = Double(data.solarAndUvi.solar.value) {
                HStack {
                    Text("Intensity:")
                        .font(.subheadline)
                    Spacer()
                    Text(SolarUVHelpers.getSolarIntensityDescription(solarValue))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(SolarUVHelpers.getSolarIntensityColor(solarValue))
                }
                
                // Estimated solar panel efficiency (for fun)
                let efficiency = SolarUVHelpers.estimateSolarPanelOutput(solarValue)
                HStack {
                    Text("Solar Panel Est.:")
                        .font(.subheadline)
                    Spacer()
                    Text("\(String(format: "%.0f", efficiency))% of peak")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
            }
        }
    }
}

struct LightningCard: View {
    let station: WeatherStation
    let data: WeatherStationData
    let onTitleChange: (String) -> Void
    let getLastLightningStats: () -> LastLightningStats?
    
    var body: some View {
        EditableWeatherCard(
            title: .constant(station.customLabels.lightning),
            systemImage: "cloud.bolt.fill",
            onTitleChange: onTitleChange
        ) {
            VStack(alignment: .leading, spacing: 12) {
                // Current Lightning Distance - Main Display
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Distance")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(MeasurementConverter.formatDistance(data.lightning.distance.value, originalUnit: data.lightning.distance.unit))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.orange)
                }
                
                // Current Lightning Count
                HStack {
                    Text("Current Count:")
                        .font(.subheadline)
                    Spacer()
                    Text(data.lightning.count.value)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // Last Lightning Detection
                LastLightningDetectionView(getLastLightningStats: getLastLightningStats)
            }
        }
    }
}

struct LightningDistanceRings: View {
    let currentDistance: Double
    let distanceUnit: String
    let lightningCount: Int
    
    // Define safety zones for lightning (in miles/km)
    private let safetyZones: [(distance: Double, color: Color, label: String)] = [
        (5, .red, "Danger"),      // 0-5 miles - immediate danger
        (10, .orange, "Warning"),  // 5-10 miles - warning zone  
        (20, .yellow, "Caution"),  // 10-20 miles - caution zone
        (40, .green, "Safe")       // 20+ miles - generally safe
    ]
    
    private var maxDisplayDistance: Double {
        40.0 // Show up to 40 miles/km range
    }
    
    private var currentDistanceInDisplayUnits: Double {
        // Convert current distance to miles for consistent display
        if distanceUnit.lowercased().contains("km") {
            return currentDistance * 0.621371 // Convert km to miles
        }
        return currentDistance
    }
    
    private var isLightningActive: Bool {
        lightningCount > 0 && currentDistance > 0
    }
    
    private var currentSafetyZone: (distance: Double, color: Color, label: String) {
        let distance = currentDistanceInDisplayUnits
        
        for zone in safetyZones {
            if distance <= zone.distance {
                return zone
            }
        }
        return safetyZones.last ?? (40, .green, "Safe")
    }
    
    var body: some View {
        GeometryReader { geometry in
            let centerX = geometry.size.width / 2
            let centerY = geometry.size.height / 2
            let maxRadius = min(centerX, centerY) - 5
            
            ZStack {
                // Background concentric circles (safety zones)
                ForEach(Array(safetyZones.enumerated()), id: \.offset) { index, zone in
                    let radius = (zone.distance / maxDisplayDistance) * maxRadius
                    
                    Circle()
                        .stroke(zone.color.opacity(0.2), lineWidth: 1)
                        .frame(width: radius * 2, height: radius * 2)
                        .position(x: centerX, y: centerY)
                    
                    // Zone labels
                    Text(zone.label)
                        .font(.caption2)
                        .foregroundColor(zone.color.opacity(0.7))
                        .position(
                            x: centerX + radius * cos(.pi / 4) * 0.7,
                            y: centerY - radius * sin(.pi / 4) * 0.7
                        )
                }
                
                // Weather station at center
                Circle()
                    .fill(.blue)
                    .frame(width: 8, height: 8)
                    .position(x: centerX, y: centerY)
                    .overlay(
                        Circle()
                            .stroke(.blue.opacity(0.3), lineWidth: 2)
                            .frame(width: 12, height: 12)
                            .position(x: centerX, y: centerY)
                    )
                
                // Current lightning position indicator
                if isLightningActive {
                    let lightningRadius = min(
                        (currentDistanceInDisplayUnits / maxDisplayDistance) * maxRadius,
                        maxRadius
                    )
                    
                    // Lightning strike indicator
                    Group {
                        // Strike position (at the distance)
                        Image(systemName: "bolt.fill")
                            .foregroundColor(currentSafetyZone.color)
                            .font(.system(size: 12))
                            .position(
                                x: centerX + lightningRadius * cos(.pi / 6),
                                y: centerY - lightningRadius * sin(.pi / 6)
                            )
                            .shadow(color: currentSafetyZone.color.opacity(0.6), radius: 2)
                        
                        // Distance ring highlighting current distance
                        Circle()
                            .stroke(currentSafetyZone.color, lineWidth: 2)
                            .frame(width: lightningRadius * 2, height: lightningRadius * 2)
                            .position(x: centerX, y: centerY)
                            .opacity(0.8)
                        
                        // Pulsing effect for active lightning
                        Circle()
                            .stroke(currentSafetyZone.color.opacity(0.3), lineWidth: 1)
                            .frame(width: lightningRadius * 2, height: lightningRadius * 2)
                            .position(x: centerX, y: centerY)
                            .scaleEffect(lightningPulseScale)
                            .animation(
                                .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                                value: lightningPulseScale
                            )
                    }
                }
                
                // Distance scale indicators
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("0")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("mi")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .position(x: centerX - 10, y: centerY + maxRadius + 15)
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(Int(maxDisplayDistance))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("mi")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .position(x: centerX + maxRadius, y: centerY + 15)
                }
            }
        }
    }
    
    @State private var lightningPulseScale: CGFloat = 1.0
    
    init(currentDistance: Double, distanceUnit: String, lightningCount: Int) {
        self.currentDistance = currentDistance
        self.distanceUnit = distanceUnit
        self.lightningCount = lightningCount
        self._lightningPulseScale = State(initialValue: 1.0)
    }
}

struct LastLightningDetectionView: View {
    let getLastLightningStats: () -> LastLightningStats?
    
    var body: some View {
        if let lightningStats = getLastLightningStats() {
            VStack(alignment: .leading, spacing: 8) {
                Text("Last Lightning Detection")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fontWeight(.semibold)
                
                HStack {
                    Image(systemName: lightningStats.lastDetectionTime != nil ? "clock.fill" : "clock")
                        .foregroundColor(lightningStats.lastDetectionTime != nil ? .yellow : .secondary)
                        .font(.caption)
                    
                    Text(lightningStats.formattedLastDetection)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(lightningStats.lastDetectionTime != nil ? .primary : .secondary)
                    
                    Spacer()
                }
                
                // Confidence/search range indicator
                Text(lightningStats.confidenceDescription)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .italic()
            }
        } else {
            // Fallback when no lightning data available
            VStack(alignment: .leading, spacing: 4) {
                Text("Last Lightning Detection")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fontWeight(.semibold)
                
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    
                    Text("No data available")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
            }
        }
    }
}

struct BatteryStatusCard: View {
    let station: WeatherStation
    let data: WeatherStationData
    let onTitleChange: (String) -> Void
    
    var body: some View {
        EditableWeatherCard(
            title: .constant(station.customLabels.batteryStatus),
            systemImage: "battery.100",
            onTitleChange: onTitleChange
        ) {
            VStack(alignment: .leading, spacing: 8) {
                // System Health Overview (Traffic Light Dashboard)
                BatteryHealthDashboard(data: data)
                
                Divider()
                
                BatteryMainSystemsView(data: data)
                Divider()
                BatterySensorSystemsView(data: data)
            }
            .font(.caption)
        }
    }
}

struct BatteryHealthDashboard: View {
    let data: WeatherStationData
    
    private var systemHealthStats: (total: Int, healthy: Int, warning: Int, critical: Int) {
        var stats = (total: 0, healthy: 0, warning: 0, critical: 0)
        
        // Check all battery components
        let batteries = [
            data.battery.console?.value,
            data.battery.hapticArrayBattery?.value,
            data.battery.hapticArrayCapacitor?.value,
            data.battery.lightningSensor?.value,
            data.battery.rainfallSensor?.value,
            data.battery.pm25SensorCh1?.value,
            data.battery.pm25SensorCh2?.value,
            data.battery.tempHumiditySensorCh1?.value,
            data.battery.tempHumiditySensorCh2?.value,
            data.battery.tempHumiditySensorCh3?.value
        ]
        
        for batteryValue in batteries {
            guard let value = batteryValue else { continue }
            stats.total += 1
            
            let status = BatteryHealthHelper.getBatteryHealth(value)
            switch status.level {
            case .healthy:
                stats.healthy += 1
            case .warning:
                stats.warning += 1
            case .critical:
                stats.critical += 1
            }
        }
        
        return stats
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("System Health Overview")
                .font(.caption)
                .foregroundColor(.secondary)
                .fontWeight(.semibold)
            
            HStack(spacing: 12) {
                // Traffic Light Indicators
                HStack(spacing: 8) {
                    // Green (Healthy)
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.green)
                            .frame(width: 12, height: 12)
                        Text("\(systemHealthStats.healthy)")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    
                    // Yellow (Warning)
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.orange)
                            .frame(width: 12, height: 12)
                        Text("\(systemHealthStats.warning)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(systemHealthStats.warning > 0 ? .orange : .secondary)
                    }
                    
                    // Red (Critical)
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.red)
                            .frame(width: 12, height: 12)
                        Text("\(systemHealthStats.critical)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(systemHealthStats.critical > 0 ? .red : .secondary)
                    }
                }
                
                Spacer()
                
                // Overall Status
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: overallSystemIcon)
                            .foregroundColor(overallSystemColor)
                            .font(.caption)
                        Text(overallSystemStatus)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(overallSystemColor)
                    }
                    
                    Text("\(systemHealthStats.total) systems")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var overallSystemStatus: String {
        if systemHealthStats.critical > 0 {
            return "Critical"
        } else if systemHealthStats.warning > 0 {
            return "Warning"
        } else if systemHealthStats.healthy > 0 {
            return "Healthy"
        } else {
            return "No Data"
        }
    }
    
    private var overallSystemColor: Color {
        if systemHealthStats.critical > 0 {
            return .red
        } else if systemHealthStats.warning > 0 {
            return .orange
        } else if systemHealthStats.healthy > 0 {
            return .green
        } else {
            return .secondary
        }
    }
    
    private var overallSystemIcon: String {
        if systemHealthStats.critical > 0 {
            return "exclamationmark.triangle.fill"
        } else if systemHealthStats.warning > 0 {
            return "exclamationmark.circle.fill"
        } else if systemHealthStats.healthy > 0 {
            return "checkmark.circle.fill"
        } else {
            return "questionmark.circle"
        }
    }
}

struct BatteryMainSystemsView: View {
    let data: WeatherStationData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Main Console and Haptic Array
            if let console = data.battery.console {
                HStack {
                    BatteryHealthIndicator(value: console.value)
                    Text("Console:")
                    Spacer()
                    Text("\(console.value) \(console.unit)")
                        .fontWeight(.semibold)
                }
            }
            
            if let haptic = data.battery.hapticArrayBattery {
                HStack {
                    BatteryHealthIndicator(value: haptic.value)
                    Text("Haptic Array:")
                    Spacer()
                    Text("\(haptic.value) \(haptic.unit)")
                        .fontWeight(.semibold)
                }
            }
            
            // Haptic Capacitor - moved up for better visibility
            if let hapticCap = data.battery.hapticArrayCapacitor {
                HStack {
                    BatteryHealthIndicator(value: hapticCap.value)
                    Text("Haptic Capacitor:")
                    Spacer()
                    Text("\(hapticCap.value) \(hapticCap.unit)")
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
            }
        }
    }
}

struct BatterySensorSystemsView: View {
    let data: WeatherStationData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Sensor Batteries
            if let lightning = data.battery.lightningSensor {
                HStack {
                    BatteryHealthIndicator(value: lightning.value)
                    Text("Lightning Sensor:")
                    Spacer()
                    Text(WeatherStatusHelpers.batteryLevelText(lightning.value))
                }
            }
            
            if let rainfall = data.battery.rainfallSensor {
                HStack {
                    BatteryHealthIndicator(value: rainfall.value)
                    Text("Rainfall Sensor:")
                    Spacer()
                    Text("\(rainfall.value) \(rainfall.unit)")
                }
            }
            
            if let pm25Ch1 = data.battery.pm25SensorCh1 {
                HStack {
                    BatteryHealthIndicator(value: pm25Ch1.value)
                    Text("PM2.5 Ch1:")
                    Spacer()
                    Text(WeatherStatusHelpers.batteryLevelText(pm25Ch1.value))
                }
            }
            
            if let pm25Ch2 = data.battery.pm25SensorCh2 {
                HStack {
                    BatteryHealthIndicator(value: pm25Ch2.value)
                    Text("PM2.5 Ch2:")
                    Spacer()
                    Text(WeatherStatusHelpers.batteryLevelText(pm25Ch2.value))
                }
            }
            
            if let th1 = data.battery.tempHumiditySensorCh1 {
                HStack {
                    BatteryHealthIndicator(value: th1.value)
                    Text("Temp/Humidity Ch1:")
                    Spacer()
                    Text(WeatherStatusHelpers.tempHumidityBatteryStatusText(th1.value))
                }
            }
            
            if let th2 = data.battery.tempHumiditySensorCh2 {
                HStack {
                    BatteryHealthIndicator(value: th2.value)
                    Text("Temp/Humidity Ch2:")
                    Spacer()
                    Text(WeatherStatusHelpers.tempHumidityBatteryStatusText(th2.value))
                }
            }
            
            if let th3 = data.battery.tempHumiditySensorCh3 {
                HStack {
                    BatteryHealthIndicator(value: th3.value)
                    Text("Temp/Humidity Ch3:")
                    Spacer()
                    Text(WeatherStatusHelpers.tempHumidityBatteryStatusText(th3.value))
                }
            }
        }
    }
}

struct BatteryHealthIndicator: View {
    let value: String
    
    private var healthStatus: BatteryHealthHelper.BatteryHealth {
        BatteryHealthHelper.getBatteryHealth(value)
    }
    
    var body: some View {
        Circle()
            .fill(healthStatus.color)
            .frame(width: 12, height: 12)
            .shadow(color: healthStatus.color.opacity(0.3), radius: 1)
    }
}

// MARK: - Battery Health Helper
struct BatteryHealthHelper {
    enum HealthLevel {
        case healthy, warning, critical
    }
    
    struct BatteryHealth {
        let level: HealthLevel
        let color: Color
        let description: String
    }
    
    static func getBatteryHealth(_ value: String) -> BatteryHealth {
        // Handle voltage values (like console, haptic array)
        if value.contains(".") || value.contains("V") {
            let numericValue = Double(value.replacingOccurrences(of: "V", with: "")) ?? 0
            
            if numericValue >= 3.0 {
                return BatteryHealth(level: .healthy, color: .green, description: "Good")
            } else if numericValue >= 2.5 {
                return BatteryHealth(level: .warning, color: .orange, description: "Low")
            } else {
                return BatteryHealth(level: .critical, color: .red, description: "Critical")
            }
        }
        
        // Handle temp/humidity sensor status FIRST (before integer parsing)
        // These sensors return "0" = Normal (Green) or "1" = Low (Orange)
        if value == "0" {
            return BatteryHealth(level: .healthy, color: .green, description: "Normal")
        } else if value == "1" {
            return BatteryHealth(level: .warning, color: .orange, description: "Low")
        }
        
        // Handle integer values (sensor battery levels 2-6, but NOT 0-1 from temp/humidity)
        if let intValue = Int(value), intValue >= 2 {
            switch intValue {
            case 4...6: // 61-100% + DC Power
                return BatteryHealth(level: .healthy, color: .green, description: "Good")
            case 2...3: // 21-60%
                return BatteryHealth(level: .warning, color: .orange, description: "Low")
            default:
                return BatteryHealth(level: .warning, color: .orange, description: "Unknown")
            }
        }
        
        // Handle other battery sensor levels (0-1 range for non-temp/humidity sensors)
        if let intValue = Int(value), intValue < 2 {
            // This would be for PM2.5 or Lightning sensors with 0-1 values (Critical)
            return BatteryHealth(level: .critical, color: .red, description: "Critical")
        }
        
        // Default case
        return BatteryHealth(level: .warning, color: .orange, description: "Unknown")
    }
}

struct SunriseSunsetCard: View {
    let station: WeatherStation
    let onTitleChange: (String) -> Void
    
    var body: some View {
        EditableWeatherCard(
            title: .constant(station.customLabels.sunriseSunset),
            systemImage: SunHelpers.sunIconForCurrentTime(station: station),
            onTitleChange: onTitleChange
        ) {
            if let latitude = station.latitude, let longitude = station.longitude,
               let sunTimes = SunCalculator.calculateSunTimes(for: Date(), latitude: latitude, longitude: longitude, timeZone: station.timeZone) {
                SunTimesView(sunTimes: sunTimes, station: station)
            } else {
                SunLocationRequiredView()
            }
        }
    }
}

struct SunTimesView: View {
    let sunTimes: SunTimes
    let station: WeatherStation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Current status
            HStack {
                Image(systemName: sunTimes.isCurrentlyDaylight ? "sun.max.fill" : "moon.fill")
                    .foregroundColor(sunTimes.isCurrentlyDaylight ? .orange : .blue)
                Text(sunTimes.isCurrentlyDaylight ? "Daylight" : "Nighttime")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            // Sun Position Arc
            SunPositionArc(sunTimes: sunTimes)
                .frame(height: 50)
                .padding(.vertical, 4)
            
            // Sunrise and sunset times
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "sunrise.fill")
                            .foregroundColor(.orange)
                        Text("Sunrise")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Text(sunTimes.formattedSunrise)
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    HStack {
                        Text("Sunset")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Image(systemName: "sunset.fill")
                            .foregroundColor(.red)
                    }
                    Text(sunTimes.formattedSunset)
                        .font(.title2)
                        .fontWeight(.bold)
                }
            }
            
            // Day length
            HStack {
                Text("Day Length:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text(sunTimes.formattedDayLength)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            
            // Tomorrow's sunrise and sunset
            if let latitude = station.latitude, let longitude = station.longitude {
                let calendar = Calendar.current
                let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
                
                if let tomorrowSunTimes = SunCalculator.calculateSunTimes(for: tomorrow, latitude: latitude, longitude: longitude, timeZone: station.timeZone) {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Tomorrow")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fontWeight(.semibold)
                        
                        HStack {
                            Text("Sunrise:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(tomorrowSunTimes.formattedSunrise)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        
                        HStack {
                            Text("Sunset:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(tomorrowSunTimes.formattedSunset)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        
                        HStack {
                            Text("Day Length:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(tomorrowSunTimes.formattedDayLength)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
        }
    }
    
    // Helper function to format time in the correct timezone
    private func formatTimeInTimeZone(_ date: Date, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.timeZone = timeZone
        return formatter.string(from: date)
    }
}

struct SunPositionArc: View {
    let sunTimes: SunTimes
    
    private var sunPosition: CGFloat {
        let now = Date()
        
        // If before sunrise or after sunset, show sun below horizon
        if now < sunTimes.sunrise {
            return 0 // Before sunrise - sun at left edge (below horizon)
        } else if now > sunTimes.sunset {
            return 1 // After sunset - sun at right edge (below horizon)
        } else {
            // During the day - calculate position along arc
            let totalDaylight = sunTimes.sunset.timeIntervalSince(sunTimes.sunrise)
            let timeSinceSunrise = now.timeIntervalSince(sunTimes.sunrise)
            return CGFloat(timeSinceSunrise / totalDaylight)
        }
    }
    
    private var isDaytime: Bool {
        let now = Date()
        return now >= sunTimes.sunrise && now <= sunTimes.sunset
    }
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let arcHeight = height * 0.7
            
            ZStack {
                // Background arc representing the sun's path
                Path { path in
                    path.move(to: CGPoint(x: 0, y: height))
                    path.addQuadCurve(
                        to: CGPoint(x: width, y: height),
                        control: CGPoint(x: width / 2, y: height - arcHeight)
                    )
                }
                .stroke(Color.secondary.opacity(0.3), lineWidth: 2)
                
                // Daylight portion of the arc (if currently daylight)
                if isDaytime {
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: height))
                        
                        let endX = width * sunPosition
                        let controlX = endX / 2
                        let controlY = height - (arcHeight * sin(.pi * sunPosition))
                        
                        path.addQuadCurve(
                            to: CGPoint(x: endX, y: height),
                            control: CGPoint(x: controlX, y: controlY)
                        )
                    }
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [.orange, .yellow]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 3
                    )
                }
                
                // Sun position indicator
                let sunX = width * sunPosition
                let sunY = isDaytime ? 
                    height - (arcHeight * sin(.pi * sunPosition)) : 
                    height + 5 // Below horizon when not daylight
                
                Circle()
                    .fill(isDaytime ? .yellow : .gray)
                    .frame(width: 12, height: 12)
                    .position(x: sunX, y: sunY)
                    .shadow(color: isDaytime ? .yellow.opacity(0.6) : .clear, radius: 2)
                
                // Sunrise marker
                Circle()
                    .fill(.orange)
                    .frame(width: 6, height: 6)
                    .position(x: 0, y: height)
                
                // Sunset marker  
                Circle()
                    .fill(.red)
                    .frame(width: 6, height: 6)
                    .position(x: width, y: height)
                
                // Current time indicator (optional - shows exact current time)
                if isDaytime {
                    Rectangle()
                        .fill(.primary.opacity(0.5))
                        .frame(width: 1, height: 8)
                        .position(x: sunX, y: height + 8)
                }
            }
        }
    }
}

struct SunLocationRequiredView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "location.slash")
                .font(.system(size: 24))
                .foregroundColor(.secondary)
            Text("Location Required")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Sunrise/sunset calculations require station location data")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

struct LunarCard: View {
    let station: WeatherStation
    let onTitleChange: (String) -> Void
    
    var body: some View {
        EditableWeatherCard(
            title: .constant(station.customLabels.lunar),
            systemImage: "moon.stars.fill",
            onTitleChange: onTitleChange
        ) {
            if let latitude = station.latitude, let longitude = station.longitude {
                LunarInfoView(
                    latitude: latitude,
                    longitude: longitude,
                    timeZone: station.timeZone
                )
            } else {
                LunarLocationRequiredView()
            }
        }
    }
}

struct LunarInfoView: View {
    let latitude: Double
    let longitude: Double
    let timeZone: TimeZone
    
    private var moonPhase: MoonPhase {
        MoonCalculator.getCurrentMoonPhase(for: Date(), timeZone: timeZone)
    }
    
    private var moonTimes: MoonTimes? {
        MoonCalculator.calculateMoonTimes(
            for: Date(),
            latitude: latitude,
            longitude: longitude,
            timeZone: timeZone
        )
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Current Moon Phase Display
            HStack(spacing: 16) {
                // Moon Phase Visual
                MoonPhaseVisual(phase: moonPhase)
                    .frame(width: 50, height: 50)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(moonPhase.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("\(Int(moonPhase.illumination * 100))% Illuminated")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Age: \(moonPhase.age) days")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            Divider()
            
            // Moonrise and Moonset Times
            if let moonTimes = moonTimes {
                MoonTimesView(moonTimes: moonTimes, timeZone: timeZone)
            } else {
                Text("Moon times unavailable")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // Next Moon Phase Information
            NextMoonPhaseView(currentPhase: moonPhase)
        }
    }
}

struct MoonPhaseVisual: View {
    let phase: MoonPhase
    
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            
            ZStack {
                // Background circle (full moon)
                Circle()
                    .fill(.gray.opacity(0.2))
                    .frame(width: size, height: size)
                
                // Illuminated portion
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [.yellow.opacity(0.8), .white]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size, height: size)
                    .mask(
                        MoonPhaseMask(illumination: phase.illumination, isWaxing: phase.isWaxing)
                            .frame(width: size, height: size)
                    )
                
                // Subtle border
                Circle()
                    .stroke(.secondary.opacity(0.3), lineWidth: 1)
                    .frame(width: size, height: size)
            }
        }
    }
}

struct MoonPhaseMask: View {
    let illumination: Double
    let isWaxing: Bool
    
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let radius = size / 2
            let center = CGPoint(x: size / 2, y: size / 2)
            
            Path { path in
                // Create the moon phase shape
                if illumination <= 0.01 {
                    // New moon - no illumination
                    return
                } else if illumination >= 0.99 {
                    // Full moon - complete circle
                    path.addEllipse(in: CGRect(x: 0, y: 0, width: size, height: size))
                } else if illumination == 0.5 {
                    // Quarter moon - half circle
                    path.move(to: CGPoint(x: center.x, y: 0))
                    path.addArc(
                        center: center,
                        radius: radius,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(90),
                        clockwise: isWaxing
                    )
                    path.closeSubpath()
                } else {
                    // Crescent or gibbous moon
                    let phase = illumination
                    
                    // Calculate the shape of the terminator (day/night boundary)
                    path.move(to: CGPoint(x: center.x, y: 0))
                    
                    if isWaxing {
                        // Waxing phases (crescent to gibbous)
                        if phase < 0.5 {
                            // Waxing crescent
                            let ellipseWidth = size * (1 - 2 * phase)
                            path.addEllipse(in: CGRect(
                                x: center.x - ellipseWidth / 2,
                                y: 0,
                                width: ellipseWidth,
                                height: size
                            ))
                            path.addArc(
                                center: center,
                                radius: radius,
                                startAngle: .degrees(-90),
                                endAngle: .degrees(90),
                                clockwise: true
                            )
                        } else {
                            // Waxing gibbous
                            path.addEllipse(in: CGRect(x: 0, y: 0, width: size, height: size))
                            let ellipseWidth = size * (2 * (1 - phase))
                            path.addEllipse(in: CGRect(
                                x: center.x - ellipseWidth / 2,
                                y: 0,
                                width: ellipseWidth,
                                height: size
                            ))
                        }
                    } else {
                        // Waning phases (gibbous to crescent)
                        if phase > 0.5 {
                            // Waning gibbous
                            path.addEllipse(in: CGRect(x: 0, y: 0, width: size, height: size))
                            let ellipseWidth = size * (2 * (1 - phase))
                            path.addEllipse(in: CGRect(
                                x: size - center.x - ellipseWidth / 2,
                                y: 0,
                                width: ellipseWidth,
                                height: size
                            ))
                        } else {
                            // Waning crescent
                            let ellipseWidth = size * (1 - 2 * phase)
                            path.addEllipse(in: CGRect(
                                x: size - center.x - ellipseWidth / 2,
                                y: 0,
                                width: ellipseWidth,
                                height: size
                            ))
                            path.addArc(
                                center: center,
                                radius: radius,
                                startAngle: .degrees(-90),
                                endAngle: .degrees(90),
                                clockwise: false
                            )
                        }
                    }
                }
            }
            .fill(.black)
        }
    }
}

struct MoonTimesView: View {
    let moonTimes: MoonTimes
    let timeZone: TimeZone
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Moon Times")
                .font(.caption)
                .foregroundColor(.secondary)
                .fontWeight(.semibold)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "moonrise.fill")
                            .foregroundColor(.blue)
                        Text("Moonrise")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    if let moonrise = moonTimes.moonrise {
                        Text(formatTimeInTimeZone(moonrise, timeZone: timeZone))
                            .font(.title3)
                            .fontWeight(.bold)
                    } else {
                        Text("No moonrise")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    HStack {
                        Text("Moonset")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Image(systemName: "moonset.fill")
                            .foregroundColor(.purple)
                    }
                    if let moonset = moonTimes.moonset {
                        Text(formatTimeInTimeZone(moonset, timeZone: timeZone))
                            .font(.title3)
                            .fontWeight(.bold)
                    } else {
                        Text("No moonset")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Show current timezone name (accounts for daylight saving)
            Text("Times shown in \(getCurrentTimeZoneName())")
                .font(.caption2)
                .foregroundColor(.secondary)
                .italic()
        }
    }
    
    private func formatTimeInTimeZone(_ date: Date, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.timeZone = timeZone
        return formatter.string(from: date)
    }
    
    private func getCurrentTimeZoneName() -> String {
        // Get the current timezone name accounting for daylight saving
        if timeZone.isDaylightSavingTime(for: Date()) {
            // Use daylight saving name (e.g., "CDT")
            return timeZone.localizedName(for: .daylightSaving, locale: .current) ?? timeZone.abbreviation(for: Date()) ?? "Local Time"
        } else {
            // Use standard time name (e.g., "CST")
            return timeZone.localizedName(for: .standard, locale: .current) ?? timeZone.abbreviation(for: Date()) ?? "Local Time"
        }
    }
}

struct NextMoonPhaseView: View {
    let currentPhase: MoonPhase
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Upcoming")
                .font(.caption)
                .foregroundColor(.secondary)
                .fontWeight(.semibold)
            
            HStack {
                Text("Next \(currentPhase.nextPhaseName):")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text("in \(currentPhase.daysToNextPhase) days")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            
            HStack {
                Text("Next Full Moon:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text("in \(currentPhase.daysToNextFullMoon) days")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.yellow)
            }
        }
    }
}

struct LunarLocationRequiredView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "location.slash")
                .font(.system(size: 24))
                .foregroundColor(.secondary)
            Text("Location Required")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Moon calculations require station location data")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Moon Calculation System
struct MoonPhase {
    let name: String
    let illumination: Double // 0.0 to 1.0
    let age: Int // Days since new moon
    let isWaxing: Bool
    let nextPhaseName: String
    let daysToNextPhase: Int
    let daysToNextFullMoon: Int
}

struct MoonTimes {
    let moonrise: Date?
    let moonset: Date?
}

class MoonCalculator {
    
    static func getCurrentMoonPhase(for date: Date, timeZone: TimeZone = .current) -> MoonPhase {
        // Convert date to Julian Day
        let julianDay = dateToJulianDay(date)
        
        // Calculate moon phase
        let phase = calculateMoonPhase(julianDay: julianDay)
        let illumination = 0.5 * (1 - cos(2 * .pi * phase))
        
        // Calculate age in days (moon cycle is ~29.53 days)
        let age = Int(phase * 29.53)
        
        let (name, isWaxing, nextPhase, daysToNext) = getMoonPhaseInfo(age: age, illumination: illumination)
        let daysToFullMoon = calculateDaysToNextFullMoon(age: age)
        
        return MoonPhase(
            name: name,
            illumination: illumination,
            age: age,
            isWaxing: isWaxing,
            nextPhaseName: nextPhase,
            daysToNextPhase: daysToNext,
            daysToNextFullMoon: daysToFullMoon
        )
    }
    
    static func calculateMoonTimes(for date: Date, latitude: Double, longitude: Double, timeZone: TimeZone) -> MoonTimes? {
        // Set up calendar for the specific timezone
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        
        let startOfDay = calendar.startOfDay(for: date)
        var moonrise: Date?
        var moonset: Date?
        var previousAltitude: Double?
        
        print("🌙 Calculating moon times for date: \(date)")
        print("🌙 Start of day in timezone: \(startOfDay)")
        print("🌙 Latitude: \(latitude), Longitude: \(longitude)")
        print("🌙 TimeZone: \(timeZone.identifier)")
        
        // Check every 30 minutes throughout the day for more precision
        for halfHour in 0..<48 {
            let currentTime = startOfDay.addingTimeInterval(Double(halfHour) * 1800) // 30 minutes = 1800 seconds
            let currentAltitude = calculateMoonAltitude(for: currentTime, latitude: latitude, longitude: longitude, timeZone: timeZone)
            
            if let prevAlt = previousAltitude {
                // Moonrise: altitude changes from negative to positive
                if prevAlt < 0 && currentAltitude >= 0 && moonrise == nil {
                    // Interpolate to find more precise time
                    let ratio = -prevAlt / (currentAltitude - prevAlt)
                    moonrise = currentTime.addingTimeInterval(-1800 + ratio * 1800)
                    print("🌙 Found moonrise at: \(moonrise!)")
                }
                
                // Moonset: altitude changes from positive to negative
                if prevAlt >= 0 && currentAltitude < 0 && moonset == nil {
                    // Interpolate to find more precise time
                    let ratio = -prevAlt / (currentAltitude - prevAlt)
                    moonset = currentTime.addingTimeInterval(-1800 + ratio * 1800)
                    print("🌙 Found moonset at: \(moonset!)")
                }
            }
            
            previousAltitude = currentAltitude
            
            // Debug: Print altitude for troubleshooting
            if halfHour % 4 == 0 { // Every 2 hours
                let formatter = DateFormatter()
                formatter.timeStyle = .short
                formatter.timeZone = timeZone
                print("🌙 \(formatter.string(from: currentTime)): Moon altitude = \(String(format: "%.2f", currentAltitude))°")
            }
        }
        
        return MoonTimes(moonrise: moonrise, moonset: moonset)
    }
    
    private static func dateToJulianDay(_ date: Date) -> Double {
        // Convert to Julian Day (standard astronomical calculation)
        let timeInterval = date.timeIntervalSince1970
        let julianDay = (timeInterval / 86400.0) + 2440587.5
        return julianDay
    }
    
    private static func calculateMoonPhase(julianDay: Double) -> Double {
        // Calculate moon phase based on Julian Day
        // Reference: January 6, 2000 was a new moon
        let newMoonReference = 2451550.1  // JD of new moon on Jan 6, 2000
        let lunarCycle = 29.53058867      // Average lunar month in days
        
        let daysSinceNewMoon = julianDay - newMoonReference
        let cyclesSinceNewMoon = daysSinceNewMoon / lunarCycle
        let phasePosition = cyclesSinceNewMoon - floor(cyclesSinceNewMoon)
        
        return phasePosition
    }
    
    private static func calculateMoonAltitude(for date: Date, latitude: Double, longitude: Double, timeZone: TimeZone) -> Double {
        // Convert date to UTC for astronomical calculations
        let utcDate = date
        let julianDay = dateToJulianDay(utcDate)
        
        // Calculate moon's position (simplified)
        let moonPosition = calculateMoonPosition(julianDay: julianDay)
        
        // Calculate local sidereal time for the given longitude and time
        let lst = calculateLocalSiderealTime(julianDay: julianDay, longitude: longitude)
        
        // Calculate hour angle (in degrees)
        var hourAngle = lst - moonPosition.rightAscension
        
        // Normalize hour angle to [-180, 180] range
        while hourAngle > 180 { hourAngle -= 360 }
        while hourAngle < -180 { hourAngle += 360 }
        
        // Convert to radians for trigonometric calculations
        let latRad = latitude * .pi / 180.0
        let decRad = moonPosition.declination * .pi / 180.0
        let haRad = hourAngle * .pi / 180.0
        
        // Calculate altitude using spherical trigonometry
        let sinAlt = sin(latRad) * sin(decRad) + cos(latRad) * cos(decRad) * cos(haRad)
        let altitudeRad = asin(max(-1.0, min(1.0, sinAlt))) // Clamp to valid range
        let altitude = altitudeRad * 180.0 / .pi
        
        // Apply atmospheric refraction correction for objects near horizon
        let refraction = if altitude > -1 && altitude < 15 {
            1.02 / tan((altitude + 10.3 / (altitude + 5.11)) * .pi / 180.0) / 60.0
        } else {
            0.0
        }
        
        return altitude + refraction - 0.583 // Standard correction for moon's semidiameter and refraction
    }
    
    private static func calculateMoonPosition(julianDay: Double) -> (rightAscension: Double, declination: Double) {
        // Simplified lunar position calculation
        let T = (julianDay - 2451545.0) / 36525.0
        
        // Mean longitude of the Moon
        let L0 = normalizeAngle(218.3164477 + 481267.88123421 * T)
        
        // Mean elongation of Moon from Sun
        let D = normalizeAngle(297.8501921 + 445267.1114034 * T)
        
        // Sun's mean anomaly (not used in simplified calculation)
        let _ = normalizeAngle(357.5291092 + 35999.0502909 * T)
        
        // Moon's mean anomaly
        let Mp = normalizeAngle(134.9633964 + 477198.8675055 * T)
        
        // Argument of latitude
        let F = normalizeAngle(93.2720950 + 483202.0175233 * T)
        
        // Calculate longitude and latitude corrections (main terms)
        let longitude = L0 + 6.289 * sin(Mp * .pi / 180.0) + 1.274 * sin((2 * D - Mp) * .pi / 180.0) + 0.658 * sin(2 * D * .pi / 180.0)
        let latitude = 5.128 * sin(F * .pi / 180.0)
        
        // Convert to equatorial coordinates
        let obliquity = 23.4393 - 0.0000004 * (julianDay - 2451545.0)
        let obliquityRad = obliquity * .pi / 180.0
        let lonRad = longitude * .pi / 180.0
        let latRad = latitude * .pi / 180.0
        
        // Right ascension and declination
        let ra = atan2(sin(lonRad) * cos(obliquityRad) - tan(latRad) * sin(obliquityRad), cos(lonRad)) * 180.0 / .pi
        let dec = asin(sin(latRad) * cos(obliquityRad) + cos(latRad) * sin(obliquityRad) * sin(lonRad)) * 180.0 / .pi
        
        return (normalizeAngle(ra), dec)
    }
    
    private static func calculateLocalSiderealTime(julianDay: Double, longitude: Double) -> Double {
        // Calculate Greenwich Mean Sidereal Time
        let T = (julianDay - 2451545.0) / 36525.0
        var gmst = 280.46061837 + 360.98564736629 * (julianDay - 2451545.0) + 0.000387933 * T * T - T * T * T / 38710000.0
        
        // Normalize GMST
        gmst = normalizeAngle(gmst)
        
        // Convert to Local Sidereal Time
        let lst = normalizeAngle(gmst + longitude)
        
        return lst
    }
    
    private static func normalizeAngle(_ angle: Double) -> Double {
        var normalized = angle
        while normalized < 0 { normalized += 360 }
        while normalized >= 360 { normalized -= 360 }
        return normalized
    }
    
    private static func getMoonPhaseInfo(age: Int, illumination: Double) -> (name: String, isWaxing: Bool, nextPhase: String, daysToNext: Int) {
        switch age {
        case 0...1:
            return ("New Moon", true, "First Quarter", 7 - age)
        case 2...6:
            return ("Waxing Crescent", true, "First Quarter", 7 - age)
        case 7...8:
            return ("First Quarter", true, "Full Moon", 15 - age)
        case 9...13:
            return ("Waxing Gibbous", true, "Full Moon", 15 - age)
        case 14...16:
            return ("Full Moon", false, "Last Quarter", 22 - age)
        case 17...21:
            return ("Waning Gibbous", false, "Last Quarter", 22 - age)
        case 22...23:
            return ("Last Quarter", false, "New Moon", 30 - age)
        case 24...29:
            return ("Waning Crescent", false, "New Moon", 30 - age)
        default:
            return ("New Moon", true, "First Quarter", 7)
        }
    }
    
    private static func calculateDaysToNextFullMoon(age: Int) -> Int {
        // Full moon occurs around day 14-15 of the lunar cycle
        let fullMoonDay = 15
        
        if age < fullMoonDay {
            // We haven't reached this cycle's full moon yet
            return fullMoonDay - age
        } else {
            // Full moon has passed, calculate days to next cycle's full moon
            let daysRemainingInCycle = 30 - age
            return daysRemainingInCycle + fullMoonDay
        }
    }
}