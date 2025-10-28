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