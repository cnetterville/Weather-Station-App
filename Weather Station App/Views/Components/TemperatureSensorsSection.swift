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
                        DailyTemperatureCalculator.getDailyStats(
                            weatherData: data,
                            historicalData: weatherService.historicalData[station.macAddress],
                            station: station
                        )
                    },
                    getDailyHumidityStats: {
                        DailyTemperatureCalculator.getDailyHumidityStats(
                            weatherData: data,
                            historicalData: weatherService.historicalData[station.macAddress],
                            station: station
                        )
                    }
                )
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
                        DailyTemperatureCalculator.getIndoorDailyStats(
                            weatherData: data,
                            historicalData: weatherService.historicalData[station.macAddress],
                            station: station
                        )
                    },
                    getDailyHumidityStats: {
                        DailyTemperatureCalculator.getIndoorDailyHumidityStats(
                            weatherData: data,
                            historicalData: weatherService.historicalData[station.macAddress],
                            station: station
                        )
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
                        DailyTemperatureCalculator.getTempHumidityCh1DailyStats(
                            weatherData: data,
                            historicalData: weatherService.historicalData[station.macAddress],
                            station: station
                        )
                    },
                    getDailyHumidityStats: {
                        DailyTemperatureCalculator.getTempHumidityCh1DailyHumidityStats(
                            weatherData: data,
                            historicalData: weatherService.historicalData[station.macAddress],
                            station: station
                        )
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
                        DailyTemperatureCalculator.getTempHumidityCh2DailyStats(
                            weatherData: data,
                            historicalData: weatherService.historicalData[station.macAddress],
                            station: station
                        )
                    },
                    getDailyHumidityStats: {
                        DailyTemperatureCalculator.getTempHumidityCh2DailyHumidityStats(
                            weatherData: data,
                            historicalData: weatherService.historicalData[station.macAddress],
                            station: station
                        )
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
                        DailyTemperatureCalculator.getTempHumidityCh3DailyStats(
                            weatherData: data,
                            historicalData: weatherService.historicalData[station.macAddress],
                            station: station
                        )
                    },
                    getDailyHumidityStats: {
                        DailyTemperatureCalculator.getTempHumidityCh3DailyHumidityStats(
                            weatherData: data,
                            historicalData: weatherService.historicalData[station.macAddress],
                            station: station
                        )
                    }
                )
            }
        }
    }
}