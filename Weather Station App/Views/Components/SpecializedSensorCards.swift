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
                VStack(alignment: .leading, spacing: 8) {
                    Text("UV Index")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Text(data.solarAndUvi.uvi.value)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(SolarUVHelpers.getUVIndexColor(data.solarAndUvi.uvi.value))
                        .lineLimit(1)
                        .fixedSize()
                    Text(SolarUVHelpers.getUVIndexDescription(data.solarAndUvi.uvi.value))
                        .font(.subheadline)
                        .foregroundColor(SolarUVHelpers.getUVIndexColor(data.solarAndUvi.uvi.value))
                        .padding(.top, 2)
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
                
                // Circular gauge in the center
                CircularSolarGauge(intensity: intensityLevel, solarRadiation: solarRadiation)
                    .frame(width: 80, height: 80)
                    .position(x: centerX, y: centerY - 5)
            }
        }
    }
}

// New Circular Gauge Design
struct CircularSolarGauge: View {
    let intensity: SunStrengthIndicator.SolarIntensityLevel
    let solarRadiation: Double
    
    @State private var pulseScale: CGFloat = 1.0
    
    private var progress: Double {
        min(solarRadiation / 1200.0, 1.0)
    }
    
    private var isNighttime: Bool {
        solarRadiation == 0
    }
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(
                    isNighttime ? Color.blue.opacity(0.2) : intensity.color.opacity(0.2),
                    lineWidth: 8
                )
            
            // Progress circle (only show during daytime)
            if !isNighttime {
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                intensity.color.opacity(0.6),
                                intensity.color,
                                intensity.color.opacity(0.6)
                            ]),
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: intensity.color.opacity(0.4), radius: 4)
            }
            
            // Center content
            VStack(spacing: 2) {
                if isNighttime {
                    // Moon icon for nighttime
                    Image(systemName: "moon.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue.opacity(0.8), .blue],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: .blue.opacity(0.4), radius: 2)
                } else {
                    // Sun icon for daytime
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [intensity.color.opacity(0.8), intensity.color],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .scaleEffect(pulseScale)
                        .shadow(color: intensity.color.opacity(0.6), radius: intensity.glowRadius)
                }
                
                Text(String(format: "%.0f", solarRadiation))
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(isNighttime ? .blue : intensity.color)
            }
        }
        .onAppear {
            if !isNighttime && intensity.glowRadius > 0 {
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    pulseScale = 1.2
                }
            }
        }
        .onChange(of: intensity) { _, newIntensity in
            if !isNighttime && newIntensity.glowRadius > 0 {
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    pulseScale = 1.2
                }
            } else {
                withAnimation(.easeOut(duration: 0.3)) {
                    pulseScale = 1.0
                }
            }
        }
        .onChange(of: solarRadiation) { _, _ in
            // Reset animation when transitioning between day/night
            if isNighttime {
                withAnimation(.easeOut(duration: 0.3)) {
                    pulseScale = 1.0
                }
            } else if intensity.glowRadius > 0 {
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    pulseScale = 1.2
                }
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
                // Lightning Activity Display with Animation
                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Distance")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(MeasurementConverter.formatDistance(data.lightning.distance.value, originalUnit: data.lightning.distance.unit))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.orange)
                        Text("Count: \(data.lightning.count.value)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Animated Lightning Bolt
                    LightningBoltAnimation(
                        isActive: Int(data.lightning.count.value) ?? 0 > 0 && Double(data.lightning.distance.value) ?? 0 > 0,
                        distance: Double(data.lightning.distance.value) ?? 0,
                        count: Int(data.lightning.count.value) ?? 0
                    )
                    .frame(width: 100, height: 100)
                }
                
                Divider()
                
                // Last Lightning Detection with update time (Change 1)
                LastLightningDetectionView(
                    getLastLightningStats: getLastLightningStats,
                    lastUpdateTime: data.lightning.distance.lastUpdateTime
                )
            }
        }
    }
}

struct LightningBoltAnimation: View {
    let isActive: Bool
    let distance: Double
    let count: Int
    
    @State private var flashOpacity: Double = 0.0
    @State private var pulseScale: CGFloat = 1.0
    @State private var rotationAngle: Double = 0
    
    private var safetyColor: Color {
        switch distance {
        case 0...5: return .red
        case 5...10: return .orange
        case 10...20: return .yellow
        default: return .green
        }
    }
    
    private var safetyLevel: String {
        switch distance {
        case 0...5: return "Danger"
        case 5...10: return "Warning"
        case 10...20: return "Caution"
        default: return "Safe"
        }
    }
    
    var body: some View {
        ZStack {
            // Background circle with safety rings
            ForEach([40.0, 30.0, 20.0, 10.0], id: \.self) { ringDistance in
                Circle()
                    .stroke(getRingColor(for: ringDistance).opacity(0.2), lineWidth: 1)
                    .frame(width: getRingSize(for: ringDistance), height: getRingSize(for: ringDistance))
            }
            
            // Center station indicator
            Circle()
                .fill(.blue)
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .stroke(.blue.opacity(0.3), lineWidth: 2)
                        .frame(width: 12, height: 12)
                )
            
            if isActive {
                // Lightning strike indicator at distance
                let boltSize = min(distance / 40.0 * 80, 80.0)
                
                ZStack {
                    // Glow effect
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    safetyColor.opacity(0.4),
                                    safetyColor.opacity(0.1),
                                    .clear
                                ]),
                                center: .center,
                                startRadius: 0,
                                endRadius: 20
                            )
                        )
                        .frame(width: 40, height: 40)
                        .scaleEffect(pulseScale)
                    
                    // Lightning bolt icon
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.yellow, safetyColor],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: .yellow.opacity(0.8), radius: 4)
                        .opacity(flashOpacity)
                    
                    // Multiple bolt strikes for high count
                    if count > 3 {
                        ForEach(0..<min(count - 1, 3), id: \.self) { index in
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 16))
                                .foregroundColor(safetyColor.opacity(0.6))
                                .offset(x: CGFloat(index - 1) * 15)
                                .opacity(flashOpacity * 0.7)
                        }
                    }
                }
                .offset(x: boltSize * 0.4, y: -boltSize * 0.4)
            } else {
                // No activity - show calm weather icon
                VStack(spacing: 4) {
                    Image(systemName: "cloud.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.gray.opacity(0.5))
                    
                    Text("No Activity")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // Safety status label at bottom
            if isActive {
                VStack {
                    Spacer()
                    Text(safetyLevel)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(safetyColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(safetyColor.opacity(0.2))
                        )
                }
                .frame(height: 100)
            }
        }
        .onAppear {
            if isActive {
                startAnimations()
            }
        }
        .onChange(of: isActive) { _, newValue in
            if newValue {
                startAnimations()
            } else {
                stopAnimations()
            }
        }
        .onChange(of: count) { _, _ in
            if isActive {
                startAnimations()
            }
        }
    }
    
    private func getRingColor(for distance: Double) -> Color {
        switch distance {
        case 0...5: return .red
        case 5...10: return .orange
        case 10...20: return .yellow
        default: return .green
        }
    }
    
    private func getRingSize(for distance: Double) -> CGFloat {
        return CGFloat(distance / 40.0 * 80)
    }
    
    private func startAnimations() {
        // Flash animation
        withAnimation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true)) {
            flashOpacity = 1.0
        }
        
        // Pulse animation
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            pulseScale = 1.3
        }
    }
    
    private func stopAnimations() {
        withAnimation(.easeOut(duration: 0.3)) {
            flashOpacity = 0.0
            pulseScale = 1.0
        }
    }
}

struct LastLightningDetectionView: View {
    let getLastLightningStats: () -> LastLightningStats?
    let lastUpdateTime: Date?
    
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
                
                // Add API last update time (Change 1)
                if let lastUpdate = lastUpdateTime {
                    HStack {
                        Image(systemName: "arrow.clockwise.circle.fill")
                            .foregroundColor(.blue)
                            .font(.caption)
                        Text("Data updated: \(formatRelativeTime(lastUpdate))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
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
                
                // Add API last update time even when no lightning detected (Change 1)
                if let lastUpdate = lastUpdateTime {
                    HStack {
                        Image(systemName: "arrow.clockwise.circle.fill")
                            .foregroundColor(.blue)
                            .font(.caption)
                        Text("Data updated: \(formatRelativeTime(lastUpdate))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    private func formatRelativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
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
                // Last update time at the top (Change 1)
                if let lastUpdate = getLastUpdateTime() {
                    HStack {
                        Image(systemName: "clock.fill")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("Last updated: \(formatRelativeTime(lastUpdate))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 4)
                }
                
                // System Health Overview (Traffic Light Dashboard) - Enhanced with Device Status (Change 2)
                BatteryHealthDashboard(data: data, deviceStatus: data.deviceStatus)
                
                Divider()
                
                BatteryMainSystemsView(data: data)
                Divider()
                BatterySensorSystemsView(data: data)
            }
            .font(.caption)
        }
    }
    
    // Helper to get the most recent last update time from battery data
    private func getLastUpdateTime() -> Date? {
        let batteries = [
            data.battery.console,
            data.battery.hapticArrayBattery,
            data.battery.hapticArrayCapacitor,
            data.battery.lightningSensor,
            data.battery.rainfallSensor,
            data.battery.pm25SensorCh1,
            data.battery.pm25SensorCh2,
            data.battery.tempHumiditySensorCh1,
            data.battery.tempHumiditySensorCh2,
            data.battery.tempHumiditySensorCh3
        ]
        
        let updateTimes = batteries.compactMap { $0?.lastUpdateTime }
        return updateTimes.max()
    }
    
    private func formatRelativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct BatteryHealthDashboard: View {
    let data: WeatherStationData
    let deviceStatus: DeviceStatus?
    
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
            // Device Status Banner (Change 2: Device Status Data)
            if let status = deviceStatus {
                HStack(spacing: 8) {
                    // Online/Offline status
                    HStack(spacing: 4) {
                        Image(systemName: status.isOnline ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                            .foregroundColor(status.isOnline ? .green : .red)
                            .font(.caption)
                        Text(status.isOnline ? "Online" : "Offline")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(status.isOnline ? .green : .red)
                    }
                    
                    // Signal strength
                    if let signalStrength = status.signalStrength {
                        Divider()
                            .frame(height: 12)
                        HStack(spacing: 4) {
                            Image(systemName: signalIcon(for: signalStrength))
                                .foregroundColor(signalColor(signalStrength))
                                .font(.caption)
                            Text("\(signalStrength)%")
                                .font(.caption)
                                .foregroundColor(signalColor(signalStrength))
                        }
                    }
                    
                    // Firmware version
                    if let firmware = status.firmwareVersion {
                        Divider()
                            .frame(height: 12)
                        HStack(spacing: 4) {
                            Image(systemName: "gear")
                                .foregroundColor(.secondary)
                                .font(.caption2)
                            Text("v\(firmware)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Last communication
                    if let lastComm = status.lastCommunication {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.blue)
                                .font(.caption2)
                            Text(formatRelativeTime(lastComm))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(status.isOnline ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                )
            }
            
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
    
    private func signalColor(_ strength: Int) -> Color {
        switch strength {
        case 75...100: return .green
        case 50..<75: return .yellow
        case 25..<50: return .orange
        default: return .red
        }
    }
    
    private func signalIcon(for strength: Int) -> String {
        switch strength {
        case 75...100: return "wifi"
        case 50..<75: return "wifi.exclamationmark"
        case 25..<50: return "wifi.slash"
        default: return "wifi.slash"
        }
    }
    
    private func formatRelativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
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
                    // Use API description if available (Change 3)
                    if let description = console.description {
                        Text(description)
                            .fontWeight(.semibold)
                    } else {
                        Text("\(console.value) \(console.unit)")
                            .fontWeight(.semibold)
                    }
                }
            }
            
            if let haptic = data.battery.hapticArrayBattery {
                HStack {
                    BatteryHealthIndicator(value: haptic.value)
                    Text("Haptic Array:")
                    Spacer()
                    // Use API description if available (Change 3)
                    if let description = haptic.description {
                        Text(description)
                            .fontWeight(.semibold)
                    } else {
                        Text("\(haptic.value) \(haptic.unit)")
                            .fontWeight(.semibold)
                    }
                }
            }
            
            // Haptic Capacitor - moved up for better visibility
            if let hapticCap = data.battery.hapticArrayCapacitor {
                HStack {
                    BatteryHealthIndicator(value: hapticCap.value)
                    Text("Haptic Capacitor:")
                    Spacer()
                    // Use API description if available (Change 3)
                    if let description = hapticCap.description {
                        Text(description)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    } else {
                        Text("\(hapticCap.value) \(hapticCap.unit)")
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    }
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
                    // Use API description if available (Change 3)
                    if let description = lightning.description {
                        Text(description)
                            .fontWeight(.semibold)
                    } else {
                        Text(WeatherStatusHelpers.batteryLevelText(lightning.value))
                    }
                }
            }
            
            if let rainfall = data.battery.rainfallSensor {
                HStack {
                    BatteryHealthIndicator(value: rainfall.value)
                    Text("Rainfall Sensor:")
                    Spacer()
                    // Use API description if available (Change 3)
                    if let description = rainfall.description {
                        Text(description)
                            .fontWeight(.semibold)
                    } else {
                        Text("\(rainfall.value) \(rainfall.unit)")
                    }
                }
            }
            
            if let pm25Ch1 = data.battery.pm25SensorCh1 {
                HStack {
                    BatteryHealthIndicator(value: pm25Ch1.value)
                    Text("PM2.5 Ch1:")
                    Spacer()
                    // Use API description if available (Change 3)
                    if let description = pm25Ch1.description {
                        Text(description)
                            .fontWeight(.semibold)
                    } else {
                        Text(WeatherStatusHelpers.batteryLevelText(pm25Ch1.value))
                    }
                }
            }
            
            if let pm25Ch2 = data.battery.pm25SensorCh2 {
                HStack {
                    BatteryHealthIndicator(value: pm25Ch2.value)
                    Text("PM2.5 Ch2:")
                    Spacer()
                    // Use API description if available (Change 3)
                    if let description = pm25Ch2.description {
                        Text(description)
                            .fontWeight(.semibold)
                    } else {
                        Text(WeatherStatusHelpers.batteryLevelText(pm25Ch2.value))
                    }
                }
            }
            
            if let th1 = data.battery.tempHumiditySensorCh1 {
                HStack {
                    BatteryHealthIndicator(value: th1.value)
                    Text("Temp/Humidity Ch1:")
                    Spacer()
                    // Use API description if available (Change 3)
                    if let description = th1.description {
                        Text(description)
                            .fontWeight(.semibold)
                    } else {
                        Text(WeatherStatusHelpers.tempHumidityBatteryStatusText(th1.value))
                    }
                }
            }
            
            if let th2 = data.battery.tempHumiditySensorCh2 {
                HStack {
                    BatteryHealthIndicator(value: th2.value)
                    Text("Temp/Humidity Ch2:")
                    Spacer()
                    // Use API description if available (Change 3)
                    if let description = th2.description {
                        Text(description)
                            .fontWeight(.semibold)
                    } else {
                        Text(WeatherStatusHelpers.tempHumidityBatteryStatusText(th2.value))
                    }
                }
            }
            
            if let th3 = data.battery.tempHumiditySensorCh3 {
                HStack {
                    BatteryHealthIndicator(value: th3.value)
                    Text("Temp/Humidity Ch3:")
                    Spacer()
                    // Use API description if available (Change 3)
                    if let description = th3.description {
                        Text(description)
                            .fontWeight(.semibold)
                    } else {
                        Text(WeatherStatusHelpers.tempHumidityBatteryStatusText(th3.value))
                    }
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
        // Handle voltage values (like console, haptic array, rainfall sensor)
        if value.contains(".") || value.contains("V") {
            let numericValue = Double(value.replacingOccurrences(of: "V", with: "")) ?? 0
            
            // Check if this is likely a single-battery sensor (like rainfall sensor)
            // Single 1.5V battery sensors typically show values between 1.0V - 1.8V
            if numericValue >= 1.0 && numericValue <= 2.0 {
                // Single 1.5V battery thresholds
                if numericValue >= 1.4 {
                    return BatteryHealth(level: .healthy, color: .green, description: "Good")
                } else if numericValue >= 1.2 {
                    return BatteryHealth(level: .warning, color: .orange, description: "Low")
                } else {
                    return BatteryHealth(level: .critical, color: .red, description: "Critical")
                }
            } else {
                // Multi-battery or higher voltage sensors (console, haptic array, etc.)
                if numericValue >= 3.0 {
                    return BatteryHealth(level: .healthy, color: .green, description: "Good")
                } else if numericValue >= 2.5 {
                    return BatteryHealth(level: .warning, color: .orange, description: "Low")
                } else {
                    return BatteryHealth(level: .critical, color: .red, description: "Critical")
                }
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
    
    @State private var currentTime = Date()
    
    // Computed property for day length difference calculation
    private var tomorrowDayLengthDifference: (changeText: String, changeColor: Color)? {
        guard let latitude = station.latitude, let longitude = station.longitude else { return nil }
        
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        
        guard let tomorrowSunTimes = SunCalculator.calculateSunTimes(for: tomorrow, latitude: latitude, longitude: longitude, timeZone: station.timeZone) else { return nil }
        
        // Day length difference calculation
        let todayLength = sunTimes.sunset.timeIntervalSince(sunTimes.sunrise)
        let tomorrowLength = tomorrowSunTimes.sunset.timeIntervalSince(tomorrowSunTimes.sunrise)
        let difference = tomorrowLength - todayLength
        let diffMinutes = Int(difference / 60)
        let diffSeconds = Int(difference.truncatingRemainder(dividingBy: 60))
        
        let changeText: String
        let changeColor: Color
        
        if abs(diffMinutes) > 0 {
            if diffMinutes > 0 {
                changeText = "+\(diffMinutes)m \(abs(diffSeconds))s"
                changeColor = .green
            } else {
                changeText = "\(diffMinutes)m \(abs(diffSeconds))s"
                changeColor = .orange
            }
        } else {
            if diffSeconds > 0 {
                changeText = "+\(diffSeconds)s"
                changeColor = .green
            } else if diffSeconds < 0 {
                changeText = "\(diffSeconds)s"
                changeColor = .orange
            } else {
                changeText = "Same"
                changeColor = .secondary
            }
        }
        
        return (changeText, changeColor)
    }
    
    // Computed property for live daylight countdown
    private var liveDaylightLeft: String {
        if currentTime >= sunTimes.sunrise && currentTime <= sunTimes.sunset {
            let remaining = sunTimes.sunset.timeIntervalSince(currentTime)
            let hours = Int(remaining / 3600)
            let minutes = Int((remaining.truncatingRemainder(dividingBy: 3600)) / 60)
            let seconds = Int(remaining.truncatingRemainder(dividingBy: 60))
            
            if hours > 0 {
                return String(format: "%dh %02dm %02ds", hours, minutes, seconds)
            } else {
                return String(format: "%dm %02ds", minutes, seconds)
            }
        } else {
            return "Nighttime"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) { 
            // Current status
            HStack {
                Image(systemName: sunTimes.isCurrentlyDaylight ? "sun.max.fill" : "moon.fill")
                    .foregroundColor(sunTimes.isCurrentlyDaylight ? .orange : .blue)
                Text(sunTimes.isCurrentlyDaylight ? "Daylight" : "Nighttime")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            // Sun Position Arc - Enhanced version
            SunPositionArc(sunTimes: sunTimes, currentTime: currentTime)
                .frame(height: 120) 
                .padding(.vertical, 8) 
            
            // Sunrise and sunset times
            HStack {
                VStack(alignment: .leading, spacing: 2) { 
                    HStack {
                        Image(systemName: "sunrise.fill")
                            .foregroundColor(.orange)
                        Text("Sunrise")
                            .font(.caption) 
                            .foregroundColor(.secondary)
                    }
                    Text(sunTimes.formattedSunrise)
                        .font(.title3) 
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                // Timezone abbreviation in the center
                Text(getCurrentTimeZoneAbbreviation())
                    .font(.caption2) 
                    .foregroundColor(.secondary)
                    .italic()
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) { 
                    HStack {
                        Text("Sunset")
                            .font(.caption) 
                            .foregroundColor(.secondary)
                        Image(systemName: "sunset.fill")
                            .foregroundColor(.red)
                            .font(.caption) 
                    }
                    Text(sunTimes.formattedSunset)
                        .font(.title3) 
                        .fontWeight(.bold)
                }
            }
            
            // Day length and daylight left in compact rows
            VStack(spacing: 3) { 
                HStack {
                    Text("Day Length:")
                        .font(.caption) 
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(sunTimes.formattedDayLength)
                        .font(.caption) 
                        .fontWeight(.semibold)
                }
                
                HStack {
                    Text("Daylight Left:")
                        .font(.caption) 
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(liveDaylightLeft)
                        .font(.caption) 
                        .fontWeight(.semibold)
                        .foregroundColor(currentTime >= sunTimes.sunrise && currentTime <= sunTimes.sunset ? .orange : .secondary)
                        .monospacedDigit()
                }
            }
            
            // Tomorrow's sunrise and sunset
            if let latitude = station.latitude, let longitude = station.longitude {
                let calendar = Calendar.current
                let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
                
                if let tomorrowSunTimes = SunCalculator.calculateSunTimes(for: tomorrow, latitude: latitude, longitude: longitude, timeZone: station.timeZone) {
                    Divider()
                        .padding(.vertical, 2) 
            
                    VStack(alignment: .leading, spacing: 6) { 
                        Text("Tomorrow")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fontWeight(.semibold)
                        
                        // Sunrise and sunset times in a clean row
                        HStack(spacing: 12) {
                            HStack(spacing: 4) {
                                Image(systemName: "sunrise.fill")
                                    .foregroundColor(.orange)
                                    .font(.caption2)
                                Text("Sunrise")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text(tomorrowSunTimes.formattedSunrise)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                            
                            Spacer()
                            
                            HStack(spacing: 4) {
                                Image(systemName: "sunset.fill")
                                    .foregroundColor(.red)
                                    .font(.caption2)
                                Text("Sunset")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text(tomorrowSunTimes.formattedSunset)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                        }
                        
                        // Day length and difference in a separate clean row
                        HStack(spacing: 8) {
                            Text("Day Length:")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(tomorrowSunTimes.formattedDayLength)
                                .font(.caption)
                                .fontWeight(.semibold)
                            
                            Spacer()
                            
                            if let diff = tomorrowDayLengthDifference {
                                Text(diff.changeText)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(diff.changeColor)
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            startTimer()
        }
    }
    
    private func startTimer() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            currentTime = Date()
        }
    }
    
    // Helper function to format time in the correct timezone
    private func formatTimeInTimeZone(_ date: Date, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.timeZone = timeZone
        return formatter.string(from: date)
    }
    
    private func getCurrentTimeZoneAbbreviation() -> String {
        // Get the current timezone abbreviation accounting for daylight saving
        return station.timeZone.abbreviation(for: Date()) ?? "Local"
    }
}

struct SunPositionArc: View {
    let sunTimes: SunTimes
    let currentTime: Date
    
    private var sunPosition: CGFloat {
        if currentTime < sunTimes.sunrise {
            return 0 
        } else if currentTime > sunTimes.sunset {
            return 1 
        } else {
            let totalDaylight = sunTimes.sunset.timeIntervalSince(sunTimes.sunrise)
            let timeSinceSunrise = currentTime.timeIntervalSince(sunTimes.sunrise)
            return CGFloat(timeSinceSunrise / totalDaylight)
        }
    }
    
    private var isDaytime: Bool {
        return currentTime >= sunTimes.sunrise && currentTime <= sunTimes.sunset
    }
    
    // Get color for a specific position along the arc (0 to 1)
    private func arcColor(at position: CGFloat) -> Color {
        if !isDaytime {
            return Color.purple.opacity(0.6)
        }
        
        // Color transitions based on sun position
        if position < sunPosition {
            // Before current sun position - use gradient from purple/pink to orange/yellow
            let relativePosition = position / sunPosition
            if relativePosition < 0.5 {
                // Early morning - purple/pink
                return Color.purple.opacity(0.6)
            } else {
                // Approaching current time - transition to orange
                return Color.orange.opacity(0.7)
            }
        } else {
            // After current sun position - lighter/grayed out
            return Color.gray.opacity(0.4)
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let padding: CGFloat = 40 // Padding from edges
            let arcWidth = width - (padding * 2)
            let arcHeight = height * 0.7 // Height of the arc
            let baseY = height * 0.85 // Base line Y position
            
            ZStack {
                // Full dashed arc path (background)
                Path { path in
                    path.move(to: CGPoint(x: padding, y: baseY))
                    path.addQuadCurve(
                        to: CGPoint(x: width - padding, y: baseY),
                        control: CGPoint(x: width / 2, y: baseY - arcHeight)
                    )
                }
                .stroke(
                    Color.gray.opacity(0.3),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [8, 6])
                )
                
                // Colored portion of arc (from sunrise to current position)
                if isDaytime {
                    Path { path in
                        let endX = padding + (arcWidth * sunPosition)
                        
                        path.move(to: CGPoint(x: padding, y: baseY))
                        
                        // Calculate end point on the arc
                        let endProgress = sunPosition
                        let arcEndY = baseY - (arcHeight * sin(.pi * endProgress))
                        
                        path.addQuadCurve(
                            to: CGPoint(x: endX, y: arcEndY),
                            control: CGPoint(x: width / 2, y: baseY - arcHeight)
                        )
                    }
                    .trim(from: 0, to: sunPosition)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.6, green: 0.3, blue: 0.8).opacity(0.8), // Purple
                                Color(red: 0.8, green: 0.4, blue: 0.6).opacity(0.8), // Pink
                                Color.orange.opacity(0.9), // Orange
                                Color.yellow.opacity(0.9) // Yellow
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [8, 6])
                    )
                }
                
                // Calculate sun position on arc
                let sunX = padding + (arcWidth * sunPosition)
                let sunY = baseY - (arcHeight * sin(.pi * sunPosition))
                
                // Sun icon with glow
                ZStack {
                    // Outer glow
                    if isDaytime {
                        Circle()
                            .fill(
                                RadialGradient(
                                    gradient: Gradient(colors: [
                                        Color.orange.opacity(0.4),
                                        Color.orange.opacity(0.2),
                                        Color.clear
                                    ]),
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 20
                                )
                            )
                            .frame(width: 40, height: 40)
                    }
                    
                    // Sun circle with texture
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 1.0, green: 0.9, blue: 0.6),
                                    Color.orange
                                ]),
                                center: .center,
                                startRadius: 0,
                                endRadius: 12
                            )
                        )
                        .frame(width: 24, height: 24)
                        .overlay(
                            Circle()
                                .fill(Color.white.opacity(0.4))
                                .frame(width: 10, height: 10)
                                .offset(x: -4, y: -4)
                        )
                        .shadow(color: .orange.opacity(0.6), radius: 6)
                }
                .position(x: sunX, y: sunY)
                
                // Moon icon (top right, only shown at night or near sunset)
                if !isDaytime || sunPosition > 0.8 {
                    Image(systemName: "moon.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.gray.opacity(0.6))
                        .position(x: width - 30, y: 20)
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
            HStack(spacing: 16) {
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
                    
                    Text(moonPhase.emoji)
                        .font(.title)
                }
                
                Spacer()
            }
            
            Divider()
            
            if let moonTimes = moonTimes {
                MoonTimesView(moonTimes: moonTimes, timeZone: timeZone)
            } else {
                Text("Moon times unavailable")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
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
                Circle()
                    .fill(.gray.opacity(0.2))
                    .frame(width: size, height: size)
                
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
                if illumination <= 0.01 {
                } else if illumination >= 0.99 {
                    path.addEllipse(in: CGRect(x: 0, y: 0, width: size, height: size))
                } else if illumination == 0.5 {
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
                    path.move(to: CGPoint(x: center.x, y: 0))
                    
                    let ellipseWidth = size * (1 - 2 * illumination)
                    if isWaxing {
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
                        path.addEllipse(in: CGRect(x: 0, y: 0, width: size, height: size))
                        let ellipseWidth = size * (2 * (1 - illumination))
                        path.addEllipse(in: CGRect(
                            x: size - center.x - ellipseWidth / 2,
                            y: 0,
                            width: ellipseWidth,
                            height: size
                        ))
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
                
                Text(getCurrentTimeZoneAbbreviation())
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
                
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
        }
    }
    
    private func formatTimeInTimeZone(_ date: Date, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.timeZone = timeZone
        return formatter.string(from: date)
    }
    
    private func getCurrentTimeZoneAbbreviation() -> String {
        return timeZone.abbreviation(for: Date()) ?? "Local"
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
            
            if currentPhase.nextPhaseName != "Full Moon" {
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
    let illumination: Double 
    let age: Int 
    let isWaxing: Bool
    let nextPhaseName: String
    let daysToNextPhase: Int
    let daysToNextFullMoon: Int
    
    // MARK: - Moon Phase Emoji
    
    /// Returns the appropriate moon phase emoji based on the current phase
    var emoji: String {
        // Moon phase emojis based on age (0-29 days)
        switch age {
        case 0...1:
            return "🌑" // New Moon
        case 2...6:
            return "🌒" // Waxing Crescent
        case 7...8:
            return "🌓" // First Quarter
        case 9...13:
            return "🌔" // Waxing Gibbous
        case 14...15:
            return "🌕" // Full Moon
        case 16...20:
            return "🌖" // Waning Gibbous
        case 21...22:
            return "🌗" // Last Quarter
        case 23...28:
            return "🌘" // Waning Crescent
        default:
            return "🌑" // New Moon (for day 29+)
        }
    }
}

struct MoonTimes {
    let moonrise: Date?
    let moonset: Date?
}

class MoonCalculator {
    
    static func getCurrentMoonPhase(for date: Date, timeZone: TimeZone = .current) -> MoonPhase {
        let julianDay = dateToJulianDay(date)
        
        let phase = calculateMoonPhase(julianDay: julianDay)
        let illumination = 0.5 * (1 - cos(2 * .pi * phase))
        
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
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        
        let startOfDay = calendar.startOfDay(for: date)
        var moonrise: Date?
        var moonset: Date?
        var previousAltitude: Double?
        
        print(" Calculating moon times for date: \(date)")
        print(" Start of day in timezone: \(startOfDay)")
        print(" Latitude: \(latitude), Longitude: \(longitude)")
        print(" TimeZone: \(timeZone.identifier)")
        
        for halfHour in 0..<48 {
            let currentTime = startOfDay.addingTimeInterval(Double(halfHour) * 1800) // 1800 seconds (30 minutes) 
            let currentAltitude = calculateMoonAltitude(for: currentTime, latitude: latitude, longitude: longitude, timeZone: timeZone)
            
            if let prevAlt = previousAltitude {
                if prevAlt < 0 && currentAltitude >= 0 && moonrise == nil {
                    let ratio = -prevAlt / (currentAltitude - prevAlt)
                    moonrise = currentTime.addingTimeInterval(-1800 + ratio * 1800)
                    print(" Found moonrise at: \(moonrise!)")
                }
                
                if prevAlt >= 0 && currentAltitude < 0 && moonset == nil {
                    let ratio = -prevAlt / (currentAltitude - prevAlt)
                    moonset = currentTime.addingTimeInterval(-1800 + ratio * 1800)
                    print(" Found moonset at: \(moonset!)")
                }
            }
            
            previousAltitude = currentAltitude
            
            if halfHour % 4 == 0 { 
                let formatter = DateFormatter()
                formatter.timeStyle = .short
                formatter.timeZone = timeZone
                print(" \(formatter.string(from: currentTime)): Moon altitude = \(String(format: "%.2f", currentAltitude))°")
            }
        }
        
        return MoonTimes(moonrise: moonrise, moonset: moonset)
    }
    
    private static func dateToJulianDay(_ date: Date) -> Double {
        let timeInterval = date.timeIntervalSince1970
        let julianDay = (timeInterval / 86400.0) + 2440587.5
        return julianDay
    }
    
    private static func calculateMoonPhase(julianDay: Double) -> Double {
        let newMoonReference = 2451550.1  
        let lunarCycle = 29.53058867      
        
        let daysSinceNewMoon = julianDay - newMoonReference
        let cyclesSinceNewMoon = daysSinceNewMoon / lunarCycle
        let phasePosition = cyclesSinceNewMoon - floor(cyclesSinceNewMoon)
        
        return phasePosition
    }
    
    private static func calculateMoonAltitude(for date: Date, latitude: Double, longitude: Double, timeZone: TimeZone) -> Double {
        let utcDate = date
        let julianDay = dateToJulianDay(utcDate)
        
        let moonPosition = calculateMoonPosition(julianDay: julianDay)
        
        let lst = calculateLocalSiderealTime(julianDay: julianDay, longitude: longitude)
        
        // Calculate hour angle (in degrees)
        var hourAngle = lst - moonPosition.rightAscension
        
        // Normalize hour angle to [-180, 180] range
        while hourAngle > 180 { hourAngle -= 360 }
        while hourAngle < -180 { hourAngle += 360 }
        
        let latRad = latitude * .pi / 180.0
        let decRad = moonPosition.declination * .pi / 180.0
        let haRad = hourAngle * .pi / 180.0
        
        let sinAlt = sin(latRad) * sin(decRad) + cos(latRad) * cos(decRad) * cos(haRad)
        let altitudeRad = asin(max(-1.0, min(1.0, sinAlt))) // asin expects value between -1 and 1
        let altitude = altitudeRad * 180.0 / .pi
        
        let refraction = if altitude > -1 && altitude < 15 {
            1.02 / tan((altitude + 10.3 / (altitude + 5.11)) * .pi / 180.0) / 60.0
        } else {
            0.0
        }
        
        return altitude + refraction - 0.583 // correct for refraction at low altitudes and 0.583 offset
    }
    
    private static func calculateMoonPosition(julianDay: Double) -> (rightAscension: Double, declination: Double) {
        let T = (julianDay - 2451545.0) / 36525.0
        
        let L0 = normalizeAngle(218.3164477 + 481267.88123421 * T)
        
        let D = normalizeAngle(297.8501921 + 445267.1114034 * T)
        
        let _ = normalizeAngle(357.5291092 + 35999.0502909 * T)
        
        let Mp = normalizeAngle(134.9633964 + 477198.8675055 * T)
        
        let F = normalizeAngle(93.2720950 + 483202.0175233 * T)
        
        let longitude = L0 + 6.289 * sin(Mp * .pi / 180.0) + 1.274 * sin((2 * D - Mp) * .pi / 180.0) + 0.658 * sin(2 * D * .pi / 180.0)
        let latitude = 5.128 * sin(F * .pi / 180.0)
        
        let obliquity = 23.4393 - 0.0000004 * (julianDay - 2451545.0)
        let obliquityRad = obliquity * .pi / 180.0
        let lonRad = longitude * .pi / 180.0
        let latRad = latitude * .pi / 180.0
        
        let ra = atan2(sin(lonRad) * cos(obliquityRad) - tan(latRad) * sin(obliquityRad), cos(lonRad)) * 180.0 / .pi
        let dec = asin(sin(latRad) * cos(obliquityRad) + cos(latRad) * sin(obliquityRad) * sin(lonRad)) * 180.0 / .pi
        
        return (normalizeAngle(ra), dec)
    }
    
    private static func calculateLocalSiderealTime(julianDay: Double, longitude: Double) -> Double {
        let T = (julianDay - 2451545.0) / 36525.0
        let gmst = 280.46061837 + 360.98564736629 * (julianDay - 2451545.0) + 0.000387933 * T * T - T * T * T / 38710000.0
        
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
        let fullMoonDay = 15
        
        if age < fullMoonDay {
            return fullMoonDay - age
        } else {
            let daysRemainingInCycle = 30 - age
            return daysRemainingInCycle + fullMoonDay
        }
    }
}
