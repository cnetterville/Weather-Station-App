//
//  WeatherStationDetailView.swift
//  Weather Station App
//
//  Created by Curtis Netterville on 10/25/25.
//

import SwiftUI

struct WeatherStationDetailView: View {
    @Binding var station: WeatherStation
    let weatherData: WeatherStationData?
    @StateObject private var weatherService = WeatherStationService.shared
    
    @State private var showingHistory = false
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 16) {
                    // Station Information Card
                    StationInfoCard(station: station)
                    
                    if let data = weatherData {
                        let columns = calculateColumns(for: geometry.size.width)
                        let tileSize = calculateTileSize(for: geometry.size.width, columns: columns)
                        LazyVGrid(columns: Array(repeating: GridItem(.fixed(tileSize), spacing: 16), count: columns), spacing: 16) {
                            
                            // TEMPERATURE SENSORS SECTION - All grouped together
                            // Outdoor Temperature Card with Daily High/Low
                            if station.sensorPreferences.showOutdoorTemp {
                                EditableWeatherCard(
                                    title: .constant(station.customLabels.outdoorTemp),
                                    systemImage: "thermometer",
                                    onTitleChange: { newTitle in
                                        station.customLabels.outdoorTemp = newTitle
                                        saveStation()
                                    }
                                ) {
                                    VStack(alignment: .leading, spacing: 12) {
                                        // Current Temperature - Main Display
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(TemperatureConverter.formatTemperature(data.outdoor.temperature.value, originalUnit: data.outdoor.temperature.unit))
                                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                            HStack(spacing: 12) {
                                                Text("Feels like \(TemperatureConverter.formatTemperature(data.outdoor.feelsLike.value, originalUnit: data.outdoor.feelsLike.unit))")
                                                    .font(.subheadline)
                                                    .foregroundColor(.secondary)
                                                
                                                // Outdoor Humidity
                                                HStack(spacing: 4) {
                                                    Image(systemName: "humidity.fill")
                                                        .foregroundColor(.blue)
                                                        .font(.caption)
                                                    Text("\(data.outdoor.humidity.value)\(data.outdoor.humidity.unit)")
                                                        .font(.subheadline)
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                        }
                                        
                                        Divider()
                                        
                                        // Daily High/Low Section - Temperature
                                        if let tempStats = getDailyTemperatureStats(for: station, data: data) {
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
                                                if let humidityStats = getDailyHumidityStats(for: station, data: data) {
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
                            
                            // Indoor Temperature Card
                            if station.sensorPreferences.showIndoorTemp {
                                EditableWeatherCard(
                                    title: .constant(station.customLabels.indoorTemp),
                                    systemImage: "house.fill",
                                    onTitleChange: { newTitle in
                                        station.customLabels.indoorTemp = newTitle
                                        saveStation()
                                    }
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
                                        if let tempStats = getIndoorDailyTemperatureStats(for: station, data: data) {
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
                                                if let humidityStats = getIndoorDailyHumidityStats(for: station, data: data) {
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
                            
                            // Additional Temperature/Humidity Ch1 Sensor
                            if station.sensorPreferences.showTempHumidityCh1 {
                                EditableWeatherCard(
                                    title: .constant(station.customLabels.tempHumidityCh1),
                                    systemImage: "thermometer",
                                    onTitleChange: { newTitle in
                                        station.customLabels.tempHumidityCh1 = newTitle
                                        saveStation()
                                    }
                                ) {
                                    VStack(alignment: .leading, spacing: 12) {
                                        // Current Temperature - Main Display
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(TemperatureConverter.formatTemperature(data.tempAndHumidityCh1.temperature.value, originalUnit: data.tempAndHumidityCh1.temperature.unit))
                                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                            if let humidity = data.tempAndHumidityCh1.humidity {
                                                Text("Humidity: \(humidity.value)\(humidity.unit)")
                                                    .font(.subheadline)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        
                                        Divider()
                                        
                                        // Daily High/Low Section - Temperature
                                        if let tempStats = getTempHumidityCh1DailyTemperatureStats(for: station, data: data) {
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
                                                if let humidityStats = getTempHumidityCh1DailyHumidityStats(for: station, data: data) {
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
                            
                            // Additional Temperature/Humidity Ch2 Sensor
                            if station.sensorPreferences.showTempHumidityCh2 {
                                EditableWeatherCard(
                                    title: .constant(station.customLabels.tempHumidityCh2),
                                    systemImage: "thermometer",
                                    onTitleChange: { newTitle in
                                        station.customLabels.tempHumidityCh2 = newTitle
                                        saveStation()
                                    }
                                ) {
                                    VStack(alignment: .leading, spacing: 12) {
                                        // Current Temperature - Main Display
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(TemperatureConverter.formatTemperature(data.tempAndHumidityCh2.temperature.value, originalUnit: data.tempAndHumidityCh2.temperature.unit))
                                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                            if let humidity = data.tempAndHumidityCh2.humidity {
                                                Text("Humidity: \(humidity.value)\(humidity.unit)")
                                                    .font(.subheadline)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        
                                        Divider()
                                        
                                        // Daily High/Low Section - Temperature
                                        if let tempStats = getTempHumidityCh2DailyTemperatureStats(for: station, data: data) {
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
                                                if let humidityStats = getTempHumidityCh2DailyHumidityStats(for: station, data: data) {
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
                            
                            // Additional Temperature/Humidity Ch3 Sensor
                            if station.sensorPreferences.showTempHumidityCh3, let tempHumCh3 = data.tempAndHumidityCh3 {
                                EditableWeatherCard(
                                    title: .constant(station.customLabels.tempHumidityCh3),
                                    systemImage: "thermometer",
                                    onTitleChange: { newTitle in
                                        station.customLabels.tempHumidityCh3 = newTitle
                                        saveStation()
                                    }
                                ) {
                                    VStack(alignment: .leading, spacing: 12) {
                                        // Current Temperature - Main Display
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(TemperatureConverter.formatTemperature(tempHumCh3.temperature.value, originalUnit: tempHumCh3.temperature.unit))
                                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                            if let humidity = tempHumCh3.humidity {
                                                Text("Humidity: \(humidity.value)\(humidity.unit)")
                                                    .font(.subheadline)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        
                                        Divider()
                                        
                                        // Daily High/Low Section - Temperature
                                        if let tempStats = getTempHumidityCh3DailyTemperatureStats(for: station, data: data) {
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
                                                if let humidityStats = getTempHumidityCh3DailyHumidityStats(for: station, data: data) {
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
                            
                            // OTHER SENSORS SECTION
                            // Enhanced Wind Card
                            if station.sensorPreferences.showWind {
                                EditableWeatherCard(
                                    title: .constant(station.customLabels.wind),
                                    systemImage: "wind",
                                    onTitleChange: { newTitle in
                                        station.customLabels.wind = newTitle
                                        saveStation()
                                    }
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
                                        
                                        // Additional Wind Information
                                        VStack(spacing: 6) {
                                            HStack {
                                                Text("Wind Gusts:")
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
                                                let beaufortScale = getBeaufortScale(windSpeedMph: windSpeedValue)
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
                            }
                            
                            // Pressure Card
                            if station.sensorPreferences.showPressure {
                                EditableWeatherCard(
                                    title: .constant(station.customLabels.pressure),
                                    systemImage: "barometer",
                                    onTitleChange: { newTitle in
                                        station.customLabels.pressure = newTitle
                                        saveStation()
                                    }
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
                            
                            // Rainfall Card (always use piezo data)
                            if station.sensorPreferences.showRainfall {
                                EditableWeatherCard(
                                    title: .constant(station.customLabels.rainfall),
                                    systemImage: "cloud.rain.fill",
                                    onTitleChange: { newTitle in
                                        station.customLabels.rainfall = newTitle
                                        saveStation()
                                    }
                                ) {
                                    let rainfallData = data.rainfallPiezo
                                    VStack(alignment: .leading, spacing: 4) {
                                        // Rain Status
                                        HStack {
                                            Text("Status:")
                                            Spacer()
                                            Text(rainStatusText(rainfallData.state.value))
                                                .fontWeight(.semibold)
                                                .foregroundColor(rainStatusColor(rainfallData.state.value))
                                        }
                                        
                                        Divider()
                                        
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
                                    .font(.subheadline)
                                }
                            }
                            
                            // Air Quality Ch1 Card
                            if station.sensorPreferences.showAirQualityCh1 && data.pm25Ch1.pm25.value != "0" && !data.pm25Ch1.pm25.value.isEmpty {
                                EditableWeatherCard(
                                    title: .constant(station.customLabels.airQualityCh1),
                                    systemImage: "aqi.medium",
                                    onTitleChange: { newTitle in
                                        station.customLabels.airQualityCh1 = newTitle
                                        saveStation()
                                    }
                                ) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("\(data.pm25Ch1.pm25.value) \(data.pm25Ch1.pm25.unit)")
                                            .font(.system(size: 24, weight: .bold, design: .rounded))
                                        Text("AQI: \(data.pm25Ch1.realTimeAqi.value)")
                                            .font(.subheadline)
                                            .foregroundColor(aqiColor(for: data.pm25Ch1.realTimeAqi.value))
                                    }
                                }
                            }
                            
                            // Air Quality Ch2 Card (if enabled and has data)
                            if station.sensorPreferences.showAirQualityCh2, 
                               let pm25Ch2 = data.pm25Ch2,
                               pm25Ch2.pm25.value != "0" && !pm25Ch2.pm25.value.isEmpty {
                                EditableWeatherCard(
                                    title: .constant(station.customLabels.airQualityCh2),
                                    systemImage: "aqi.medium",
                                    onTitleChange: { newTitle in
                                        station.customLabels.airQualityCh2 = newTitle
                                        saveStation()
                                    }
                                ) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("\(pm25Ch2.pm25.value) \(pm25Ch2.pm25.unit)")
                                            .font(.system(size: 24, weight: .bold, design: .rounded))
                                        Text("AQI: \(pm25Ch2.realTimeAqi.value)")
                                            .font(.subheadline)
                                            .foregroundColor(aqiColor(for: pm25Ch2.realTimeAqi.value))
                                    }
                                }
                            }
                            
                            // Air Quality Ch3 Card (if enabled and has data)
                            if station.sensorPreferences.showAirQualityCh3,
                               let pm25Ch3 = data.pm25Ch3,
                               pm25Ch3.pm25.value != "0" && !pm25Ch3.pm25.value.isEmpty {
                                EditableWeatherCard(
                                    title: .constant(station.customLabels.airQualityCh3),
                                    systemImage: "aqi.medium",
                                    onTitleChange: { newTitle in
                                        station.customLabels.airQualityCh3 = newTitle
                                        saveStation()
                                    }
                                ) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("\(pm25Ch3.pm25.value) \(pm25Ch3.pm25.unit)")
                                            .font(.system(size: 24, weight: .bold, design: .rounded))
                                        Text("AQI: \(pm25Ch3.realTimeAqi.value)")
                                            .font(.subheadline)
                                            .foregroundColor(aqiColor(for: pm25Ch3.realTimeAqi.value))
                                    }
                                }
                            }
                            
                            // Enhanced Solar & UV Index Card
                            if station.sensorPreferences.showSolar {
                                EditableWeatherCard(
                                    title: .constant(station.customLabels.solar),
                                    systemImage: "sun.max.fill",
                                    onTitleChange: { newTitle in
                                        station.customLabels.solar = newTitle
                                        saveStation()
                                    }
                                ) {
                                    VStack(alignment: .leading, spacing: 12) {
                                        // UV Index - Most prominent
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("UV Index")
                                                .font(.headline)
                                                .fontWeight(.semibold)
                                            Text(data.solarAndUvi.uvi.value)
                                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                                .foregroundColor(getUVIndexColor(data.solarAndUvi.uvi.value))
                                            Text(getUVIndexDescription(data.solarAndUvi.uvi.value))
                                                .font(.subheadline)
                                                .foregroundColor(getUVIndexColor(data.solarAndUvi.uvi.value))
                                        }
                                        
                                        Divider()
                                        
                                        // Solar Radiation Details
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
                                                    Text(getSolarIntensityDescription(solarValue))
                                                        .font(.subheadline)
                                                        .fontWeight(.semibold)
                                                        .foregroundColor(getSolarIntensityColor(solarValue))
                                                }
                                                
                                                // Estimated solar panel efficiency (for fun)
                                                let efficiency = estimateSolarPanelOutput(solarValue)
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
                            }
                            
                            // Lightning Card
                            if station.sensorPreferences.showLightning {
                                EditableWeatherCard(
                                    title: .constant(station.customLabels.lightning),
                                    systemImage: "cloud.bolt.fill",
                                    onTitleChange: { newTitle in
                                        station.customLabels.lightning = newTitle
                                        saveStation()
                                    }
                                ) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(MeasurementConverter.formatDistance(data.lightning.distance.value, originalUnit: data.lightning.distance.unit))
                                            .font(.system(size: 24, weight: .bold, design: .rounded))
                                        Text("Count: \(data.lightning.count.value)")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            
                            // Battery Status Card
                            if station.sensorPreferences.showBatteryStatus {
                                EditableWeatherCard(
                                    title: .constant(station.customLabels.batteryStatus),
                                    systemImage: "battery.100",
                                    onTitleChange: { newTitle in
                                        station.customLabels.batteryStatus = newTitle
                                        saveStation()
                                    }
                                ) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        if let console = data.battery.console {
                                            HStack {
                                                Text("Console:")
                                                Spacer()
                                                Text("\(console.value) \(console.unit)")
                                            }
                                        }
                                        if let haptic = data.battery.hapticArrayBattery {
                                            HStack {
                                                Text("Haptic Array:")
                                                Spacer()
                                                Text("\(haptic.value) \(haptic.unit)")
                                            }
                                        }
                                        if let lightning = data.battery.lightningSensor {
                                            HStack {
                                                Text("Lightning Sensor:")
                                                Spacer()
                                                Text(batteryLevelText(lightning.value))
                                            }
                                        }
                                        if let pm25Ch1 = data.battery.pm25SensorCh1 {
                                            HStack {
                                                Text("PM2.5 Ch1:")
                                                Spacer()
                                                Text(batteryLevelText(pm25Ch1.value))
                                            }
                                        }
                                        if let pm25Ch2 = data.battery.pm25SensorCh2 {
                                            HStack {
                                                Text("PM2.5 Ch2:")
                                                Spacer()
                                                Text(batteryLevelText(pm25Ch2.value))
                                            }
                                        }
                                        
                                        if let hapticCap = data.battery.hapticArrayCapacitor {
                                            HStack {
                                                Text("Haptic Capacitor:")
                                                Spacer()
                                                Text("\(hapticCap.value) \(hapticCap.unit)")
                                            }
                                        }
                                        if let rainfall = data.battery.rainfallSensor {
                                            HStack {
                                                Text("Rainfall Sensor:")
                                                Spacer()
                                                Text("\(rainfall.value) \(rainfall.unit)")
                                            }
                                        }
                                        if let th1 = data.battery.tempHumiditySensorCh1 {
                                            HStack {
                                                Text("Temp/Humidity Ch1:")
                                                Spacer()
                                                Text(tempHumidityBatteryStatusText(th1.value))
                                            }
                                        }
                                        if let th2 = data.battery.tempHumiditySensorCh2 {
                                            HStack {
                                                Text("Temp/Humidity Ch2:")
                                                Spacer()
                                                Text(tempHumidityBatteryStatusText(th2.value))
                                            }
                                        }
                                        if let th3 = data.battery.tempHumiditySensorCh3 {
                                            HStack {
                                                Text("Temp/Humidity Ch3:")
                                                Spacer()
                                                Text(tempHumidityBatteryStatusText(th3.value))
                                            }
                                        }
                                    }
                                    .font(.caption)
                                }
                            }
                            
                            // Sunrise/Sunset Card
                            if station.sensorPreferences.showSunriseSunset && station.latitude != nil && station.longitude != nil {
                                EditableWeatherCard(
                                    title: .constant(station.customLabels.sunriseSunset),
                                    systemImage: sunIconForCurrentTime(station: station),
                                    onTitleChange: { newTitle in
                                        station.customLabels.sunriseSunset = newTitle
                                        saveStation()
                                    }
                                ) {
                                    if let latitude = station.latitude, let longitude = station.longitude,
                                       let sunTimes = SunCalculator.calculateSunTimes(for: Date(), latitude: latitude, longitude: longitude, timeZone: station.timeZone) {
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
                                            
                                            // Next event
                                            let nextEvent = SunCalculator.getNextSunEvent(latitude: latitude, longitude: longitude, timeZone: station.timeZone)
                                            HStack {
                                                Text("Next \(nextEvent.event):")
                                                    .font(.subheadline)
                                                    .foregroundColor(.secondary)
                                                Spacer()
                                                Text(nextEvent.time, style: .time)
                                                    .font(.subheadline)
                                                    .fontWeight(.semibold)
                                            }
                                        }
                                    } else {
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
                            }
                            
                            // Camera Card (show only for stations with associated cameras)
                            if station.sensorPreferences.showCamera && station.associatedCameraMAC != nil {
                                CameraTileView(station: station, onTitleChange: { newTitle in
                                    station.customLabels.camera = newTitle
                                    saveStation()
                                })
                            }
                        }
                    } else {
                        VStack(spacing: 20) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 48))
                                .foregroundColor(.orange)
                            
                            Text("No Data Available")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("Tap refresh to load weather data for \(station.name)")
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .padding()
            }
        }
        .navigationTitle(station.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("History") {
                    showingHistory = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .sheet(isPresented: $showingHistory) {
            NavigationView {
                HistoricalChartView(station: station)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") {
                                showingHistory = false
                            }
                        }
                    }
            }
        }
    }
    
    // Dynamic column calculation based on window width
    private func calculateColumns(for width: CGFloat) -> Int {
        switch width {
        case 0..<600:
            return 1
        case 600..<900:
            return 2
        case 900..<1200:
            return 3
        case 1200..<1600:
            return 4
        default:
            return 5
        }
    }
    
    private func calculateTileSize(for width: CGFloat, columns: Int) -> CGFloat {
        let spacing: CGFloat = 16
        let totalSpacing = spacing * CGFloat(columns - 1)
        let availableWidth = width - totalSpacing - 32 // 32 for padding
        return availableWidth / CGFloat(columns)
    }
    
    private func saveStation() {
        weatherService.updateStation(station)
    }
    
    private func rainStatusText(_ value: String) -> String {
        switch value {
        case "0": return "Not Raining"
        case "1": return "Raining"
        default: return "Status: \(value)"
        }
    }
    
    private func rainStatusColor(_ value: String) -> Color {
        switch value {
        case "0": return .green
        case "1": return .blue
        default: return .secondary
        }
    }
    
    private func aqiColor(for value: String) -> Color {
        guard let intValue = Int(value) else { return .secondary }
        switch intValue {
        case 0...50: return .green
        case 51...100: return .yellow
        case 101...150: return .orange
        case 151...200: return .red
        case 201...300: return .purple
        default: return .black
        }
    }
    
    private func batteryLevelText(_ value: String) -> String {
        guard let level = Int(value) else { return value }
        switch level {
        case 0: return "Empty"
        case 1: return "1-20%"
        case 2: return "21-40%"
        case 3: return "41-60%"
        case 4: return "61-80%"
        case 5: return "81-100%"
        case 6: return "DC Power"
        default: return value
        }
    }
    
    private func sunIconForCurrentTime(station: WeatherStation) -> String {
        guard let latitude = station.latitude, let longitude = station.longitude,
              let sunTimes = SunCalculator.calculateSunTimes(for: Date(), latitude: latitude, longitude: longitude, timeZone: station.timeZone) else {
            return "sun.horizon"
        }
        
        return sunTimes.isCurrentlyDaylight ? "sun.max.fill" : "moon.stars.fill"
    }
    
    // Helper method to get daily temperature stats
    private func getDailyTemperatureStats(for station: WeatherStation, data: WeatherStationData) -> DailyTemperatureStats? {
        let historicalData = weatherService.historicalData[station.macAddress]
        return DailyTemperatureCalculator.getDailyStats(
            weatherData: data,
            historicalData: historicalData,
            station: station
        )
    }
    
    // Helper method to get daily humidity stats
    private func getDailyHumidityStats(for station: WeatherStation, data: WeatherStationData) -> DailyHumidityStats? {
        let historicalData = weatherService.historicalData[station.macAddress]
        return DailyTemperatureCalculator.getDailyHumidityStats(
            weatherData: data,
            historicalData: historicalData,
            station: station
        )
    }
    
    private func getIndoorDailyTemperatureStats(for station: WeatherStation, data: WeatherStationData) -> DailyTemperatureStats? {
        let historicalData = weatherService.historicalData[station.macAddress]
        return DailyTemperatureCalculator.getIndoorDailyStats(
            weatherData: data,
            historicalData: historicalData,
            station: station
        )
    }
    
    private func getIndoorDailyHumidityStats(for station: WeatherStation, data: WeatherStationData) -> DailyHumidityStats? {
        let historicalData = weatherService.historicalData[station.macAddress]
        return DailyTemperatureCalculator.getIndoorDailyHumidityStats(
            weatherData: data,
            historicalData: historicalData,
            station: station
        )
    }
    
    private func getTempHumidityCh1DailyTemperatureStats(for station: WeatherStation, data: WeatherStationData) -> DailyTemperatureStats? {
        let historicalData = weatherService.historicalData[station.macAddress]
        return DailyTemperatureCalculator.getTempHumidityCh1DailyStats(
            weatherData: data,
            historicalData: historicalData,
            station: station
        )
    }
    
    private func getTempHumidityCh1DailyHumidityStats(for station: WeatherStation, data: WeatherStationData) -> DailyHumidityStats? {
        let historicalData = weatherService.historicalData[station.macAddress]
        return DailyTemperatureCalculator.getTempHumidityCh1DailyHumidityStats(
            weatherData: data,
            historicalData: historicalData,
            station: station
        )
    }
    
    private func getTempHumidityCh2DailyTemperatureStats(for station: WeatherStation, data: WeatherStationData) -> DailyTemperatureStats? {
        let historicalData = weatherService.historicalData[station.macAddress]
        return DailyTemperatureCalculator.getTempHumidityCh2DailyStats(
            weatherData: data,
            historicalData: historicalData,
            station: station
        )
    }
    
    private func getTempHumidityCh2DailyHumidityStats(for station: WeatherStation, data: WeatherStationData) -> DailyHumidityStats? {
        let historicalData = weatherService.historicalData[station.macAddress]
        return DailyTemperatureCalculator.getTempHumidityCh2DailyHumidityStats(
            weatherData: data,
            historicalData: historicalData,
            station: station
        )
    }
    
    private func getTempHumidityCh3DailyTemperatureStats(for station: WeatherStation, data: WeatherStationData) -> DailyTemperatureStats? {
        let historicalData = weatherService.historicalData[station.macAddress]
        return DailyTemperatureCalculator.getTempHumidityCh3DailyStats(
            weatherData: data,
            historicalData: historicalData,
            station: station
        )
    }
    
    private func getTempHumidityCh3DailyHumidityStats(for station: WeatherStation, data: WeatherStationData) -> DailyHumidityStats? {
        let historicalData = weatherService.historicalData[station.macAddress]
        return DailyTemperatureCalculator.getTempHumidityCh3DailyHumidityStats(
            weatherData: data,
            historicalData: historicalData,
            station: station
        )
    }
    
    private func getBeaufortScale(windSpeedMph: Double) -> (number: Int, description: String) {
        switch windSpeedMph {
        case 0...1: return (0, "Calm")
        case 1...3: return (1, "Light Air")
        case 4...7: return (2, "Light Breeze")
        case 8...12: return (3, "Gentle Breeze")
        case 13...18: return (4, "Moderate Breeze")
        case 19...24: return (5, "Fresh Breeze")
        case 25...31: return (6, "Strong Breeze")
        case 32...38: return (7, "Near Gale")
        case 39...46: return (8, "Gale")
        case 47...54: return (9, "Strong Gale")
        case 55...63: return (10, "Storm")
        case 64...72: return (11, "Violent Storm")
        default: return (12, "Hurricane")
        }
    }
    
    private func getUVIndexColor(_ value: String) -> Color {
        guard let uvi = Double(value) else { return .secondary }
        switch uvi {
        case 0...2: return .green
        case 3...5: return .yellow
        case 6...7: return .orange
        case 8...10: return .red
        default: return .purple
        }
    }
    
    private func getUVIndexDescription(_ value: String) -> String {
        guard let uvi = Double(value) else { return "Unknown" }
        switch uvi {
        case 0...2: return "Low"
        case 3...5: return "Moderate"
        case 6...7: return "High"
        case 8...10: return "Very High"
        default: return "Extreme"
        }
    }
    
    private func getSolarIntensityDescription(_ value: Double) -> String {
        switch value {
        case 0...200: return "Very Low"
        case 201...400: return "Low"
        case 401...600: return "Moderate"
        case 601...800: return "High"
        case 801...1000: return "Very High"
        default: return "Extreme"
        }
    }
    
    private func getSolarIntensityColor(_ value: Double) -> Color {
        switch value {
        case 0...200: return .gray
        case 201...400: return .blue
        case 401...600: return .green
        case 601...800: return .orange
        default: return .red
        }
    }
    
    private func estimateSolarPanelOutput(_ solarRadiation: Double) -> Double {
        // Rough estimation: peak solar radiation is typically ~1000 W/m²
        let peakRadiation = 1000.0
        return min(100, (solarRadiation / peakRadiation) * 100)
    }
}

struct StationInfoCard: View {
    let station: WeatherStation
    @StateObject private var weatherService = WeatherStationService.shared
    
    private var creationDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }
    
    private func deviceTypeDescription(_ type: Int) -> String {
        switch type {
        case 1: return "Weather Station Gateway"
        case 2: return "Weather Camera"
        default: return "Device Type \(type)"
        }
    }
    
    var body: some View {
        WeatherCard(title: "Station Information", systemImage: "info.circle.fill") {
            VStack(alignment: .leading, spacing: 8) {
                // Device Type
                if let deviceType = station.deviceType {
                    HStack {
                        Text("Device Type:")
                            .fontWeight(.medium)
                        Spacer()
                        Text(deviceTypeDescription(deviceType))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(deviceType == 1 ? Color.blue.opacity(0.2) : Color.purple.opacity(0.2))
                            .foregroundColor(deviceType == 1 ? .blue : .purple)
                            .cornerRadius(6)
                    }
                }
                
                // MAC Address
                HStack {
                    Text("MAC Address:")
                        .fontWeight(.medium)
                    Spacer()
                    Text(station.macAddress)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                }
                
                // Station Model
                if let stationType = station.stationType {
                    HStack {
                        Text("Model:")
                            .fontWeight(.medium)
                        Spacer()
                        Text(stationType)
                            .font(.system(.body, design: .monospaced))
                    }
                }
                
                Divider()
                
                // Creation Date
                if let creationDate = station.creationDate {
                    HStack {
                        Text("Device Created:")
                            .fontWeight(.medium)
                        Spacer()
                        Text(creationDate, formatter: creationDateFormatter)
                    }
                }
                
                // Last Updated - Use enhanced TimestampExtractor formatting
                if let formattedTime = weatherService.getDataRecordingTime(for: station) {
                    HStack {
                        Text("Last Data Update:")
                            .fontWeight(.medium)
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text(formattedTime)
                            Text("(\(weatherService.getDataAge(for: station)))")
                                .font(.caption)
                                .foregroundColor(weatherService.isDataFresh(for: station) ? .green : .orange)
                        }
                    }
                } else if station.lastUpdated != nil {
                    HStack {
                        Text("Last Data Update:")
                            .fontWeight(.medium)
                        Spacer()
                        Text("Data available but timestamp unavailable")
                            .foregroundColor(.orange)
                    }
                } else {
                    HStack {
                        Text("Last Data Update:")
                            .fontWeight(.medium)
                        Spacer()
                        Text("Never")
                            .foregroundColor(.red)
                    }
                }
                
                // Status
                HStack {
                    Text("Status:")
                        .fontWeight(.medium)
                    Spacer()
                    HStack(spacing: 4) {
                        Circle()
                            .fill(station.isActive ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        Text(station.isActive ? "Active" : "Inactive")
                            .foregroundColor(station.isActive ? .green : .red)
                    }
                }
            }
            .font(.subheadline)
        }
    }
}

struct WeatherCard<Content: View>: View {
    let title: String
    let systemImage: String
    let content: Content
    
    init(title: String, systemImage: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Spacer()
                Image(systemName: systemImage)
                    .foregroundColor(.blue)
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                Spacer()
            }
            
            content
            
            Spacer(minLength: 0)
        }
        .padding()
        .frame(minHeight: 200, maxHeight: 220)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

struct EditableWeatherCard<Content: View>: View {
    @Binding var title: String
    let systemImage: String
    let onTitleChange: (String) -> Void
    let content: Content
    
    @State private var isEditing = false
    @State private var editedTitle = ""
    
    init(title: Binding<String>, systemImage: String, onTitleChange: @escaping (String) -> Void, @ViewBuilder content: () -> Content) {
        self._title = title
        self.systemImage = systemImage
        self.onTitleChange = onTitleChange
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with icon and title
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .foregroundColor(.blue)
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 20, height: 20)
                
                if isEditing {
                    TextField("Card title", text: $editedTitle)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.headline)
                        .fontWeight(.semibold)
                        .onSubmit {
                            onTitleChange(editedTitle)
                            title = editedTitle
                            isEditing = false
                        }
                        .onAppear {
                            editedTitle = title
                        }
                } else {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .onTapGesture {
                            editedTitle = title
                            isEditing = true
                        }
                }
                
                Spacer()
            }
            
            // Content with scrollable area for overflow
            ScrollView {
                content
            }
            .frame(maxHeight: 180) // Fixed content height for uniformity
            
            Spacer(minLength: 0)
        }
        .frame(height: 250) // Fixed card height
        .padding(20)
        .background {
            // Modern multi-layer background effect
            ZStack {
                // Base background with subtle transparency
                Color(NSColor.controlBackgroundColor)
                    .opacity(0.8)
                
                // Subtle gradient overlay for depth
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(0.1),
                        Color.clear,
                        Color.black.opacity(0.05)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
        .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.linearGradient(
                    colors: [
                        Color.white.opacity(0.3),
                        Color.white.opacity(0.1),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ), lineWidth: 0.5)
        )
        .scaleEffect(1.0)
        .animation(.easeInOut(duration: 0.2), value: isEditing)
    }
}

private func tempHumidityBatteryStatusText(_ value: String) -> String {
    switch value {
    case "0": return "Normal"
    case "1": return "Low"
    default: return value
    }
}

struct PreviewWeatherStationDetailView: PreviewProvider {
    static var previews: some View {
        NavigationView {
            WeatherStationDetailView(station: .constant(WeatherStation(name: "Test Station", macAddress: "A0:A3:B3:7B:28:8B")), weatherData: nil)
        }
    }
}