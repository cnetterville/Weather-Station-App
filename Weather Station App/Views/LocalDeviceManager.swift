//
//  LocalDeviceManager.swift
//  Weather Station App
//
//  Manages local GW2000 devices and their associations with weather stations
//

import Foundation
import Combine

class LocalDeviceManager: ObservableObject {
    static let shared = LocalDeviceManager()
    
    @Published var localDevices: [LocalDevice] = []
    @Published var isRefreshing = false
    @Published var lastRefreshTime: Date?
    @Published var errorMessage: String?
    
    private var refreshTimer: AnyCancellable?
    private var autoRefreshInterval: TimeInterval = 300 // 5 minutes default
    
    struct LocalDevice: Identifiable, Codable {
        let id: UUID
        var name: String
        var ipAddress: String
        var associatedStationMAC: String? // MAC address of associated weather station
        var isEnabled: Bool
        var sensors: [SensorData]
        var lastUpdated: Date?
        
        init(id: UUID = UUID(), name: String, ipAddress: String, associatedStationMAC: String? = nil, isEnabled: Bool = true) {
            self.id = id
            self.name = name
            self.ipAddress = ipAddress
            self.associatedStationMAC = associatedStationMAC
            self.isEnabled = isEnabled
            self.sensors = []
            self.lastUpdated = nil
        }
    }
    
    struct SensorData: Identifiable, Codable {
        let id: UUID
        let sensorType: UInt8
        let sensorID: UInt32
        var battery: UInt8
        var signal: UInt8
        var rssi: String? // RSSI value in dBm
        var customLabel: String?
        var lastUpdated: Date
        
        init(from webSensorInfo: GW2000WebAPI.SensorInfo) {
            self.id = UUID()
            // Extract sensor type from the "type" field (hex string)
            if let typeValue = UInt8(webSensorInfo.type, radix: 16) {
                self.sensorType = typeValue
            } else {
                self.sensorType = 0xFF // Unknown
            }
            // Extract sensor ID (hex string without 0x prefix)
            if let idValue = UInt32(webSensorInfo.sensorId, radix: 16) {
                self.sensorID = idValue
            } else {
                self.sensorID = 0
            }
            // Extract battery level
            if let battValue = UInt8(webSensorInfo.battery) {
                self.battery = battValue
            } else {
                self.battery = 0
            }
            // Extract signal level
            if let sigValue = UInt8(webSensorInfo.signal) {
                self.signal = sigValue
            } else {
                self.signal = 0
            }
            // Store RSSI from web API
            self.rssi = webSensorInfo.rssi
            self.customLabel = nil
            self.lastUpdated = Date()
        }
        
        var sensorTypeName: String {
            GW2000LocalAPI.SensorType(rawValue: sensorType)?.description ?? "Unknown (0x\(String(format: "%02X", sensorType)))"
        }
        
        var sensorIcon: String {
            GW2000LocalAPI.SensorType(rawValue: sensorType)?.icon ?? "sensor"
        }
        
        var displayLabel: String {
            customLabel ?? sensorTypeName
        }
        
        var signalStrength: GW2000LocalAPI.SignalStrength {
            // If we have RSSI, use that for more accurate signal strength
            if let rssiString = rssi,
               rssiString != "--",
               !rssiString.isEmpty,
               let rssiValue = Int(rssiString) {
                // Calculate signal strength based on RSSI (in dBm)
                // Industry standard ranges:
                // -50 dBm and closer to 0 = Excellent (max speed & reliability)
                // -51 to -65 dBm = Good (very reliable, suitable for most applications)
                // -66 to -75 dBm = Fair (usable, may experience slowdowns)
                // -76 to -90 dBm = Poor (weak, unreliable connection)
                // -91 dBm and lower = Unusable (connection practically impossible)
                switch rssiValue {
                case -50...0:  // Excellent
                    return .excellent
                case -65..<(-50):  // Good: -51 to -65
                    return .good
                case -75..<(-65):  // Fair: -66 to -75
                    return .fair
                default:  // Poor: -76 and below
                    return .poor
                }
            }
            
            // Fallback to signal bars if no RSSI
            switch signal {
            case 4: return .excellent
            case 3: return .good
            case 2: return .fair
            case 1: return .poor
            default: return .unknown
            }
        }
        
        var batteryLevel: GW2000LocalAPI.BatteryLevel {
            switch battery {
            case 5...6: return .good
            case 3...4: return .medium
            case 1...2: return .low
            case 0: return .critical
            default: return .unknown
            }
        }
    }
    
    private init() {
        loadDevices()
        setupAutoRefresh()
    }
    
    // MARK: - Device Management
    
    func addDevice(_ device: LocalDevice) {
        localDevices.append(device)
        saveDevices()
    }
    
    func updateDevice(_ device: LocalDevice) {
        if let index = localDevices.firstIndex(where: { $0.id == device.id }) {
            localDevices[index] = device
            saveDevices()
        }
    }
    
    func removeDevice(_ device: LocalDevice) {
        localDevices.removeAll { $0.id == device.id }
        saveDevices()
    }
    
    func getDevice(forStationMAC mac: String) -> LocalDevice? {
        return localDevices.first { $0.associatedStationMAC == mac }
    }
    
    func getSensors(forStationMAC mac: String) -> [SensorData] {
        guard let device = getDevice(forStationMAC: mac) else { return [] }
        return device.sensors
    }
    
    // MARK: - Sensor Label Management
    
    func updateSensorLabel(deviceID: UUID, sensorID: UInt32, label: String?) {
        guard let deviceIndex = localDevices.firstIndex(where: { $0.id == deviceID }) else { return }
        guard let sensorIndex = localDevices[deviceIndex].sensors.firstIndex(where: { $0.sensorID == sensorID }) else { return }
        
        localDevices[deviceIndex].sensors[sensorIndex].customLabel = label
        saveDevices()
        
        // Post notification for UI updates
        NotificationCenter.default.post(name: .localDeviceDataUpdated, object: nil)
    }
    
    // MARK: - Data Refresh
    
    func refreshDevice(_ device: LocalDevice) async -> (success: Bool, message: String) {
        guard device.isEnabled else {
            return (false, "Device is disabled")
        }
        
        // Use HTTP API to retrieve sensor data
        let webAPI = GW2000WebAPI(host: device.ipAddress, port: 80)
        
        do {
            print("📡 Fetching sensor data via HTTP API...")
            let sensorInfo = try await webAPI.getAllSensors()
            
            // Update device with new data
            await MainActor.run {
                if let index = localDevices.firstIndex(where: { $0.id == device.id }) {
                    // Preserve custom labels
                    let existingSensors = localDevices[index].sensors
                    var updatedSensors = sensorInfo.map { SensorData(from: $0) }
                    
                    // Restore custom labels
                    for i in 0..<updatedSensors.count {
                        if let existingSensor = existingSensors.first(where: { $0.sensorID == updatedSensors[i].sensorID }) {
                            updatedSensors[i].customLabel = existingSensor.customLabel
                        }
                    }
                    
                    localDevices[index].sensors = updatedSensors
                    localDevices[index].lastUpdated = Date()
                    
                    saveDevices()
                    
                    // Post notification
                    NotificationCenter.default.post(name: .localDeviceDataUpdated, object: nil)
                }
            }
            
            return (true, "✅ Successfully retrieved \(sensorInfo.count) sensor(s)")
            
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
            return (false, "❌ Failed to retrieve sensor data: \(error.localizedDescription)")
        }
    }
    
    func refreshAllDevices() async {
        await MainActor.run {
            isRefreshing = true
            errorMessage = nil
        }
        
        for device in localDevices where device.isEnabled {
            let result = await refreshDevice(device)
            print("📡 Refreshed \(device.name): \(result.message)")
        }
        
        await MainActor.run {
            isRefreshing = false
            lastRefreshTime = Date()
        }
    }
    
    func testConnection(_ device: LocalDevice) async -> (success: Bool, message: String) {
        let webAPI = GW2000WebAPI(host: device.ipAddress, port: 80)
        
        do {
            let sensorInfo = try await webAPI.getAllSensors()
            
            var message = "✅ Connected successfully!\n"
            message += "Found \(sensorInfo.count) sensor(s)"
            
            return (true, message)
            
        } catch {
            return (false, "❌ Connection failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Auto Refresh
    
    private func setupAutoRefresh() {
        // Refresh every 5 minutes by default
        refreshTimer = Timer.publish(every: autoRefreshInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task {
                    await self?.refreshAllDevices()
                }
            }
    }
    
    func setAutoRefreshInterval(_ interval: TimeInterval) {
        autoRefreshInterval = interval
        setupAutoRefresh()
        UserDefaults.standard.set(interval, forKey: "LocalDeviceRefreshInterval")
    }
    
    // MARK: - Persistence
    
    private func loadDevices() {
        if let data = UserDefaults.standard.data(forKey: "LocalDevices"),
           let decoded = try? JSONDecoder().decode([LocalDevice].self, from: data) {
            localDevices = decoded
        }
        
        // Load refresh interval
        let savedInterval = UserDefaults.standard.double(forKey: "LocalDeviceRefreshInterval")
        if savedInterval > 0 {
            autoRefreshInterval = savedInterval
        }
    }
    
    private func saveDevices() {
        if let encoded = try? JSONEncoder().encode(localDevices) {
            UserDefaults.standard.set(encoded, forKey: "LocalDevices")
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let localDeviceDataUpdated = Notification.Name("localDeviceDataUpdated")
}
