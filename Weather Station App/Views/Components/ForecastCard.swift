//
//  ForecastCard.swift
//  Weather Station App
//
//  Created by Curtis Netterville on 10/25/25.
//

import SwiftUI

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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Forecast header with last updated time
            HStack {
                Text("5-Day Forecast")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if let age = forecastService.getForecastAge(for: station) {
                    Text(age)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // Daily forecast items
            LazyVStack(spacing: 8) {
                ForEach(Array(forecast.dailyForecasts.enumerated()), id: \.offset) { index, dailyForecast in
                    ForecastDayRow(
                        forecast: dailyForecast,
                        isFirst: index == 0
                    )
                    
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
    }
}

struct ForecastDayRow: View {
    let forecast: DailyWeatherForecast
    let isFirst: Bool
    
    var body: some View {
        VStack(spacing: 2) {
            // Top row: Day, Icon, Description, Temperature
            HStack(spacing: 8) {
                // Day
                Text(forecast.displayDay)
                    .font(.system(size: isFirst ? 14 : 13, weight: isFirst ? .semibold : .medium))
                    .foregroundColor(isFirst ? .primary : .secondary)
                    .frame(width: 45, alignment: .leading)
                
                // Weather icon
                Image(systemName: forecast.weatherIcon)
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
                    .frame(width: 18)
                
                // Weather description
                Text(forecast.weatherDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                Spacer()
                
                // Temperature range
                HStack(spacing: 1) {
                    Text(forecast.formattedMaxTemp)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                        .minimumScaleFactor(0.8)
                    
                    Text("/")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(forecast.formattedMinTemp)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.secondary)
                        .minimumScaleFactor(0.8)
                }
                .frame(width: 65, alignment: .trailing)
            }
            
            // Bottom row: Date, Precipitation, Wind
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
                
                // Precipitation
                if forecast.precipitation > 0.1 {
                    HStack(spacing: 2) {
                        Image(systemName: "drop.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.blue)
                        Text(forecast.formattedPrecipitation)
                            .font(.system(size: 9))
                            .foregroundColor(.blue)
                    }
                } else {
                    Spacer()
                }
                
                Spacer()
                
                // Wind info
                HStack(spacing: 2) {
                    Image(systemName: "wind")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                    
                    Text("\(Int(forecast.maxWindSpeed))km/h \(forecast.windDirectionText)")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                .frame(width: 65, alignment: .trailing)
            }
        }
        .padding(.vertical, isFirst ? 4 : 2)
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