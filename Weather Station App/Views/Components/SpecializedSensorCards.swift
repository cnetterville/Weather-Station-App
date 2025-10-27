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
            VStack(alignment: .leading, spacing: 4) {
                BatteryMainSystemsView(data: data)
                Divider()
                BatterySensorSystemsView(data: data)
            }
            .font(.caption)
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
                    Text("Console:")
                    Spacer()
                    Text("\(console.value) \(console.unit)")
                        .fontWeight(.semibold)
                }
            }
            
            if let haptic = data.battery.hapticArrayBattery {
                HStack {
                    Text("Haptic Array:")
                    Spacer()
                    Text("\(haptic.value) \(haptic.unit)")
                        .fontWeight(.semibold)
                }
            }
            
            // Haptic Capacitor - moved up for better visibility
            if let hapticCap = data.battery.hapticArrayCapacitor {
                HStack {
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
                    Text("Lightning Sensor:")
                    Spacer()
                    Text(WeatherStatusHelpers.batteryLevelText(lightning.value))
                }
            }
            
            if let rainfall = data.battery.rainfallSensor {
                HStack {
                    Text("Rainfall Sensor:")
                    Spacer()
                    Text("\(rainfall.value) \(rainfall.unit)")
                }
            }
            
            if let pm25Ch1 = data.battery.pm25SensorCh1 {
                HStack {
                    Text("PM2.5 Ch1:")
                    Spacer()
                    Text(WeatherStatusHelpers.batteryLevelText(pm25Ch1.value))
                }
            }
            
            if let pm25Ch2 = data.battery.pm25SensorCh2 {
                HStack {
                    Text("PM2.5 Ch2:")
                    Spacer()
                    Text(WeatherStatusHelpers.batteryLevelText(pm25Ch2.value))
                }
            }
            
            if let th1 = data.battery.tempHumiditySensorCh1 {
                HStack {
                    Text("Temp/Humidity Ch1:")
                    Spacer()
                    Text(WeatherStatusHelpers.tempHumidityBatteryStatusText(th1.value))
                }
            }
            
            if let th2 = data.battery.tempHumiditySensorCh2 {
                HStack {
                    Text("Temp/Humidity Ch2:")
                    Spacer()
                    Text(WeatherStatusHelpers.tempHumidityBatteryStatusText(th2.value))
                }
            }
            
            if let th3 = data.battery.tempHumiditySensorCh3 {
                HStack {
                    Text("Temp/Humidity Ch3:")
                    Spacer()
                    Text(WeatherStatusHelpers.tempHumidityBatteryStatusText(th3.value))
                }
            }
        }
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
            
            Divider()
            
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