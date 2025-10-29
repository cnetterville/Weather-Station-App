//
//  OtherSensorsSection.swift
//  Weather Station App
//
//  Created by Curtis Netterville on 10/25/25.
//

import SwiftUI

struct OtherSensorsSection: View {
    @Binding var station: WeatherStation
    let data: WeatherStationData
    let weatherService: WeatherStationService
    
    var body: some View {
        Group {
            // Enhanced Wind Card
            if station.sensorPreferences.showWind {
                WindCard(
                    station: station,
                    data: data,
                    onTitleChange: { newTitle in
                        station.customLabels.wind = newTitle
                        weatherService.updateStation(station)
                    },
                    getDailyWindStats: {
                        DailyTemperatureCalculator.getDailyWindStats(
                            weatherData: data,
                            historicalData: weatherService.historicalData[station.macAddress],
                            station: station
                        )
                    }
                )
            }
            
            // Pressure Card
            if station.sensorPreferences.showPressure {
                PressureCard(
                    station: station,
                    data: data,
                    onTitleChange: { newTitle in
                        station.customLabels.pressure = newTitle
                        weatherService.updateStation(station)
                    },
                    getDailyPressureStats: {
                        DailyTemperatureCalculator.getDailyPressureStats(
                            weatherData: data,
                            historicalData: weatherService.historicalData[station.macAddress],
                            station: station
                        )
                    }
                )
            }
            
            // Traditional Rainfall Card (if enabled and data available)
            if station.sensorPreferences.showRainfall, let rainfallData = data.rainfall {
                TraditionalRainfallCard(
                    station: station,
                    data: data,
                    rainfallData: rainfallData,
                    onTitleChange: { newTitle in
                        station.customLabels.rainfall = newTitle
                        weatherService.updateStation(station)
                    }
                )
            }
            
            // Piezo Rainfall Card (if enabled)
            if station.sensorPreferences.showRainfallPiezo {
                RainfallCard(
                    station: station,
                    data: data,
                    onTitleChange: { newTitle in
                        station.customLabels.rainfallPiezo = newTitle
                        weatherService.updateStation(station)
                    }
                )
            }
            
            // Air Quality Cards
            AirQualitySensorCards(station: $station, data: data, weatherService: weatherService)
            
            // Enhanced Solar & UV Index Card
            if station.sensorPreferences.showSolar {
                SolarUVCard(
                    station: station,
                    data: data,
                    onTitleChange: { newTitle in
                        station.customLabels.solar = newTitle
                        weatherService.updateStation(station)
                    }
                )
            }
            
            // Lightning Card
            if station.sensorPreferences.showLightning {
                LightningCard(
                    station: station,
                    data: data,
                    onTitleChange: { newTitle in
                        station.customLabels.lightning = newTitle
                        weatherService.updateStation(station)
                    },
                    getLastLightningStats: {
                        DailyTemperatureCalculator.getLastLightningStats(
                            weatherData: data,
                            historicalData: weatherService.historicalData[station.macAddress],
                            station: station,
                            daysToSearch: 30
                        )
                    }
                )
            }
            
            // Battery Status Card
            if station.sensorPreferences.showBatteryStatus {
                BatteryStatusCard(
                    station: station,
                    data: data,
                    onTitleChange: { newTitle in
                        station.customLabels.batteryStatus = newTitle
                        weatherService.updateStation(station)
                    }
                )
            }
            
            // Sunrise/Sunset Card
            if station.sensorPreferences.showSunriseSunset && station.latitude != nil && station.longitude != nil {
                SunriseSunsetCard(
                    station: station,
                    onTitleChange: { newTitle in
                        station.customLabels.sunriseSunset = newTitle
                        weatherService.updateStation(station)
                    }
                )
            }
            
            // Lunar Card
            if station.sensorPreferences.showLunar && station.latitude != nil && station.longitude != nil {
                LunarCard(
                    station: station,
                    onTitleChange: { newTitle in
                        station.customLabels.lunar = newTitle
                        weatherService.updateStation(station)
                    }
                )
            }
            
            // Camera Card (show only for stations with associated cameras)
            if station.sensorPreferences.showCamera && station.associatedCameraMAC != nil {
                CameraTileView(station: station, onTitleChange: { newTitle in
                    station.customLabels.camera = newTitle
                    weatherService.updateStation(station)
                })
            }
            
            // Radar Card (show only for stations with coordinates)
            if station.sensorPreferences.showRadar && station.latitude != nil && station.longitude != nil {
                RadarTileView(station: station, onTitleChange: { newTitle in
                    station.customLabels.radar = newTitle
                    weatherService.updateStation(station)
                })
            }
        }
    }
}

struct AirQualitySensorCards: View {
    @Binding var station: WeatherStation
    let data: WeatherStationData
    let weatherService: WeatherStationService
    
    var body: some View {
        Group {
            // Air Quality Ch1 Card
            if station.sensorPreferences.showAirQualityCh1 && data.pm25Ch1.pm25.value != "0" && !data.pm25Ch1.pm25.value.isEmpty {
                AirQualityCard(
                    title: station.customLabels.airQualityCh1,
                    data: data.pm25Ch1,
                    systemImage: "aqi.medium",
                    onTitleChange: { newTitle in
                        station.customLabels.airQualityCh1 = newTitle
                        weatherService.updateStation(station)
                    },
                    getDailyPM25Stats: {
                        DailyTemperatureCalculator.getDailyPM25Ch1Stats(
                            weatherData: data,
                            historicalData: weatherService.historicalData[station.macAddress],
                            station: station
                        )
                    }
                )
            }
            
            // Air Quality Ch2 Card (if enabled and has data)
            if station.sensorPreferences.showAirQualityCh2,
               let pm25Ch2 = data.pm25Ch2,
               pm25Ch2.pm25.value != "0" && !pm25Ch2.pm25.value.isEmpty {
                AirQualityCard(
                    title: station.customLabels.airQualityCh2,
                    data: pm25Ch2,
                    systemImage: "aqi.medium",
                    onTitleChange: { newTitle in
                        station.customLabels.airQualityCh2 = newTitle
                        weatherService.updateStation(station)
                    },
                    getDailyPM25Stats: {
                        DailyTemperatureCalculator.getDailyPM25Ch2Stats(
                            weatherData: data,
                            historicalData: weatherService.historicalData[station.macAddress],
                            station: station
                        )
                    }
                )
            }
            
            // Air Quality Ch3 Card (if enabled and has data)
            if station.sensorPreferences.showAirQualityCh3,
               let pm25Ch3 = data.pm25Ch3,
               pm25Ch3.pm25.value != "0" && !pm25Ch3.pm25.value.isEmpty {
                AirQualityCard(
                    title: station.customLabels.airQualityCh3,
                    data: pm25Ch3,
                    systemImage: "aqi.medium",
                    onTitleChange: { newTitle in
                        station.customLabels.airQualityCh3 = newTitle
                        weatherService.updateStation(station)
                    },
                    getDailyPM25Stats: {
                        DailyTemperatureCalculator.getDailyPM25Ch3Stats(
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