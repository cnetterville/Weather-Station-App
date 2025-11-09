//
//  ForecastCard.swift
//  Weather Station App
//
//  Created by Curtis Netterville on 10/25/25.
//

import SwiftUI
import CoreLocation
import MapKit

struct ForecastCard: View {
    let station: WeatherStation
    let onTitleChange: (String) -> Void
    @StateObject private var forecastService = WeatherForecastService.shared
    
    var body: some View {
        EditableWeatherCard(
            title: .constant(station.customLabels.forecast),
            systemImage: "calendar",
            onTitleChange: onTitleChange
        ) {
            VStack(alignment: .leading, spacing: 16) {
                if forecastService.isLoading {
                    // Loading state
                    HStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                            .scaleEffect(0.8)
                        Text("Loading forecast...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    
                } else if let forecast = forecastService.getForecast(for: station) {
                    // Forecast content
                    ForecastContent(forecast: forecast, station: station)
                    
                } else if let errorMessage = forecastService.errorMessage {
                    // Error state
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.orange)
                        
                        Text("Forecast Unavailable")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Retry") {
                            Task {
                                await forecastService.fetchForecast(for: station)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    
                } else if station.latitude == nil || station.longitude == nil {
                    // No coordinates
                    VStack(spacing: 8) {
                        Image(systemName: "location.slash.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.orange)
                        
                        Text("Location Required")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("This station needs GPS coordinates to show weather forecasts")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    
                } else {
                    // No data state
                    VStack(spacing: 8) {
                        Image(systemName: "cloud.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.blue.opacity(0.6))
                        
                        Text("No Forecast Data")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("Tap to load 5-day weather forecast")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Load Forecast") {
                            Task {
                                await forecastService.fetchForecast(for: station)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                }
            }
        }
        .onAppear {
            // Auto-load forecast when card appears if we have coordinates
            if station.latitude != nil && station.longitude != nil && 
               !forecastService.hasFreshForecast(for: station) {
                Task {
                    await forecastService.fetchForecast(for: station)
                }
            }
        }
    }
}

struct ForecastContent: View {
    let forecast: WeatherForecast
    let station: WeatherStation
    @StateObject private var forecastService = WeatherForecastService.shared
    @State private var locationName: String = "5-Day Forecast"
    @State private var countryFlag: String = ""
    @State private var expandedDayIndex: Int? = nil
    @State private var expandedAlertId: String? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Weather Alerts - shown at the top if present
            if forecast.hasActiveAlerts {
                VStack(spacing: 8) {
                    ForEach(forecast.weatherAlerts.filter { $0.isActive }) { alert in
                        WeatherAlertBanner(alert: alert, isExpanded: expandedAlertId == alert.id)
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    if expandedAlertId == alert.id {
                                        expandedAlertId = nil
                                    } else {
                                        expandedAlertId = alert.id
                                    }
                                }
                            }
                    }
                }
                .padding(.bottom, 4)
            }
            
            // Forecast header with location name and last updated time
            HStack {
                HStack(spacing: 6) {
                    Text(locationName)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    if !countryFlag.isEmpty {
                        Text(countryFlag)
                            .font(.system(size: 16))
                    }
                }
                .onLongPressGesture {
                    logDebug("🔄 Force refreshing forecast (debug feature)")
                    Task {
                        await forecastService.forceRefreshForecast(for: station)
                    }
                }
                
                Spacer()
                
                if let age = forecastService.getForecastAge(for: station) {
                    Text(age)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // Show info if no hourly data and prompt to refresh
            if forecast.hourlyForecasts.isEmpty {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.blue)
                    Text("Hourly data unavailable. Tap refresh to load.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Refresh") {
                        Task {
                            await forecastService.fetchForecast(for: station)
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.caption2)
                    .foregroundColor(.blue)
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.blue.opacity(0.1))
                )
            }
            
            // Daily forecast items
            LazyVStack(spacing: 8) {
                ForEach(Array(forecast.dailyForecasts.enumerated()), id: \.offset) { index, dailyForecast in
                    VStack(spacing: 0) {
                        ForecastDayRow(
                            forecast: dailyForecast,
                            station: station,
                            isFirst: index == 0,
                            isExpanded: expandedDayIndex == index
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                if expandedDayIndex == index {
                                    expandedDayIndex = nil
                                } else {
                                    expandedDayIndex = index
                                }
                            }
                        }
                        
                        if expandedDayIndex == index {
                            ExpandedForecastDetails(forecast: dailyForecast, station: station)
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .move(edge: .top)),
                                    removal: .opacity.combined(with: .move(edge: .top))
                                ))
                        }
                    }
                    
                    if index < forecast.dailyForecasts.count - 1 {
                        Divider()
                    }
                }
            }
            
            // Location info footer - removed lat/long, keeping just refresh button
            HStack {
                Spacer()
                
                if forecast.isExpired {
                    Button("Refresh") {
                        Task {
                            await forecastService.fetchForecast(for: station)
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.caption2)
                    .foregroundColor(.blue)
                }
            }
        }
        .onAppear {
            loadLocationName()
            // Check if we need to refresh for hourly data
            if forecast.hourlyForecasts.isEmpty {
                Task {
                    await forecastService.fetchForecast(for: station)
                }
            }
        }
    }
    
    private func loadLocationName() {
        guard let latitude = station.latitude, let longitude = station.longitude else {
            return
        }
        
        Task {
            let (cityName, flagEmoji) = await getCityNameAndFlagAsync(latitude: latitude, longitude: longitude)
            await MainActor.run {
                if let cityName = cityName {
                    locationName = cityName
                }
                countryFlag = flagEmoji
            }
        }
    }
    
    private func getCityNameAndFlagAsync(latitude: Double, longitude: Double) async -> (String?, String) {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        
        guard let request = MKReverseGeocodingRequest(location: location) else {
            print("Failed to create reverse geocoding request")
            return (nil, "")
        }
        
        do {
            let mapItems = try await request.mapItems
            
            guard let firstItem = mapItems.first,
                  let addressReps = firstItem.addressRepresentations else {
                return (nil, "")
            }
            
            // Get city name
            let cityName = addressReps.cityName
            
            // Get country flag emoji from region name
            // For country code, we need to extract it from the full address or use a different approach
            // Since regionName gives us the full country name (e.g., "United States"), 
            // we can use Locale to get the country code
            let flagEmoji = getCountryFlagFromRegionName(addressReps.regionName)
            
            return (cityName, flagEmoji)
            
        } catch {
            print("Error in reverse geocoding: \(error.localizedDescription)")
            return (nil, "")
        }
    }
    
    private func getCountryFlagFromRegionName(_ regionName: String?) -> String {
        guard let regionName = regionName else { return "" }
        
        // Try to find the country code from the region name
        // This searches through all known locales to find a matching country
        for localeID in Locale.availableIdentifiers {
            let locale = Locale(identifier: localeID)
            if let countryName = locale.localizedString(forRegionCode: locale.region?.identifier ?? ""),
               countryName.localizedCaseInsensitiveContains(regionName) ||
               regionName.localizedCaseInsensitiveContains(countryName) {
                if let countryCode = locale.region?.identifier {
                    return getCountryFlagEmoji(countryCode: countryCode)
                }
            }
        }
        
        return ""
    }
    
    private func getCountryFlagEmoji(countryCode: String?) -> String {
        guard let countryCode = countryCode?.uppercased() else { return "" }
        
        // Convert ISO country code to flag emoji
        // Flag emojis are created by combining regional indicator symbols
        let base: UInt32 = 127397 // Base value for regional indicator symbols
        var flagString = ""
        
        for character in countryCode {
            if let scalar = character.unicodeScalars.first {
                let flagScalar = UnicodeScalar(base + scalar.value)!
                flagString.append(Character(flagScalar))
            }
        }
        
        return flagString
    }
}

// New expanded details view with hourly data
struct ExpandedForecastDetails: View {
    let forecast: DailyWeatherForecast
    let station: WeatherStation
    @StateObject private var forecastService = WeatherForecastService.shared
    
    private var hourlyForecasts: [HourlyWeatherForecast] {
        guard let weatherForecast = forecastService.getForecast(for: station) else {
            return []
        }
        return weatherForecast.hourlyForecasts(for: forecast.date, timezone: forecast.timezone)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if hourlyForecasts.isEmpty {
                // Fallback if no hourly data
                Text("Hourly data unavailable")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                // Hourly forecast header
                HStack {
                    Image(systemName: "clock.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text("Hourly Forecast")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
                
                // Hourly forecast scroll view
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(hourlyForecasts.enumerated()), id: \.offset) { index, hourly in
                            HourlyForecastItem(hourly: hourly)
                        }
                    }
                    .padding(.horizontal, 4)
                }
                
                Divider()
                
                // Daily summary
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "sun.max.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text("Daily Summary")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 16) {
                        // Temperature range
                        VStack(alignment: .leading, spacing: 4) {
                            Text("High/Low")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            HStack(spacing: 4) {
                                Text(forecast.formattedMaxTemp)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.orange)
                                Text("/")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(forecast.formattedMinTemp)
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        // Precipitation
                        if forecast.precipitation > 0.1 || forecast.precipitationProbability > 20 {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Rain")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                HStack(spacing: 2) {
                                    if forecast.precipitation > 0.1 {
                                        Text(forecast.formattedPrecipitation)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                    }
                                    if forecast.precipitationProbability > 0 {
                                        Text("(\(forecast.precipitationProbability)%)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        
                        Spacer()
                        
                        // Wind
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Wind")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            HStack(spacing: 4) {
                                Text(forecast.formattedWindSpeed)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text(forecast.windDirectionText)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.05))
        )
        .padding(.horizontal, 4)
        .padding(.top, 4)
    }
}

// Hourly forecast item component
struct HourlyForecastItem: View {
    let hourly: HourlyWeatherForecast
    
    var body: some View {
        VStack(spacing: 6) {
            // Time
            Text(hourly.shortFormattedTime)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            // Weather icon
            Image(systemName: hourly.weatherIcon)
                .font(.system(size: 20))
                .foregroundColor(.blue)
                .frame(height: 24)
            
            // Temperature
            Text(hourly.formattedTemperature)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
            
            // Precipitation probability
            if hourly.precipitationProbability > 20 {
                HStack(spacing: 2) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 6))
                        .foregroundColor(.blue)
                    Text("\(hourly.precipitationProbability)%")
                        .font(.system(size: 8))
                        .foregroundColor(.blue)
                }
            } else {
                // Spacer to maintain consistent height
                Text(" ")
                    .font(.system(size: 8))
            }
            
            // Wind with directional arrow
            HStack(spacing: 2) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 7, weight: .semibold))
                    .foregroundColor(.secondary)
                    .rotationEffect(.degrees(Double(hourly.windDirection)))
                
                Text(hourly.formattedWindSpeed)
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.secondary.opacity(0.08))
        )
    }
}

struct ForecastDayRow: View {
    let forecast: DailyWeatherForecast
    let station: WeatherStation
    let isFirst: Bool
    let isExpanded: Bool
    
    private var displayIcon: String {
        // Only apply night icon conversion for today's forecast
        if forecast.isToday {
            return WeatherIconHelper.adaptIconForTimeOfDay(forecast.weatherIcon, station: station)
        }
        return forecast.weatherIcon
    }
    
    var body: some View {
        VStack(spacing: 2) {
            // Top row: Day, Icon, Description, Temperature
            HStack(spacing: 8) {
                // Day
                Text(forecast.displayDay)
                    .font(.system(size: isFirst ? 15 : 13, weight: isFirst ? .bold : .medium))
                    .foregroundColor(isFirst ? .primary : .secondary)
                    .frame(width: 45, alignment: .leading)
                
                // Weather icon
                Image(systemName: displayIcon)
                    .font(.system(size: isFirst ? 18 : 16))
                    .foregroundColor(isFirst ? .blue : .blue.opacity(0.8))
                    .frame(width: 18)
                
                // Weather description
                Text(forecast.weatherDescription)
                    .font(.caption)
                    .foregroundColor(isFirst ? .primary : .secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                Spacer(minLength: 4)
                
                // Expand indicator
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.trailing, 4)
                
                // Temperature range
                HStack(spacing: 1) {
                    Text(forecast.formattedMaxTemp)
                        .font(.system(size: isFirst ? 13 : 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                    
                    Text("/")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize()
                    
                    Text(forecast.formattedMinTemp)
                        .font(.system(size: isFirst ? 13 : 12, design: .rounded))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .fixedSize(horizontal: true, vertical: false)
            }
            
            // Bottom row: Date, Precipitation/Probability, Wind
            HStack(spacing: 8) {
                // Date
                if !forecast.isToday {
                    Text(forecast.monthDay)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(width: 45, alignment: .leading)
                } else {
                    Spacer()
                        .frame(width: 45)
                }
                
                // Precipitation amount and/or probability
                if forecast.precipitation > 0.1 {
                    // Show both amount and probability if probability > 0
                    HStack(spacing: 2) {
                        Image(systemName: "drop.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.blue)
                        Text(forecast.formattedPrecipitation)
                            .font(.system(size: 9))
                            .foregroundColor(.blue)
                        
                        if forecast.precipitationProbability > 0 {
                            Text("(\(forecast.precipitationProbability)%)")
                                .font(.system(size: 9))
                                .foregroundColor(.blue.opacity(0.8))
                        }
                    }
                } else if forecast.precipitationProbability > 20 {
                    // Show only probability if there's a chance but no expected amount
                    HStack(spacing: 2) {
                        Image(systemName: "drop.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.blue.opacity(0.7))
                        Text("\(forecast.precipitationProbability)%")
                            .font(.system(size: 9))
                            .foregroundColor(.blue.opacity(0.7))
                    }
                } else {
                    Spacer()
                }
                
                Spacer(minLength: 4)
                
                // Wind info with directional arrow
                HStack(spacing: 3) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(Double(forecast.windDirection)))
                    
                    Text(forecast.formattedWindSpeed)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .fixedSize(horizontal: true, vertical: false)
            }
        }
        .padding(.vertical, isFirst ? 6 : 2)
        .padding(.horizontal, isFirst ? 8 : 0)
        .background(
            Group {
                if isFirst {
                    // Today's row background
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.blue.opacity(0.08),
                                    Color.blue.opacity(0.05)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.blue.opacity(0.15), lineWidth: 1)
                        )
                } else if isExpanded {
                    // Expanded row background
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.secondary.opacity(0.05))
                } else {
                    // No background
                    Color.clear
                }
            }
        )
        .cornerRadius(isFirst ? 8 : 6)
    }
}

// MARK: - Weather Alert Banner

struct WeatherAlertBanner: View {
    let alert: WeatherAlert
    let isExpanded: Bool
    @Environment(\.openURL) var openURL
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Alert header
            HStack(spacing: 8) {
                Image(systemName: alert.severityIcon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(alert.severityColor)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(alert.eventName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(isExpanded ? nil : 1)
                }
                
                Spacer()
                
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Expanded details
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                    
                    Text(alert.summary)
                        .font(.caption)
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Text(alert.formattedTimeRange)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    if let detailsURL = alert.detailsURL {
                        Button {
                            openURL(detailsURL)
                        } label: {
                            HStack(spacing: 4) {
                                Text("More Details")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Image(systemName: "arrow.up.right.square")
                                    .font(.caption2)
                            }
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.blue)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(alert.severityColor.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(alert.severityColor.opacity(0.3), lineWidth: 1.5)
                )
        )
    }
}

// MARK: - Preview

#Preview {
    VStack {
        ForecastCard(
            station: WeatherStation(
                name: "Test Station",
                macAddress: "00:11:22:33:44:55",
                latitude: 40.7128,
                longitude: -74.0060
            ),
            onTitleChange: { _ in }
        )
    }
    .padding()
    .background(Color(NSColor.windowBackgroundColor))
}

// Preview extension for WeatherStation
extension WeatherStation {
    init(name: String, macAddress: String, latitude: Double? = nil, longitude: Double? = nil) {
        self.name = name
        self.macAddress = macAddress
        self.latitude = latitude
        self.longitude = longitude
        
        // Set other required properties to defaults
        self.isActive = true
        self.lastUpdated = nil
        self.sensorPreferences = SensorPreferences()
        self.customLabels = SensorLabels()
        self.stationType = nil
        self.creationDate = nil
        self.deviceType = nil
        self.timeZoneId = nil
        self.associatedCameraMAC = nil
        self.menuBarLabel = nil
    }
}