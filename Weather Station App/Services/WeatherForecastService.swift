//
//  WeatherForecastService.swift
//  Weather Station App
//
//  Created by Curtis Netterville on 10/25/25.
//

import Foundation
import Combine

class WeatherForecastService: ObservableObject {
    static let shared = WeatherForecastService()
    
    // Open-Meteo API endpoint
    private let baseURL = "https://api.open-meteo.com/v1/forecast"
    
    @Published var forecasts: [String: WeatherForecast] = [:] // Key: station MAC address
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let session: URLSession
    private var loadingTasks: [String: Task<Void, Never>] = [:]
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0
        config.timeoutIntervalForResource = 60.0
        config.requestCachePolicy = .useProtocolCachePolicy
        self.session = URLSession(configuration: config)
    }
    
    /// Fetch 5-day forecast for a weather station using its coordinates
    func fetchForecast(for station: WeatherStation) async {
        guard let latitude = station.latitude, let longitude = station.longitude else {
            await MainActor.run {
                errorMessage = "No coordinates available for \(station.name)"
            }
            print("⚠️ No coordinates for station: \(station.name)")
            return
        }
        
        // Check if we already have fresh data
        if let existingForecast = forecasts[station.macAddress], !existingForecast.isExpired {
            print("📊 Using cached forecast for \(station.name)")
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
        
        // Build Open-Meteo API URL
        var urlComponents = URLComponents(string: baseURL)
        urlComponents?.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "daily", value: "weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum,wind_speed_10m_max,wind_direction_10m_dominant"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "forecast_days", value: "5") // Changed from 4 to 5
        ]
        
        guard let url = urlComponents?.url else {
            await MainActor.run {
                errorMessage = "Invalid forecast URL for \(station.name)"
                isLoading = false
            }
            return
        }
        
        print("🌤️ Fetching 5-day forecast for \(station.name) at (\(latitude), \(longitude))") // Updated log message
        print("📍 URL: \(url.absoluteString)")
        
        do {
            let (data, response) = try await session.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 Forecast HTTP Status: \(httpResponse.statusCode)")
                
                guard httpResponse.statusCode == 200 else {
                    await MainActor.run {
                        errorMessage = "Forecast API returned HTTP \(httpResponse.statusCode)"
                        isLoading = false
                    }
                    return
                }
            }
            
            print("📦 Forecast response: \(data.count) bytes")
            
            // Parse the response
            let decoder = JSONDecoder()
            let forecastResponse = try decoder.decode(ForecastResponse.self, from: data)
            
            // Convert to our processed model
            let processedForecast = processForecastResponse(forecastResponse, for: station)
            
            await MainActor.run {
                forecasts[station.macAddress] = processedForecast
                isLoading = false
                errorMessage = nil
                
                print("✅ 5-day forecast updated for \(station.name): \(processedForecast.dailyForecasts.count) days") // Updated log message
            }
            
        } catch {
            await MainActor.run {
                errorMessage = "Failed to fetch forecast for \(station.name): \(error.localizedDescription)"
                isLoading = false
            }
            print("❌ Forecast error for \(station.name): \(error)")
        }
        
        // Clean up completed task
        loadingTasks.removeValue(forKey: station.macAddress)
    }
    
    private func processForecastResponse(_ response: ForecastResponse, for station: WeatherStation) -> WeatherForecast {
        let location = ForecastLocation(
            latitude: response.latitude,
            longitude: response.longitude,
            timezone: response.timezone,
            elevation: response.elevation
        )
        
        var dailyForecasts: [DailyWeatherForecast] = []
        
        // Process each day
        for i in 0..<response.daily.time.count {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            dateFormatter.timeZone = TimeZone(identifier: response.timezone) ?? TimeZone.current
            
            if let date = dateFormatter.date(from: response.daily.time[i]) {
                let forecast = DailyWeatherForecast(
                    date: date,
                    weatherCode: response.daily.weatherCode[i],
                    maxTemperature: response.daily.temperature2mMax[i],
                    minTemperature: response.daily.temperature2mMin[i],
                    precipitation: response.daily.precipitationSum[i],
                    maxWindSpeed: response.daily.windSpeed10mMax[i],
                    windDirection: response.daily.windDirection10mDominant[i]
                )
                dailyForecasts.append(forecast)
            }
        }
        
        return WeatherForecast(
            location: location,
            dailyForecasts: dailyForecasts,
            lastUpdated: Date()
        )
    }
    
    /// Fetch forecasts for all active weather stations that have coordinates
    func fetchForecastsForAllStations(_ stations: [WeatherStation]) async {
        let stationsWithCoordinates = stations.filter { station in
            station.isActive && station.latitude != nil && station.longitude != nil
        }
        
        guard !stationsWithCoordinates.isEmpty else {
            print("⚠️ No stations with coordinates found")
            return
        }
        
        print("🌤️ Fetching forecasts for \(stationsWithCoordinates.count) stations")
        
        // Fetch forecasts concurrently with a limit to avoid overwhelming the API
        await withTaskGroup(of: Void.self) { group in
            for station in stationsWithCoordinates.prefix(5) { // Limit to 5 concurrent requests
                group.addTask {
                    await self.fetchForecast(for: station)
                    
                    // Small delay between requests to be respectful to the free API
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
        print("🗑️ Cleared all cached forecasts")
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

// MARK: - Notification Extensions

extension Notification.Name {
    static let forecastDataUpdated = Notification.Name("ForecastDataUpdated")
}