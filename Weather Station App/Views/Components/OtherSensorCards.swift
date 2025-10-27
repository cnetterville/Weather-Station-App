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
                // Current Wind Speed - Larger, more prominent
                HStack {
                    VStack(alignment: .leading) {
                        Text("Speed")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(MeasurementConverter.formatWindSpeed(data.wind.windSpeed.value, originalUnit: data.wind.windSpeed.unit))
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                    }
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
                let beaufortScale = WindHelpers.getBeaufortScale(windSpeedMph: windSpeedValue)
                HStack {
                    Text("Beaufort Scale:")
                        .font(.subheadline)
                    Spacer()
                    Text("\(beaufortScale.number) - \(beaufortScale.description)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
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
            title: .constant(station.customLabels.rainfall),
            systemImage: "cloud.rain.fill",
            onTitleChange: onTitleChange
        ) {
            let rainfallData = data.rainfallPiezo
            VStack(alignment: .leading, spacing: 4) {
                // Rain Status
                HStack {
                    Text("Status:")
                    Spacer()
                    Text(WeatherStatusHelpers.rainStatusText(rainfallData.state.value))
                        .fontWeight(.semibold)
                        .foregroundColor(WeatherStatusHelpers.rainStatusColor(rainfallData.state.value))
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
                Text(MeasurementConverter.formatRainRate(rainfallData.rainRate.value, originalUnit: rainfallData.rainRate.unit))
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