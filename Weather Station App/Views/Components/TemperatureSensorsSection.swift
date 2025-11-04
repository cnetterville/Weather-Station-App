//
//  TemperatureSensorsSection.swift
//  Weather Station App
//
//  Created by Curtis Netterville on 10/25/25.
//

import SwiftUI

struct TemperatureSensorsSection: View {
    @Binding var station: WeatherStation
    let data: WeatherStationData
    let weatherService: WeatherStationService
    
    var body: some View {
        Group {
            // Outdoor Temperature Card with Daily High/Low
            if station.sensorPreferences.showOutdoorTemp {
                OutdoorTemperatureCard(
                    station: station,
                    data: data,
                    onTitleChange: { newTitle in
                        station.customLabels.outdoorTemp = newTitle
                        weatherService.updateStation(station)
                    },
                    getDailyTemperatureStats: {
                        // Use flexible stats that fall back to available data
                        DailyTemperatureCalculator.getFlexibleDailyStats(
                            weatherData: data,
                            historicalData: weatherService.historicalData[station.macAddress],
                            station: station
                        )
                    },
                    getDailyHumidityStats: {
                        // Try daily stats first, then fall back to available data
                        if let dailyStats = DailyTemperatureCalculator.getDailyHumidityStats(
                            weatherData: data,
                            historicalData: weatherService.historicalData[station.macAddress],
                            station: station
                        ) {
                            return dailyStats
                        }
                        // Fallback to available data
                        guard let historical = weatherService.historicalData[station.macAddress] else { return nil }
                        return DailyTemperatureCalculator.calculateHumidityStatsFromAvailableData(from: historical.outdoor)
                    }
                )
            }
            
            // 5-Day Weather Forecast Card
            if station.sensorPreferences.showForecast {
                ForecastCard(
                    station: station,
                    onTitleChange: { newTitle in
                        var updatedStation = station
                        updatedStation.customLabels.forecast = newTitle
                        station = updatedStation
                        weatherService.updateStation(station)
                    }
                )
            }
            
            // Radar Card (show only for stations with coordinates) - Moved here after forecast
            if station.sensorPreferences.showRadar && station.latitude != nil && station.longitude != nil {
                RadarTileView(station: station, onTitleChange: { newTitle in
                    station.customLabels.radar = newTitle
                    weatherService.updateStation(station)
                })
            }
            
            // Indoor Temperature Card
            if station.sensorPreferences.showIndoorTemp {
                IndoorTemperatureCard(
                    station: station,
                    data: data,
                    onTitleChange: { newTitle in
                        station.customLabels.indoorTemp = newTitle
                        weatherService.updateStation(station)
                    },
                    getDailyTemperatureStats: {
                        // Use flexible stats that fall back to available data
                        DailyTemperatureCalculator.getFlexibleIndoorDailyStats(
                            weatherData: data,
                            historicalData: weatherService.historicalData[station.macAddress],
                            station: station
                        )
                    },
                    getDailyHumidityStats: {
                        // Try daily stats first, then fall back to available data
                        if let dailyStats = DailyTemperatureCalculator.getIndoorDailyHumidityStats(
                            weatherData: data,
                            historicalData: weatherService.historicalData[station.macAddress],
                            station: station
                        ) {
                            return dailyStats
                        }
                        // Fallback to available data
                        guard let historical = weatherService.historicalData[station.macAddress] else { return nil }
                        return DailyTemperatureCalculator.calculateIndoorHumidityStatsFromAvailableData(from: historical.indoor)
                    }
                )
            }
            
            // Additional Temperature/Humidity Ch1 Sensor
            if station.sensorPreferences.showTempHumidityCh1 {
                ChannelTemperatureCard(
                    station: station,
                    data: data.tempAndHumidityCh1,
                    title: station.customLabels.tempHumidityCh1,
                    onTitleChange: { newTitle in
                        station.customLabels.tempHumidityCh1 = newTitle
                        weatherService.updateStation(station)
                    },
                    getDailyTemperatureStats: {
                        // Use flexible stats that fall back to available data
                        DailyTemperatureCalculator.getFlexibleTempHumidityCh1DailyStats(
                            weatherData: data,
                            historicalData: weatherService.historicalData[station.macAddress],
                            station: station
                        )
                    },
                    getDailyHumidityStats: {
                        // Try daily stats first, then fall back to available data
                        if let dailyStats = DailyTemperatureCalculator.getTempHumidityCh1DailyHumidityStats(
                            weatherData: data,
                            historicalData: weatherService.historicalData[station.macAddress],
                            station: station
                        ) {
                            return dailyStats
                        }
                        // Fallback to available data
                        guard let historical = weatherService.historicalData[station.macAddress] else { return nil }
                        return DailyTemperatureCalculator.calculateChannelHumidityStatsFromAvailableData(from: historical.tempAndHumidityCh1)
                    }
                )
            }
            
            // Additional Temperature/Humidity Ch2 Sensor
            if station.sensorPreferences.showTempHumidityCh2 {
                ChannelTemperatureCard(
                    station: station,
                    data: data.tempAndHumidityCh2,
                    title: station.customLabels.tempHumidityCh2,
                    onTitleChange: { newTitle in
                        station.customLabels.tempHumidityCh2 = newTitle
                        weatherService.updateStation(station)
                    },
                    getDailyTemperatureStats: {
                        // Use flexible stats that fall back to available data
                        DailyTemperatureCalculator.getFlexibleTempHumidityCh2DailyStats(
                            weatherData: data,
                            historicalData: weatherService.historicalData[station.macAddress],
                            station: station
                        )
                    },
                    getDailyHumidityStats: {
                        // Try daily stats first, then fall back to available data
                        if let dailyStats = DailyTemperatureCalculator.getTempHumidityCh2DailyHumidityStats(
                            weatherData: data,
                            historicalData: weatherService.historicalData[station.macAddress],
                            station: station
                        ) {
                            return dailyStats
                        }
                        // Fallback to available data
                        guard let historical = weatherService.historicalData[station.macAddress] else { return nil }
                        return DailyTemperatureCalculator.calculateChannelHumidityStatsFromAvailableData(from: historical.tempAndHumidityCh2)
                    }
                )
            }
            
            // Additional Temperature/Humidity Ch3 Sensor
            if station.sensorPreferences.showTempHumidityCh3, let tempHumCh3 = data.tempAndHumidityCh3 {
                ChannelTemperatureCard(
                    station: station,
                    data: tempHumCh3,
                    title: station.customLabels.tempHumidityCh3,
                    onTitleChange: { newTitle in
                        station.customLabels.tempHumidityCh3 = newTitle
                        weatherService.updateStation(station)
                    },
                    getDailyTemperatureStats: {
                        // Use flexible stats that fall back to available data
                        DailyTemperatureCalculator.getFlexibleTempHumidityCh3DailyStats(
                            weatherData: data,
                            historicalData: weatherService.historicalData[station.macAddress],
                            station: station
                        )
                    },
                    getDailyHumidityStats: {
                        // Try daily stats first, then fall back to available data
                        if let dailyStats = DailyTemperatureCalculator.getTempHumidityCh3DailyHumidityStats(
                            weatherData: data,
                            historicalData: weatherService.historicalData[station.macAddress],
                            station: station
                        ) {
                            return dailyStats
                        }
                        // Fallback to available data
                        guard let historical = weatherService.historicalData[station.macAddress] else { return nil }
                        return DailyTemperatureCalculator.calculateChannelHumidityStatsFromAvailableData(from: historical.tempAndHumidityCh3)
                    }
                )
            }
        }
    }
}