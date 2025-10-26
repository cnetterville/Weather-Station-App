//
//  WeatherData.swift
//  Weather Station App
//
//  Created by Curtis Netterville on 10/25/25.
//

import Foundation

struct WeatherStationResponse: Codable {
    let code: Int
    let msg: String
    let time: String
    let data: WeatherStationData
}

struct WeatherStationData: Codable {
    let outdoor: OutdoorData
    let indoor: IndoorData
    let solarAndUvi: SolarAndUVIData
    let rainfall: RainfallData? // Made optional
    let rainfallPiezo: RainfallPiezoData
    let wind: WindData
    let pressure: PressureData
    let lightning: LightningData
    let pm25Ch1: PM25Data
    let pm25Ch2: PM25Data? // Made optional
    let tempAndHumidityCh1: TempHumidityData
    let tempAndHumidityCh2: TempHumidityData
    let tempAndHumidityCh3: TempHumidityData? // Made optional
    let battery: BatteryData
    
    enum CodingKeys: String, CodingKey {
        case outdoor, indoor, wind, pressure, lightning, battery
        case solarAndUvi = "solar_and_uvi"
        case rainfall
        case rainfallPiezo = "rainfall_piezo"
        case pm25Ch1 = "pm25_ch1"
        case pm25Ch2 = "pm25_ch2"
        case tempAndHumidityCh1 = "temp_and_humidity_ch1"
        case tempAndHumidityCh2 = "temp_and_humidity_ch2"
        case tempAndHumidityCh3 = "temp_and_humidity_ch3"
    }
}

struct MeasurementData: Codable {
    let time: String
    let unit: String
    let value: String
}

struct OutdoorData: Codable {
    let temperature: MeasurementData
    let feelsLike: MeasurementData
    let appTemp: MeasurementData
    let dewPoint: MeasurementData
    let vpd: MeasurementData
    let humidity: MeasurementData
    
    enum CodingKeys: String, CodingKey {
        case temperature, humidity
        case feelsLike = "feels_like"
        case appTemp = "app_temp"
        case dewPoint = "dew_point"
        case vpd
    }
}

struct IndoorData: Codable {
    let temperature: MeasurementData
    let humidity: MeasurementData
    let dewPoint: MeasurementData
    let feelsLike: MeasurementData
    let appTempIn: MeasurementData
    
    enum CodingKeys: String, CodingKey {
        case temperature, humidity
        case dewPoint = "dew_point"
        case feelsLike = "feels_like"
        case appTempIn = "app_tempin"
    }
}

struct SolarAndUVIData: Codable {
    let solar: MeasurementData
    let uvi: MeasurementData
}

struct RainfallData: Codable {
    let rainRate: MeasurementData
    let daily: MeasurementData
    let event: MeasurementData
    let oneHour: MeasurementData
    let twentyFourHours: MeasurementData
    let weekly: MeasurementData
    let monthly: MeasurementData
    let yearly: MeasurementData
    
    enum CodingKeys: String, CodingKey {
        case daily, event, weekly, monthly, yearly
        case rainRate = "rain_rate"
        case oneHour = "1_hour"
        case twentyFourHours = "24_hours"
    }
}

struct RainfallPiezoData: Codable {
    let rainRate: MeasurementData
    let daily: MeasurementData
    let state: MeasurementData
    let event: MeasurementData
    let oneHour: MeasurementData
    let twentyFourHours: MeasurementData
    let weekly: MeasurementData
    let monthly: MeasurementData
    let yearly: MeasurementData
    
    enum CodingKeys: String, CodingKey {
        case daily, event, weekly, monthly, yearly, state
        case rainRate = "rain_rate"
        case oneHour = "1_hour"
        case twentyFourHours = "24_hours"
    }
}

struct WindData: Codable {
    let windSpeed: MeasurementData
    let windGust: MeasurementData
    let windDirection: MeasurementData
    let tenMinuteAverageWindDirection: MeasurementData
    
    enum CodingKeys: String, CodingKey {
        case windSpeed = "wind_speed"
        case windGust = "wind_gust"
        case windDirection = "wind_direction"
        case tenMinuteAverageWindDirection = "10_minute_average_wind_direction"
    }
}

struct PressureData: Codable {
    let relative: MeasurementData
    let absolute: MeasurementData
}

struct LightningData: Codable {
    let distance: MeasurementData
    let count: MeasurementData
}

struct PM25Data: Codable {
    let realTimeAqi: MeasurementData
    let pm25: MeasurementData
    let twentyFourHoursAqi: MeasurementData
    
    enum CodingKeys: String, CodingKey {
        case pm25
        case realTimeAqi = "real_time_aqi"
        case twentyFourHoursAqi = "24_hours_aqi"
    }
}

struct TempHumidityData: Codable {
    let temperature: MeasurementData
    let humidity: MeasurementData?
}

struct BatteryData: Codable {
    let console: MeasurementData?
    let hapticArrayBattery: MeasurementData?
    let hapticArrayCapacitor: MeasurementData?
    let rainfallSensor: MeasurementData?
    let lightningSensor: MeasurementData?
    let pm25SensorCh1: MeasurementData?
    let pm25SensorCh2: MeasurementData?
    let tempHumiditySensorCh1: MeasurementData?
    let tempHumiditySensorCh2: MeasurementData?
    let tempHumiditySensorCh3: MeasurementData?
    
    enum CodingKeys: String, CodingKey {
        case console
        case hapticArrayBattery = "haptic_array_battery"
        case hapticArrayCapacitor = "haptic_array_capacitor"
        case rainfallSensor = "rainfall_sensor"
        case lightningSensor = "lightning_sensor"
        case pm25SensorCh1 = "pm25_sensor_ch1"
        case pm25SensorCh2 = "pm25_sensor_ch2"
        case tempHumiditySensorCh1 = "temp_humidity_sensor_ch1"
        case tempHumiditySensorCh2 = "temp_humidity_sensor_ch2"
        case tempHumiditySensorCh3 = "temp_humidity_sensor_ch3"
    }
}