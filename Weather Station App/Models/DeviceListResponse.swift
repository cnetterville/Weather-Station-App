//
//  DeviceListResponse.swift
//  Weather Station App
//
//  Created by Curtis Netterville on 10/25/25.
//

import Foundation

struct DeviceListResponse: Codable {
    let code: Int
    let msg: String
    let time: String
    let data: DeviceListData
}

struct DeviceListData: Codable {
    let total: Int
    let totalPage: Int
    let pageNum: Int
    let list: [EcowittDevice]
}

struct EcowittDevice: Codable {
    let id: Int
    let name: String
    let mac: String
    let type: Int
    let dateZoneId: String?
    let createtime: Int?
    let longitude: Double?
    let latitude: Double?
    let stationtype: String?
    let iotdeviceList: [String]?
    
    enum CodingKeys: String, CodingKey {
        case id, name, mac, type, createtime, longitude, latitude, stationtype
        case dateZoneId = "date_zone_id"
        case iotdeviceList = "iotdevice_list"
    }
    
    // Convert to WeatherStation
    func toWeatherStation() -> WeatherStation {
        var station = WeatherStation(name: name, macAddress: mac)
        
        // Set creation date based on createtime if available
        if let createtime = createtime {
            station.creationDate = Date(timeIntervalSince1970: TimeInterval(createtime))
            // Also set lastUpdated initially to creation date
            station.lastUpdated = Date(timeIntervalSince1970: TimeInterval(createtime))
        }
        
        // Set station type and device type
        station.stationType = stationtype
        station.deviceType = type
        
        // Set location data
        station.latitude = latitude
        station.longitude = longitude
        
        return station
    }
}