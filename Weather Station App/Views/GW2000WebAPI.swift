//
//  GW2000WebAPI.swift
//  Weather Station App
//
//  HTTP-based API for GW2000/GW1100 web interface
//

import Foundation

class GW2000WebAPI {
    private let baseURL: String
    
    init(host: String, port: UInt16 = 80) {
        self.baseURL = "http://\(host):\(port)"
    }
    
    struct SensorInfo: Codable, Identifiable {
        let id: UUID = UUID()
        let type: String
        let name: String
        let sensorId: String  // "id" in JSON
        let battery: String   // "batt" in JSON
        let signal: String
        let rssi: String?
        let idst: String      // "1" = enabled, "0" = disabled
        let img: String?
        let version: String?
        
        enum CodingKeys: String, CodingKey {
            case type
            case name
            case sensorId = "id"
            case battery = "batt"
            case signal
            case rssi
            case idst
            case img
            case version
        }
        
        var displayID: String {
            if sensorId == "FFFFFFFE" {
                return "Disabled"
            } else if sensorId == "FFFFFFFF" {
                return "Learning"
            } else {
                return "0x\(sensorId)"
            }
        }
        
        var batteryStatus: BatteryStatus {
            if battery == "0" || battery.isEmpty {
                return .normal
            } else if battery == "9" {
                return .unknown
            } else if let battLevel = Int(battery) {
                switch battLevel {
                case 1: return .critical
                case 2: return .low
                case 3: return .medium
                default: return .normal
                }
            }
            return .unknown
        }
        
        var signalStrength: SignalStrength {
            guard let signalLevel = Int(signal) else { return .unknown }
            switch signalLevel {
            case 4: return .excellent
            case 3: return .good
            case 2: return .fair
            case 1: return .poor
            default: return .unknown
            }
        }
        
        var rssiValue: Int? {
            guard let rssi = rssi, rssi != "--" else { return nil }
            return Int(rssi)
        }
        
        var isEnabled: Bool {
            return idst == "1"
        }
    }
    
    enum BatteryStatus {
        case normal, low, medium, critical, unknown
        
        var description: String {
            switch self {
            case .normal: return "Normal"
            case .low: return "Low"
            case .medium: return "Medium"
            case .critical: return "Critical"
            case .unknown: return "Unknown"
            }
        }
        
        var icon: String {
            switch self {
            case .normal: return "battery.100"
            case .medium: return "battery.75"
            case .low: return "battery.25"
            case .critical: return "battery.0"
            case .unknown: return "battery.0"
            }
        }
    }
    
    enum SignalStrength: Int {
        case excellent = 4
        case good = 3
        case fair = 2
        case poor = 1
        case unknown = 0
        
        var description: String {
            switch self {
            case .excellent: return "Excellent"
            case .good: return "Good"
            case .fair: return "Fair"
            case .poor: return "Poor"
            case .unknown: return "Unknown"
            }
        }
        
        var icon: String {
            switch self {
            case .excellent: return "wifi"
            case .good: return "wifi"
            case .fair: return "wifi.exclamationmark"
            case .poor: return "wifi.slash"
            case .unknown: return "antenna.radiowaves.left.and.right.slash"
            }
        }
    }
    
    // MARK: - API Methods
    
    func getSensorInfo(page: Int = 1) async throws -> [SensorInfo] {
        let urlString = "\(baseURL)/get_sensors_info?page=\(page)"
        
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "GW2000WebAPI", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Invalid URL: \(urlString)"
            ])
        }
        
        print("📡 Fetching sensor info from: \(urlString)")
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "GW2000WebAPI", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Invalid response"
            ])
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NSError(domain: "GW2000WebAPI", code: httpResponse.statusCode, userInfo: [
                NSLocalizedDescriptionKey: "HTTP error: \(httpResponse.statusCode)"
            ])
        }
        
        // Parse JSON response
        do {
            let sensors = try JSONDecoder().decode([SensorInfo].self, from: data)
            print("✅ Successfully retrieved \(sensors.count) sensors")
            return sensors
        } catch {
            print("❌ JSON parsing error: \(error)")
            print("   Response data: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
            throw NSError(domain: "GW2000WebAPI", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to parse sensor data: \(error.localizedDescription)"
            ])
        }
    }
    
    func getAllSensors(includeInactive: Bool = false) async throws -> [SensorInfo] {
        // Fetch first page
        var allSensors = try await getSensorInfo(page: 1)
        
        // If there are sensors and potentially more pages, try page 2
        // Most devices only have 1-2 pages
        if allSensors.count >= 10 {
            do {
                let page2Sensors = try await getSensorInfo(page: 2)
                if !page2Sensors.isEmpty {
                    allSensors.append(contentsOf: page2Sensors)
                }
            } catch {
                // Page 2 doesn't exist, that's fine
                print("ℹ️ No second page of sensors")
            }
        }
        
        print("📊 Total sensors retrieved: \(allSensors.count)")
        
        // Filter out sensors without active data
        if !includeInactive {
            let beforeCount = allSensors.count
            allSensors = allSensors.filter { sensor in
                // Exclude disabled sensors (FFFFFFFE)
                guard sensor.sensorId.uppercased() != "FFFFFFFE" else {
                    print("🚫 Filtering out disabled sensor: \(sensor.name)")
                    return false
                }
                
                // Exclude learning/unpaired sensors (FFFFFFFF)
                guard sensor.sensorId.uppercased() != "FFFFFFFF" else {
                    print("🚫 Filtering out learning sensor: \(sensor.name)")
                    return false
                }
                
                // Exclude disabled sensors (idst = "0")
                guard sensor.isEnabled else {
                    print("🚫 Filtering out inactive sensor: \(sensor.name)")
                    return false
                }
                
                // Include sensors with valid IDs
                print("✅ Including active sensor: \(sensor.name)")
                return true
            }
            print("📊 Active sensors after filtering: \(allSensors.count) (filtered out \(beforeCount - allSensors.count))")
        }
        
        return allSensors
    }
    
    func testConnection() async throws -> Bool {
        let sensors = try await getSensorInfo(page: 1)
        return !sensors.isEmpty
    }
}
