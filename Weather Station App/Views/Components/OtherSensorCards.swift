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
    
    var body: some View {
        EditableWeatherCard(
            title: .constant(station.customLabels.pressure),
            systemImage: "barometer",
            onTitleChange: onTitleChange
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Text("\(data.pressure.relative.value) \(data.pressure.relative.unit)")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Text("Absolute: \(data.pressure.absolute.value) \(data.pressure.absolute.unit)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
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
    
    var body: some View {
        EditableWeatherCard(
            title: .constant(title),
            systemImage: systemImage,
            onTitleChange: onTitleChange
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Text("\(data.pm25.value) \(data.pm25.unit)")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Text("AQI: \(data.realTimeAqi.value)")
                    .font(.subheadline)
                    .foregroundColor(WeatherStatusHelpers.aqiColor(for: data.realTimeAqi.value))
            }
        }
    }
}