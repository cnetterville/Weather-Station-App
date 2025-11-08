//
//  WeatherForecastService.swift
//  Weather Station App
//
//  Created by Curtis Netterville on 10/25/25.
//

import Foundation
import Combine
import WeatherKit
import CoreLocation

class WeatherForecastService: ObservableObject {
    static let shared = WeatherForecastService()
    
    private let weatherService = WeatherService.shared
    
    @Published var forecasts: [String: WeatherForecast] = [:] // Key: station MAC address
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var loadingTasks: [String: Task<Void, Never>] = [:]
    
    private init() {}
    
    /// Fetch 5-day forecast for a weather station using its coordinates
    func fetchForecast(for station: WeatherStation) async {
        guard let latitude = station.latitude, let longitude = station.longitude else {
            await MainActor.run {
                errorMessage = "No coordinates available for \(station.name)"
            }
            logWarning("No coordinates for station: \(station.name)")
            return
        }
        
        // Check if we already have fresh data
        if let existingForecast = forecasts[station.macAddress], !existingForecast.isExpired {
            logData("Using cached forecast for \(station.name)")
            return
        }
        
        // Cancel any existing task for this station
        loadingTasks[station.macAddress]?.cancel()
        
        // Create new loading task
        let task = Task {
            await performForecastRequest(for: station, latitude: latitude, longitude: longitude)
        }
        loadingTasks[station.macAddress] = task
        
        await task.value
    }
    
    private func performForecastRequest(for station: WeatherStation, latitude: Double, longitude: Double) async {
        await MainActor.run {
            isLoading = true
        }
        
        logWeather("Fetching 5-day forecast with hourly data and alerts for \(station.name) at (\(latitude), \(longitude))")
        
        let location = CLLocation(latitude: latitude, longitude: longitude)
        
        do {
            // Request daily and hourly forecast from WeatherKit
            let weather = try await weatherService.weather(for: location)
            
            logData("WeatherKit response received for \(station.name)")
            
            // Get timezone for the location
            let timeZone = station.timeZoneId != nil ? TimeZone(identifier: station.timeZoneId!) ?? TimeZone.current : TimeZone.current
            
            // Convert to our processed model
            let processedForecast = processWeatherKitResponse(
                weather: weather,
                latitude: latitude,
                longitude: longitude,
                timeZone: timeZone,
                for: station
            )
            
            await MainActor.run {
                forecasts[station.macAddress] = processedForecast
                isLoading = false
                errorMessage = nil
                
                if processedForecast.hasActiveAlerts {
                    logSuccess("5-day forecast updated for \(station.name): \(processedForecast.dailyForecasts.count) days, \(processedForecast.hourlyForecasts.count) hours, \(processedForecast.weatherAlerts.count) alerts")
                } else {
                    logSuccess("5-day forecast updated for \(station.name): \(processedForecast.dailyForecasts.count) days, \(processedForecast.hourlyForecasts.count) hours")
                }
            }
            
        } catch {
            await MainActor.run {
                errorMessage = "Failed to fetch forecast for \(station.name): \(error.localizedDescription)"
                isLoading = false
            }
            logError("Forecast error for \(station.name): \(error)")
        }
        
        // Clean up completed task
        loadingTasks.removeValue(forKey: station.macAddress)
    }
    
    private func processWeatherKitResponse(
        weather: Weather,
        latitude: Double,
        longitude: Double,
        timeZone: TimeZone,
        for station: WeatherStation
    ) -> WeatherForecast {
        
        let location = ForecastLocation(
            latitude: latitude,
            longitude: longitude,
            timezone: timeZone.identifier,
            elevation: 0 // WeatherKit doesn't provide elevation in the same way
        )
        
        var dailyForecasts: [DailyWeatherForecast] = []
        
        // Process daily forecasts (limit to 5 days)
        let dailyForecastArray = Array(weather.dailyForecast.forecast.prefix(5))
        
        for dayWeather in dailyForecastArray {
            let weatherCode = WeatherConditionMapper.mapToWeatherCode(dayWeather.condition)
            
            // Convert temperatures from Celsius to our format
            let maxTempC = dayWeather.highTemperature.value
            let minTempC = dayWeather.lowTemperature.value
            
            // Convert precipitation from meters to millimeters
            // Use precipitationAmountByType - sum sleet and hail
            let sleetMM = dayWeather.precipitationAmountByType.sleet.value * 1000.0
            let hailMM = dayWeather.precipitationAmountByType.hail.value * 1000.0
            let precipitationMM = sleetMM + hailMM
            
            // Get precipitation probability (0-100)
            let precipProb = Int((dayWeather.precipitationChance * 100.0).rounded())
            
            // Convert wind speed from m/s to km/h
            let windSpeedKmh = dayWeather.wind.speed.value * 3.6
            
            // Get wind direction in degrees
            let windDirection = Int(dayWeather.wind.direction.value.rounded())
            
            let forecast = DailyWeatherForecast(
                date: dayWeather.date,
                weatherCode: weatherCode,
                maxTemperature: maxTempC,
                minTemperature: minTempC,
                precipitation: precipitationMM,
                precipitationProbability: precipProb,
                maxWindSpeed: windSpeedKmh,
                windDirection: windDirection,
                timezone: timeZone
            )
            dailyForecasts.append(forecast)
        }
        
        var hourlyForecasts: [HourlyWeatherForecast] = []
        
        // Process hourly forecasts (next 24-48 hours typically available)
        let hourlyForecastArray = Array(weather.hourlyForecast.forecast.prefix(48))
        
        for hourWeather in hourlyForecastArray {
            let weatherCode = WeatherConditionMapper.mapToWeatherCode(hourWeather.condition)
            
            // Convert temperature from Celsius
            let tempC = hourWeather.temperature.value
            
            // Get precipitation probability (0-100)
            let precipProb = Int((hourWeather.precipitationChance * 100.0).rounded())
            
            // Convert precipitation from meters to millimeters
            let precipitationMM = (hourWeather.precipitationAmount.value * 1000.0)
            
            // Convert wind speed from m/s to km/h
            let windSpeedKmh = hourWeather.wind.speed.value * 3.6
            
            // Get wind direction in degrees
            let windDirection = Int(hourWeather.wind.direction.value.rounded())
            
            // Get humidity as percentage
            let humidity = Int((hourWeather.humidity * 100.0).rounded())
            
            let forecast = HourlyWeatherForecast(
                time: hourWeather.date,
                temperature: tempC,
                precipitationProbability: precipProb,
                precipitation: precipitationMM,
                weatherCode: weatherCode,
                windSpeed: windSpeedKmh,
                windDirection: windDirection,
                humidity: humidity,
                timezone: timeZone
            )
            hourlyForecasts.append(forecast)
        }
        
        // Process weather alerts
        var weatherAlerts: [WeatherAlert] = []
        
        if let alerts = weather.weatherAlerts {
            logInfo("Found \(alerts.count) weather alerts for \(station.name)")
            
            for alert in alerts {
                // Generate a unique ID using source and current time
                let alertId = "\(alert.source)-\(Date().timeIntervalSince1970)"
                
                // Extract alert details
                let severity = AlertSeverity(fromString: alert.severity.rawValue)
                let source = alert.source
                let eventName = alert.summary
                
                // DEBUG: Use reflection to see all available properties
                logDebug("=== WeatherAlert Properties Debug ===")
                let mirror = Mirror(reflecting: alert)
                for child in mirror.children {
                    if let label = child.label {
                        logDebug("  \(label): \(child.value)")
                    }
                }
                logDebug("=== End Properties Debug ===")
                
                // FIXED: WeatherKit doesn't always provide region data through the simple property
                // Try multiple approaches to extract the affected area
                let region: String
                if let alertRegion = alert.region, !alertRegion.isEmpty {
                    // Use the region property if available (best case)
                    region = alertRegion
                } else {
                    // Fallback: Try to extract region from the summary text
                    // Many NWS alerts include region info like "...for Inland Harris..."
                    if let extractedRegion = extractRegionFromSummary(alert.summary) {
                        region = extractedRegion
                    } else {
                        // Last resort: Use "Affected Area" as generic label
                        region = "Affected Area"
                    }
                }
                
                // Debug logging to understand what we're getting
                logDebug("Alert region info: region='\(alert.region ?? "nil")', extracted='\(region)', source='\(source)', summary='\(alert.summary)'")
                
                let summary = alert.summary
                let detailsURL = alert.detailsURL
                
                // Use current date as fallback for dates (WeatherAlert might not expose all date properties)
                let effectiveTime = Date()
                let expiresTime: Date? = nil
                
                let weatherAlert = WeatherAlert(
                    id: alertId,
                    severity: severity,
                    source: source,
                    eventName: eventName,
                    region: region,
                    summary: summary,
                    detailsURL: detailsURL,
                    effectiveTime: effectiveTime,
                    expiresTime: expiresTime
                )
                weatherAlerts.append(weatherAlert)
            }
            
            logSuccess("Processed \(weatherAlerts.count) weather alerts")
        }
        
        logSuccess("Processed \(dailyForecasts.count) daily and \(hourlyForecasts.count) hourly forecasts")
        
        return WeatherForecast(
            location: location,
            dailyForecasts: dailyForecasts,
            hourlyForecasts: hourlyForecasts,
            weatherAlerts: weatherAlerts,
            lastUpdated: Date()
        )
    }
    
    /// Helper function to extract region information from alert summary text
    /// Many NWS alerts include region info in patterns like "...for [Region]..."
    private func extractRegionFromSummary(_ summary: String) -> String? {
        // Common NWS patterns:
        // "Fire Weather Watch for Inland Harris..."
        // "Flood Warning for Harris County..."
        // "...in Harris County..."
        
        let patterns = [
            "for ([A-Z][A-Za-z\\s]+?)(?:\\.\\.\\.|\\s+in\\s+|\\s+until\\s+|$)",
            "in ([A-Z][A-Za-z\\s]+?)(?:\\.\\.\\.|\\s+until\\s+|\\s+through\\s+|$)",
            "affecting ([A-Z][A-Za-z\\s]+?)(?:\\.\\.\\.|\\s+until\\s+|$)"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: summary, options: [], range: NSRange(summary.startIndex..., in: summary)),
               match.numberOfRanges > 1 {
                let regionRange = match.range(at: 1)
                if let range = Range(regionRange, in: summary) {
                    let extractedRegion = String(summary[range]).trimmingCharacters(in: .whitespaces)
                    // Validate it's not too long (likely not a region name if > 40 chars)
                    if extractedRegion.count <= 40 {
                        return extractedRegion
                    }
                }
            }
        }
        
        return nil
    }
    
    /// Fetch forecasts for all active weather stations that have coordinates
    func fetchForecastsForAllStations(_ stations: [WeatherStation]) async {
        let stationsWithCoordinates = stations.filter { station in
            station.isActive && station.latitude != nil && station.longitude != nil
        }
        
        guard !stationsWithCoordinates.isEmpty else {
            logWarning("No stations with coordinates found")
            return
        }
        
        logWeather("Fetching forecasts for \(stationsWithCoordinates.count) stations")
        
        // Fetch forecasts concurrently
        await withTaskGroup(of: Void.self) { group in
            for station in stationsWithCoordinates {
                group.addTask {
                    await self.fetchForecast(for: station)
                    
                    // Small delay between requests to avoid overwhelming the service
                    try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
                }
            }
        }
    }
    
    /// Get forecast for a specific station
    func getForecast(for station: WeatherStation) -> WeatherForecast? {
        return forecasts[station.macAddress]
    }
    
    /// Check if forecast data is available and fresh
    func hasFreshForecast(for station: WeatherStation) -> Bool {
        guard let forecast = forecasts[station.macAddress] else { return false }
        return !forecast.isExpired
    }
    
    /// Get forecast age for debugging
    func getForecastAge(for station: WeatherStation) -> String? {
        guard let forecast = forecasts[station.macAddress] else { return nil }
        
        let age = Date().timeIntervalSince(forecast.lastUpdated)
        if age < 60 {
            return "\(Int(age))s ago"
        } else if age < 3600 {
            return "\(Int(age / 60))m ago"
        } else {
            return "\(Int(age / 3600))h ago"
        }
    }
    
    /// Clear cached forecasts
    func clearCachedForecasts() {
        forecasts.removeAll()
        logInfo("Cleared all cached forecasts")
    }
    
    /// Force refresh forecast for a specific station (ignores cache)
    func forceRefreshForecast(for station: WeatherStation) async {
        // Remove cached forecast to force a new fetch
        forecasts.removeValue(forKey: station.macAddress)
        logInfo("Forcing forecast refresh for \(station.name)")
        await fetchForecast(for: station)
    }
    
    /// Cancel all loading tasks
    func cancelAllRequests() {
        for task in loadingTasks.values {
            task.cancel()
        }
        loadingTasks.removeAll()
        
        DispatchQueue.main.async {
            self.isLoading = false
        }
    }
}

// MARK: - Weather Condition Mapper

/// Maps WeatherKit's WeatherCondition enum to Open-Meteo style weather codes
/// This maintains compatibility with existing UI code
struct WeatherConditionMapper {
    static func mapToWeatherCode(_ condition: WeatherCondition) -> Int {
        switch condition {
        case .clear:
            return 0 // Clear sky
        case .mostlyClear:
            return 1 // Mainly clear
        case .partlyCloudy:
            return 2 // Partly cloudy
        case .cloudy, .mostlyCloudy:
            return 3 // Overcast
        case .foggy, .haze:
            return 45 // Fog
        case .drizzle:
            return 53 // Moderate drizzle
        case .rain:
            return 63 // Moderate rain
        case .heavyRain:
            return 65 // Heavy rain
        case .freezingDrizzle:
            return 56 // Light freezing drizzle
        case .freezingRain:
            return 67 // Heavy freezing rain
        case .sleet:
            return 66 // Light freezing rain
        case .snow:
            return 73 // Moderate snow fall
        case .heavySnow:
            return 75 // Heavy snow fall
        case .flurries:
            return 71 // Slight snow fall
        case .blowingSnow:
            return 77 // Snow grains
        case .tropicalStorm:
            return 95 // Thunderstorm
        case .hurricane:
            return 99 // Thunderstorm with heavy hail
        case .thunderstorms:
            return 95 // Thunderstorm
        case .scatteredThunderstorms:
            return 95 // Thunderstorm
        case .strongStorms:
            return 96 // Thunderstorm with slight hail
        case .blizzard:
            return 86 // Heavy snow showers
        case .blowingDust, .smoky:
            return 45 // Fog (closest match)
        case .breezy, .windy:
            return 2 // Partly cloudy with wind
        case .wintryMix:
            return 77 // Snow grains
        case .frigid, .hot:
            return 0 // Clear (temperature doesn't affect weather code)
        case .isolatedThunderstorms:
            return 95 // Thunderstorm
        case .hail:
            return 96 // Thunderstorm with hail
        case .sunFlurries:
            return 71 // Slight snow fall with sun
        case .sunShowers:
            return 61 // Slight rain showers with sun
        @unknown default:
            return 0 // Default to clear
        }
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let forecastDataUpdated = Notification.Name("ForecastDataUpdated")
}