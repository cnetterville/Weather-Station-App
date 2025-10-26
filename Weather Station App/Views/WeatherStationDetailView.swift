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
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: columns), spacing: 16) {
                            
                            // Outdoor Temperature Card
                            if station.sensorPreferences.showOutdoorTemp {
                                EditableWeatherCard(
                                    title: .constant(station.customLabels.outdoorTemp),
                                    systemImage: "thermometer",
                                    onTitleChange: { newTitle in
                                        station.customLabels.outdoorTemp = newTitle
                                        saveStation()
                                    }
                                ) {
                                    VStack(spacing: 8) {
                                        Text(TemperatureConverter.formatDualTemperature(data.outdoor.temperature.value, originalUnit: data.outdoor.temperature.unit))
                                            .font(.system(size: 32, weight: .bold, design: .rounded))
                                        Text("Feels like \(TemperatureConverter.formatDualTemperature(data.outdoor.feelsLike.value, originalUnit: data.outdoor.feelsLike.unit))")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
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
                                    VStack(spacing: 8) {
                                        Text(TemperatureConverter.formatDualTemperature(data.indoor.temperature.value, originalUnit: data.indoor.temperature.unit))
                                            .font(.system(size: 32, weight: .bold, design: .rounded))
                                        Text("Humidity \(data.indoor.humidity.value)\(data.indoor.humidity.unit)")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            
                            // Wind Card
                            if station.sensorPreferences.showWind {
                                EditableWeatherCard(
                                    title: .constant(station.customLabels.wind),
                                    systemImage: "wind",
                                    onTitleChange: { newTitle in
                                        station.customLabels.wind = newTitle
                                        saveStation()
                                    }
                                ) {
                                    VStack(spacing: 8) {
                                        Text(MeasurementConverter.formatDualWindSpeed(data.wind.windSpeed.value, originalUnit: data.wind.windSpeed.unit))
                                            .font(.system(size: 24, weight: .bold, design: .rounded))
                                        Text("Gusts: \(MeasurementConverter.formatDualWindSpeed(data.wind.windGust.value, originalUnit: data.wind.windGust.unit))")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        Text("Direction: \(MeasurementConverter.formatWindDirectionWithCompass(data.wind.windDirection.value))")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
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
                                    VStack(spacing: 8) {
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
                                            Text(MeasurementConverter.formatDualRainfall(rainfallData.daily.value, originalUnit: rainfallData.daily.unit))
                                                .fontWeight(.semibold)
                                        }
                                        HStack {
                                            Text("This Hour:")
                                            Spacer()
                                            Text(MeasurementConverter.formatDualRainfall(rainfallData.oneHour.value, originalUnit: rainfallData.oneHour.unit))
                                        }
                                        HStack {
                                            Text("Rate:")
                                            Spacer()
                                            Text(MeasurementConverter.formatDualRainRate(rainfallData.rainRate.value, originalUnit: rainfallData.rainRate.unit))
                                        }
                                        HStack {
                                            Text("Weekly:")
                                            Spacer()
                                            Text(MeasurementConverter.formatDualRainfall(rainfallData.weekly.value, originalUnit: rainfallData.weekly.unit))
                                        }
                                        HStack {
                                            Text("Monthly:")
                                            Spacer()
                                            Text(MeasurementConverter.formatDualRainfall(rainfallData.monthly.value, originalUnit: rainfallData.monthly.unit))
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
                                    VStack(spacing: 8) {
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
                                    VStack(spacing: 8) {
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
                                    VStack(spacing: 8) {
                                        Text("\(pm25Ch3.pm25.value) \(pm25Ch3.pm25.unit)")
                                            .font(.system(size: 24, weight: .bold, design: .rounded))
                                        Text("AQI: \(pm25Ch3.realTimeAqi.value)")
                                            .font(.subheadline)
                                            .foregroundColor(aqiColor(for: pm25Ch3.realTimeAqi.value))
                                    }
                                }
                            }
                            
                            // UV Index Card
                            if station.sensorPreferences.showUVIndex {
                                EditableWeatherCard(
                                    title: .constant(station.customLabels.uvIndex),
                                    systemImage: "sun.max.fill",
                                    onTitleChange: { newTitle in
                                        station.customLabels.uvIndex = newTitle
                                        saveStation()
                                    }
                                ) {
                                    VStack(spacing: 8) {
                                        Text(data.solarAndUvi.uvi.value)
                                            .font(.system(size: 32, weight: .bold, design: .rounded))
                                        Text("Solar: \(data.solarAndUvi.solar.value) \(data.solarAndUvi.solar.unit)")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
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
                                    VStack(spacing: 8) {
                                        Text(MeasurementConverter.formatDualDistance(data.lightning.distance.value, originalUnit: data.lightning.distance.unit))
                                            .font(.system(size: 24, weight: .bold, design: .rounded))
                                        Text("Count: \(data.lightning.count.value)")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            
                            // Additional Temperature/Humidity Sensors
                            if station.sensorPreferences.showTempHumidityCh1 {
                                EditableWeatherCard(
                                    title: .constant(station.customLabels.tempHumidityCh1),
                                    systemImage: "thermometer",
                                    onTitleChange: { newTitle in
                                        station.customLabels.tempHumidityCh1 = newTitle
                                        saveStation()
                                    }
                                ) {
                                    VStack(spacing: 8) {
                                        Text(TemperatureConverter.formatDualTemperature(data.tempAndHumidityCh1.temperature.value, originalUnit: data.tempAndHumidityCh1.temperature.unit))
                                            .font(.system(size: 24, weight: .bold, design: .rounded))
                                        if let humidity = data.tempAndHumidityCh1.humidity {
                                            Text("Humidity: \(humidity.value)\(humidity.unit)")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                            
                            if station.sensorPreferences.showTempHumidityCh2 {
                                EditableWeatherCard(
                                    title: .constant(station.customLabels.tempHumidityCh2),
                                    systemImage: "thermometer",
                                    onTitleChange: { newTitle in
                                        station.customLabels.tempHumidityCh2 = newTitle
                                        saveStation()
                                    }
                                ) {
                                    VStack(spacing: 8) {
                                        Text(TemperatureConverter.formatDualTemperature(data.tempAndHumidityCh2.temperature.value, originalUnit: data.tempAndHumidityCh2.temperature.unit))
                                            .font(.system(size: 24, weight: .bold, design: .rounded))
                                        if let humidity = data.tempAndHumidityCh2.humidity {
                                            Text("Humidity: \(humidity.value)\(humidity.unit)")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                            
                            if station.sensorPreferences.showTempHumidityCh3, let tempHumCh3 = data.tempAndHumidityCh3 {
                                EditableWeatherCard(
                                    title: .constant(station.customLabels.tempHumidityCh3),
                                    systemImage: "thermometer",
                                    onTitleChange: { newTitle in
                                        station.customLabels.tempHumidityCh3 = newTitle
                                        saveStation()
                                    }
                                ) {
                                    VStack(spacing: 8) {
                                        Text(TemperatureConverter.formatDualTemperature(tempHumCh3.temperature.value, originalUnit: tempHumCh3.temperature.unit))
                                            .font(.system(size: 24, weight: .bold, design: .rounded))
                                        if let humidity = tempHumCh3.humidity {
                                            Text("Humidity: \(humidity.value)\(humidity.unit)")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                        }
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
        let cardMinWidth: CGFloat = 300  // Minimum width for each card
        let padding: CGFloat = 32       // Total horizontal padding
        let spacing: CGFloat = 16       // Spacing between columns
        
        let availableWidth = width - padding
        
        // Calculate maximum possible columns
        let maxColumns = max(1, Int((availableWidth + spacing) / (cardMinWidth + spacing)))
        
        // Cap at reasonable maximum for readability
        return min(maxColumns, 5)
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
}

struct StationInfoCard: View {
    let station: WeatherStation
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
    
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
                
                // Last Updated
                if let lastUpdated = station.lastUpdated {
                    HStack {
                        Text("Last Data Update:")
                            .fontWeight(.medium)
                        Spacer()
                        Text(lastUpdated, formatter: dateFormatter)
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: systemImage)
                    .foregroundColor(.blue)
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            content
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

struct EditableWeatherCard<Content: View>: View {
    @Binding var title: String
    let systemImage: String
    let content: Content
    let onTitleChange: (String) -> Void
    
    @State private var isEditing = false
    @State private var editText = ""
    
    init(title: Binding<String>, systemImage: String, onTitleChange: @escaping (String) -> Void, @ViewBuilder content: () -> Content) {
        self._title = title
        self.systemImage = systemImage
        self.onTitleChange = onTitleChange
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: systemImage)
                    .foregroundColor(.blue)
                
                if isEditing {
                    TextField("Sensor Label", text: $editText)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            title = editText
                            onTitleChange(editText)
                            isEditing = false
                        }
                        .onAppear {
                            editText = title
                        }
                } else {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .onTapGesture {
                            editText = title
                            isEditing = true
                        }
                        .help("Click to edit label")
                }
                
                Spacer()
                
                if isEditing {
                    Button("Done") {
                        title = editText
                        onTitleChange(editText)
                        isEditing = false
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.mini)
                }
            }
            
            content
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

#Preview {
    NavigationView {
        WeatherStationDetailView(
            station: .constant(WeatherStation(name: "Test Station", macAddress: "A0:A3:B3:7B:28:8B")), 
            weatherData: nil
        )
    }
}