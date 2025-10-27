//
//  HistoricalChartView.swift
//  Weather Station App
//
//  Created by Curtis Netterville on 10/25/25.
//

import SwiftUI
import Charts

struct HistoricalChartView: View {
    let station: WeatherStation
    @StateObject private var weatherService = WeatherStationService.shared
    
    @State private var selectedTimeRange: HistoricalTimeRange = .last24Hours
    @State private var selectedSensor: HistoricalSensor = .outdoorTemperature
    @State private var showDataAvailabilityInfo = false
    
    var historicalData: HistoricalWeatherData? {
        weatherService.historicalData[station.macAddress]
    }
    
    var chartData: [ChartDataPoint] {
        guard let data = historicalData else { return [] }
        
        switch selectedSensor {
        case .outdoorTemperature:
            return weatherService.getChartData(from: data.outdoor?.temperature)
        case .outdoorHumidity:
            return weatherService.getChartData(from: data.outdoor?.humidity)
        case .indoorTemperature:
            return weatherService.getChartData(from: data.indoor?.temperature)
        case .indoorHumidity:
            return weatherService.getChartData(from: data.indoor?.humidity)
        case .windSpeed:
            return weatherService.getChartData(from: data.wind?.windSpeed)
        case .windGust:
            return weatherService.getChartData(from: data.wind?.windGust)
        case .pressure:
            return weatherService.getChartData(from: data.pressure?.relative)
        case .rainRate:
            return weatherService.getChartData(from: data.rainfallPiezo?.rainRate)
        case .rainDaily:
            return weatherService.getChartData(from: data.rainfallPiezo?.daily)
        case .pm25:
            return weatherService.getChartData(from: data.pm25Ch1?.pm25)
        case .uvIndex:
            return weatherService.getChartData(from: data.solarAndUvi?.uvi)
        case .solar:
            return weatherService.getChartData(from: data.solarAndUvi?.solar)
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Header with controls
            VStack(spacing: 16) {
                HStack {
                    Text("Historical Weather Data")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Button {
                        showDataAvailabilityInfo.toggle()
                    } label: {
                        Image(systemName: "info.circle")
                    }
                    .help("Data availability information")
                    
                    Button("Refresh") {
                        loadHistoricalData()
                    }
                    .disabled(weatherService.isLoadingHistory)
                }
                
                // Data availability info (expandable)
                if showDataAvailabilityInfo {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Historical Data Availability")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text(weatherService.getDataAvailabilityInfo())
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                    )
                }
                
                // Time range selector
                VStack(alignment: .leading, spacing: 8) {
                    Text("Time Range:")
                        .font(.headline)
                    
                    HStack(spacing: 8) {
                        ForEach(HistoricalTimeRange.allCases, id: \.self) { range in
                            Button(action: {
                                selectedTimeRange = range
                                loadHistoricalData()
                            }) {
                                Text(range.displayName)
                                    .font(.system(size: 12, weight: .medium))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .frame(minWidth: 60)
                                    .background(selectedTimeRange == range ? Color.accentColor : Color(NSColor.controlBackgroundColor))
                                    .foregroundColor(selectedTimeRange == range ? .white : .primary)
                                    .cornerRadius(6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(selectedTimeRange == range ? Color.clear : Color.secondary.opacity(0.3), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                        
                        Spacer()
                    }
                    
                    // Show warning for longer time ranges
                    if selectedTimeRange == .last90Days || selectedTimeRange == .last365Days {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            
                            Text(selectedTimeRange == .last90Days ? 
                                "Note: Daily data limited to ~3 months by API" :
                                "Note: Using weekly data points for 1-year view"
                            )
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Sensor selector
                HStack {
                    Text("Sensor:")
                        .font(.headline)
                    
                    Picker("Sensor", selection: $selectedSensor) {
                        ForEach(HistoricalSensor.allCases, id: \.self) { sensor in
                            Text(sensor.displayName).tag(sensor)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
            
            // Chart
            if weatherService.isLoadingHistory {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading historical data...")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if chartData.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No Historical Data")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Select a time range and sensor to view historical data")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(selectedSensor.displayName)
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        if let lastDataPoint = chartData.last {
                            Text("Latest: \(formatLatestValue(lastDataPoint.value))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Chart(chartData) { dataPoint in
                        LineMark(
                            x: .value("Time", dataPoint.timestamp),
                            y: .value(selectedSensor.displayName, dataPoint.value)
                        )
                        .foregroundStyle(selectedSensor.color)
                        .interpolationMethod(.catmullRom)
                        
                        AreaMark(
                            x: .value("Time", dataPoint.timestamp),
                            y: .value(selectedSensor.displayName, dataPoint.value)
                        )
                        .foregroundStyle(selectedSensor.color.opacity(0.2))
                        .interpolationMethod(.catmullRom)
                    }
                    .frame(height: 400)
                    .chartYAxisLabel(selectedSensor.yAxisLabel)
                    .chartXAxisLabel("Time")
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
            }
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: 900) // Limit the overall width
        .navigationTitle("History - \(station.name)")
        .onAppear {
            if historicalData == nil {
                loadHistoricalData()
            }
        }
    }
    
    private func loadHistoricalData() {
        let sensors = selectedSensor.apiCallbacks
        Task {
            await weatherService.fetchHistoricalData(
                for: station,
                timeRange: selectedTimeRange,
                sensors: sensors
            )
        }
    }
    
    private func formatLatestValue(_ value: Double) -> String {
        let valueString = String(format: selectedSensor.formatSpecifier, value)
        
        switch selectedSensor {
        case .outdoorTemperature, .indoorTemperature:
            return MeasurementConverter.formatTemperature(valueString, originalUnit: selectedSensor.unit)
        case .windSpeed, .windGust:
            return MeasurementConverter.formatDualWindSpeed(valueString, originalUnit: selectedSensor.unit)
        case .rainRate:
            return MeasurementConverter.formatDualRainRate(valueString, originalUnit: selectedSensor.unit)
        case .rainDaily:
            return MeasurementConverter.formatDualRainfall(valueString, originalUnit: selectedSensor.unit)
        default:
            return "\(valueString) \(selectedSensor.unit)"
        }
    }
}

enum HistoricalSensor: String, CaseIterable {
    case outdoorTemperature = "outdoor_temperature"
    case outdoorHumidity = "outdoor_humidity"
    case indoorTemperature = "indoor_temperature"
    case indoorHumidity = "indoor_humidity"
    case windSpeed = "wind_speed"
    case windGust = "wind_gust"
    case pressure = "pressure"
    case rainRate = "rain_rate"
    case rainDaily = "rain_daily"
    case pm25 = "pm25"
    case uvIndex = "uv_index"
    case solar = "solar"
    
    var displayName: String {
        switch self {
        case .outdoorTemperature: return "Outdoor Temperature"
        case .outdoorHumidity: return "Outdoor Humidity"
        case .indoorTemperature: return "Indoor Temperature"
        case .indoorHumidity: return "Indoor Humidity"
        case .windSpeed: return "Wind Speed"
        case .windGust: return "Wind Gust"
        case .pressure: return "Atmospheric Pressure"
        case .rainRate: return "Rain Rate"
        case .rainDaily: return "Daily Rainfall"
        case .pm25: return "PM2.5 Air Quality"
        case .uvIndex: return "UV Index"
        case .solar: return "Solar Radiation"
        }
    }
    
    var unit: String {
        switch self {
        case .outdoorTemperature, .indoorTemperature: return "°F / °C"
        case .outdoorHumidity, .indoorHumidity: return "%"
        case .windSpeed, .windGust: return "mph / km/h"
        case .pressure: return "inHg"
        case .rainRate: return "in/h / mm/h"
        case .rainDaily: return "in / mm"
        case .pm25: return "µg/m³"
        case .uvIndex: return ""
        case .solar: return "W/m²"
        }
    }
    
    var yAxisLabel: String {
        return "\(displayName) (\(unit))"
    }
    
    var formatSpecifier: String {
        switch self {
        case .outdoorTemperature, .indoorTemperature, .windSpeed, .windGust: return "%.1f"
        case .pressure: return "%.2f"
        case .rainRate, .rainDaily: return "%.2f"
        case .outdoorHumidity, .indoorHumidity: return "%.0f"
        case .pm25: return "%.0f"
        case .uvIndex: return "%.0f"
        case .solar: return "%.1f"
        }
    }
    
    var color: Color {
        switch self {
        case .outdoorTemperature: return .red
        case .outdoorHumidity: return .blue
        case .indoorTemperature: return .orange
        case .indoorHumidity: return .cyan
        case .windSpeed, .windGust: return .green
        case .pressure: return .purple
        case .rainRate, .rainDaily: return .blue
        case .pm25: return .brown
        case .uvIndex: return .yellow
        case .solar: return .orange
        }
    }
    
    var apiCallbacks: [String] {
        switch self {
        case .outdoorTemperature, .outdoorHumidity: return ["outdoor"]
        case .indoorTemperature, .indoorHumidity: return ["indoor"]
        case .windSpeed, .windGust: return ["wind"]
        case .pressure: return ["pressure"]
        case .rainRate, .rainDaily: return ["rainfall_piezo"]
        case .pm25: return ["pm25_ch1"]
        case .uvIndex, .solar: return ["solar_and_uvi"]
        }
    }
}

#Preview {
    NavigationView {
        HistoricalChartView(station: WeatherStation(name: "Test Station", macAddress: "A0:A3:B3:7B:28:8B"))
    }
}