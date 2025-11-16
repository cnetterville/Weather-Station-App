//
//  GW2000LocalAPI.swift
//  Weather Station App
//
//  Binary protocol implementation for local GW2000/GW1000 devices
//

import Foundation
@preconcurrency import Network
import Combine
import AppKit

class GW2000LocalAPI: ObservableObject {
    @Published var isConnected = false
    @Published var errorMessage: String?
    
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "com.weatherstation.gw2000", qos: .userInitiated)
    
    // GW2000 Commands
    enum Command: UInt8 {
        case readSensorIDNew = 0x3C  // New sensor ID command (may not work on all devices)
        case readSensorID = 0x3D      // Legacy sensor ID command
        case readFirmware = 0x50
        case readRainData = 0x34
        case readEcowittNetwork = 0x24  // Read Ecowitt network info
        case readLiveData = 0x27        // Read live weather data
    }
    
    // Sensor type definitions from GW2000 protocol
    enum SensorType: UInt8, CaseIterable {
        case wh65 = 0x00           // Outdoor sensor (all-in-one)
        case wh25 = 0x01           // Indoor sensor
        case wh40 = 0x02           // Rain gauge
        case wh26 = 0x03           // External sensor
        case wh31_ch1 = 0x04       // Temp/Humidity Ch1
        case wh31_ch2 = 0x05       // Temp/Humidity Ch2
        case wh31_ch3 = 0x06       // Temp/Humidity Ch3
        case wh31_ch4 = 0x07       // Temp/Humidity Ch4
        case wh31_ch5 = 0x08       // Temp/Humidity Ch5
        case wh31_ch6 = 0x09       // Temp/Humidity Ch6
        case wh31_ch7 = 0x0A       // Temp/Humidity Ch7
        case wh31_ch8 = 0x0B       // Temp/Humidity Ch8
        case wh41_ch1 = 0x0C       // PM2.5 Ch1
        case wh41_ch2 = 0x0D       // PM2.5 Ch2
        case wh41_ch3 = 0x0E       // PM2.5 Ch3
        case wh41_ch4 = 0x0F       // PM2.5 Ch4
        case wh51_ch1 = 0x10       // Soil moisture Ch1
        case wh51_ch2 = 0x11       // Soil moisture Ch2
        case wh51_ch3 = 0x12       // Soil moisture Ch3
        case wh51_ch4 = 0x13       // Soil moisture Ch4
        case wh51_ch5 = 0x14       // Soil moisture Ch5
        case wh51_ch6 = 0x15       // Soil moisture Ch6
        case wh51_ch7 = 0x16       // Soil moisture Ch7
        case wh51_ch8 = 0x17       // Soil moisture Ch8
        case wh55_ch1 = 0x18       // Leak Ch1
        case wh55_ch2 = 0x19       // Leak Ch2
        case wh55_ch3 = 0x1A       // Leak Ch3
        case wh55_ch4 = 0x1B       // Leak Ch4
        case wh57 = 0x1C           // Lightning sensor
        case wh68 = 0x1D           // Anemometer
        case wh80 = 0x1E           // Outdoor sensor (ultrasonic)
        case wh90 = 0x1F           // Haptic rain sensor
        
        var description: String {
            switch self {
            case .wh65: return "Outdoor Sensor"
            case .wh25: return "Indoor Sensor"
            case .wh40: return "Rain Gauge"
            case .wh26: return "External Sensor"
            case .wh31_ch1: return "Temp/Humidity Ch1"
            case .wh31_ch2: return "Temp/Humidity Ch2"
            case .wh31_ch3: return "Temp/Humidity Ch3"
            case .wh31_ch4: return "Temp/Humidity Ch4"
            case .wh31_ch5: return "Temp/Humidity Ch5"
            case .wh31_ch6: return "Temp/Humidity Ch6"
            case .wh31_ch7: return "Temp/Humidity Ch7"
            case .wh31_ch8: return "Temp/Humidity Ch8"
            case .wh41_ch1: return "PM2.5 Ch1"
            case .wh41_ch2: return "PM2.5 Ch2"
            case .wh41_ch3: return "PM2.5 Ch3"
            case .wh41_ch4: return "PM2.5 Ch4"
            case .wh51_ch1: return "Soil Moisture Ch1"
            case .wh51_ch2: return "Soil Moisture Ch2"
            case .wh51_ch3: return "Soil Moisture Ch3"
            case .wh51_ch4: return "Soil Moisture Ch4"
            case .wh51_ch5: return "Soil Moisture Ch5"
            case .wh51_ch6: return "Soil Moisture Ch6"
            case .wh51_ch7: return "Soil Moisture Ch7"
            case .wh51_ch8: return "Soil Moisture Ch8"
            case .wh55_ch1: return "Leak Sensor Ch1"
            case .wh55_ch2: return "Leak Sensor Ch2"
            case .wh55_ch3: return "Leak Sensor Ch3"
            case .wh55_ch4: return "Leak Sensor Ch4"
            case .wh57: return "Lightning Sensor"
            case .wh68: return "Anemometer"
            case .wh80: return "Outdoor Sensor (Ultrasonic)"
            case .wh90: return "Haptic Rain Sensor"
            }
        }
        
        var icon: String {
            switch self {
            case .wh65, .wh80: return "thermometer"
            case .wh25: return "house"
            case .wh40, .wh90: return "cloud.rain"
            case .wh26: return "sensor"
            case .wh31_ch1, .wh31_ch2, .wh31_ch3, .wh31_ch4,
                 .wh31_ch5, .wh31_ch6, .wh31_ch7, .wh31_ch8: return "thermometer.medium"
            case .wh41_ch1, .wh41_ch2, .wh41_ch3, .wh41_ch4: return "aqi.medium"
            case .wh51_ch1, .wh51_ch2, .wh51_ch3, .wh51_ch4,
                 .wh51_ch5, .wh51_ch6, .wh51_ch7, .wh51_ch8: return "drop"
            case .wh55_ch1, .wh55_ch2, .wh55_ch3, .wh55_ch4: return "drop.triangle"
            case .wh57: return "bolt"
            case .wh68: return "wind"
            }
        }
    }
    
    struct SensorInfo: Identifiable, Codable {
        var id: UUID = UUID()
        let sensorType: UInt8
        let sensorID: UInt32
        let battery: UInt8
        let signal: UInt8
        var customLabel: String?
        
        var sensorTypeName: String {
            SensorType(rawValue: sensorType)?.description ?? "Unknown Sensor (0x\(String(format: "%02X", sensorType)))"
        }
        
        var sensorIcon: String {
            SensorType(rawValue: sensorType)?.icon ?? "sensor"
        }
        
        var displayLabel: String {
            customLabel ?? sensorTypeName
        }
        
        var signalStrength: SignalStrength {
            // Signal is typically 0-4 (bars)
            switch signal {
            case 4: return .excellent
            case 3: return .good
            case 2: return .fair
            case 1: return .poor
            default: return .unknown
            }
        }
        
        var batteryLevel: BatteryLevel {
            // Battery levels vary by sensor type
            // For most sensors: 0=critical, 1-2=low, 3-4=medium, 5-6=good
            switch battery {
            case 5...6: return .good
            case 3...4: return .medium
            case 1...2: return .low
            case 0: return .critical
            default: return .unknown
            }
        }
        
        var batteryVoltage: String? {
            // Some sensors report voltage (1-6 range typically means voltage/10)
            guard battery > 0 else { return nil }
            let voltage = Double(battery) / 10.0
            return String(format: "%.1fV", voltage)
        }
    }
    
    enum SignalStrength: Int, Codable {
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
        
        var color: NSColor {
            switch self {
            case .excellent: return .systemGreen
            case .good: return .systemBlue
            case .fair: return .systemOrange
            case .poor: return .systemRed
            case .unknown: return .systemGray
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
        
        var bars: Int {
            rawValue
        }
    }
    
    enum BatteryLevel: Codable {
        case good, medium, low, critical, unknown
        
        var description: String {
            switch self {
            case .good: return "Good"
            case .medium: return "Medium"
            case .low: return "Low"
            case .critical: return "Critical"
            case .unknown: return "Unknown"
            }
        }
        
        var color: NSColor {
            switch self {
            case .good: return .systemGreen
            case .medium: return .systemYellow
            case .low: return .systemOrange
            case .critical: return .systemRed
            case .unknown: return .systemGray
            }
        }
        
        var icon: String {
            switch self {
            case .good: return "battery.100"
            case .medium: return "battery.75"
            case .low: return "battery.25"
            case .critical: return "battery.0"
            case .unknown: return "battery.0"
            }
        }
    }
    
    // MARK: - Connection Management
    
    func connect(to host: String, port: UInt16 = 45000, timeout: TimeInterval = 5.0) async throws {
        // Clean up existing connection
        disconnect()
        
        connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(rawValue: port)!,
            using: .tcp
        )
        
        var connectionEstablished = false
        var connectionError: Error?
        
        connection?.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    self?.isConnected = true
                    self?.errorMessage = nil
                    connectionEstablished = true
                case .failed(let error):
                    self?.isConnected = false
                    self?.errorMessage = "Connection failed: \(error.localizedDescription)"
                    connectionError = error
                case .cancelled:
                    self?.isConnected = false
                default:
                    break
                }
            }
        }
        
        connection?.start(queue: queue)
        
        // Wait for connection with timeout
        let startTime = Date()
        while !connectionEstablished && connectionError == nil {
            if Date().timeIntervalSince(startTime) > timeout {
                throw NSError(domain: "GW2000", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Connection timeout after \(timeout) seconds"
                ])
            }
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        if let error = connectionError {
            throw error
        }
        
        guard connectionEstablished else {
            throw NSError(domain: "GW2000", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to establish connection"
            ])
        }
    }
    
    func disconnect() {
        connection?.cancel()
        connection = nil
        isConnected = false
    }
    
    // MARK: - Command Interface
    
    func readSensorInfo() async throws -> [SensorInfo] {
        guard let connection = connection else {
            throw NSError(domain: "GW2000", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Not connected to device"
            ])
        }
        
        guard isConnected else {
            throw NSError(domain: "GW2000", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Connection not ready"
            ])
        }
        
        // Small delay after connection to ensure device is ready
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        print("🔄 Attempting to read sensor info...")
        
        // Try the legacy command first (0x3D) as it's more compatible
        do {
            print("📡 Trying CMD_READ_SENSOR_ID (0x3D - legacy command)")
            let command = buildCommand(.readSensorID, payload: Data())
            try await sendData(connection, data: command)
            try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
            let responseData = try await receiveData(connection, timeout: 10.0)
            
            // Check if device returned an error code
            if responseData.count >= 3 {
                let responseCmd = responseData[2]
                if responseCmd == 0x5B {
                    print("⚠️ Device returned error code 0x5B (unsupported command)")
                    throw NSError(domain: "GW2000", code: -2, userInfo: [
                        NSLocalizedDescriptionKey: "Device does not support sensor info commands (error code 0x5B). Your device may need a firmware update, or this feature may not be available on your hardware model."
                    ])
                }
            }
            
            let sensors = try parseSensorIDResponse(responseData)
            print("✅ Successfully read \(sensors.count) sensors using legacy command")
            return sensors
        } catch let error as NSError where error.code == -2 {
            // Unsupported command, re-throw
            throw error
        } catch {
            print("⚠️ Legacy command failed: \(error.localizedDescription)")
            print("   Trying new command (0x3C)...")
            
            // Reconnect if needed
            if !isConnected {
                throw NSError(domain: "GW2000", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Connection lost after first attempt"
                ])
            }
            
            // Try the new command (0x3C)
            do {
                let command = buildCommand(.readSensorIDNew, payload: Data())
                try await sendData(connection, data: command)
                try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
                let responseData = try await receiveData(connection, timeout: 10.0)
                
                // Check if device returned an error code
                if responseData.count >= 3 {
                    let responseCmd = responseData[2]
                    if responseCmd == 0x5B {
                        print("⚠️ Device returned error code 0x5B (unsupported command)")
                        throw NSError(domain: "GW2000", code: -2, userInfo: [
                            NSLocalizedDescriptionKey: "Device does not support sensor info commands (error code 0x5B). Your device may need a firmware update, or this feature may not be available on your hardware model."
                        ])
                    }
                }
                
                let sensors = try parseSensorIDResponse(responseData)
                print("✅ Successfully read \(sensors.count) sensors using new command")
                return sensors
            } catch let error as NSError where error.code == -2 {
                // Unsupported command
                throw error
            } catch {
                print("❌ Both sensor ID commands failed")
                throw NSError(domain: "GW2000", code: -3, userInfo: [
                    NSLocalizedDescriptionKey: "Unable to read sensor information from device. This feature may not be supported by your GW2000/GW1100 firmware version. Sensor battery and signal strength monitoring is not available."
                ])
            }
        }
    }
    
    func readFirmwareVersion() async throws -> String {
        guard let connection = connection else {
            throw NSError(domain: "GW2000", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Not connected to device"
            ])
        }
        
        print("📡 Reading firmware version...")
        let command = buildCommand(.readFirmware, payload: Data())
        try await sendData(connection, data: command)
        try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
        let responseData = try await receiveData(connection, timeout: 5.0)
        
        print("📥 Received firmware response: \(responseData.count) bytes")
        
        // Parse firmware version (format varies by device)
        guard responseData.count >= 6 else {
            throw NSError(domain: "GW2000", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Invalid firmware response: only \(responseData.count) bytes"
            ])
        }
        
        // Skip header (5 bytes) and checksum (1 byte at end)
        let versionData = responseData.dropFirst(5).dropLast(1)
        let versionString = String(data: versionData, encoding: .ascii) ?? "Unknown"
        print("✅ Firmware version: \(versionString)")
        return versionString
    }
    
    // MARK: - Protocol Implementation
    
    private func buildCommand(_ cmd: Command, payload: Data) -> Data {
        var command = Data()
        command.append(0xFF) // Header byte 1
        command.append(0xFF) // Header byte 2
        command.append(cmd.rawValue)  // Command
        
        let size = UInt16(payload.count)
        command.append(UInt8(size >> 8))    // Size high byte
        command.append(UInt8(size & 0xFF))  // Size low byte
        
        command.append(payload)
        
        // Calculate checksum (sum of all bytes after header, mod 256)
        var checksum: UInt16 = 0
        for byte in command.dropFirst(2) {
            checksum += UInt16(byte)
        }
        command.append(UInt8(checksum & 0xFF))
        
        // Debug output
        print("📤 Sending command: 0x\(String(format: "%02X", cmd.rawValue))")
        print("   Full command: \(command.map { String(format: "%02X", $0) }.joined(separator: " "))")
        
        return command
    }
    
    private func sendData(_ connection: NWConnection, data: Data) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            })
        }
    }
    
    private func receiveData(_ connection: NWConnection, timeout: TimeInterval = 5.0) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            var hasResumed = false
            var receivedData = Data()
            var expectedLength: Int?
            
            // Set up timeout using Task
            let timeoutTask = Task {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                if !hasResumed && !Task.isCancelled {
                    hasResumed = true
                    print("❌ Receive timeout after \(timeout) seconds. Received \(receivedData.count) bytes")
                    if receivedData.count > 0 {
                        print("   Received data: \(receivedData.map { String(format: "%02X", $0) }.joined(separator: " "))")
                    }
                    continuation.resume(throwing: NSError(domain: "GW2000", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "Receive timeout after \(timeout) seconds. Received \(receivedData.count) bytes"
                    ]))
                }
            }
            
            // Recursive receive function
            func receiveNext() {
                // Use a smaller minimum length to read data more aggressively
                connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, isComplete, error in
                    guard !hasResumed else { return }
                    
                    if let error = error {
                        hasResumed = true
                        timeoutTask.cancel()
                        print("❌ Receive error: \(error.localizedDescription)")
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    if let data = data {
                        receivedData.append(data)
                        print("📥 Received \(data.count) bytes (total: \(receivedData.count) bytes)")
                        if data.count <= 100 {
                            print("   Data: \(data.map { String(format: "%02X", $0) }.joined(separator: " "))")
                        } else {
                            print("   Data: \(data.prefix(50).map { String(format: "%02X", $0) }.joined(separator: " ")) ... (\(data.count - 50) more bytes)")
                        }
                        
                        // Parse expected length from header (if we have it)
                        if receivedData.count >= 5 && expectedLength == nil {
                            // Check if this is a valid response header
                            if receivedData[0] == 0xFF && receivedData[1] == 0xFF {
                                // Format: FF FF CMD SIZE_HIGH SIZE_LOW [PAYLOAD] CHECKSUM
                                let payloadSize = Int(receivedData[3]) << 8 | Int(receivedData[4])
                                expectedLength = 6 + payloadSize // Header (5) + payload + checksum (1)
                                print("📊 Expected total length: \(expectedLength!) bytes (payload: \(payloadSize) bytes)")
                            } else {
                                // Not a valid header
                                hasResumed = true
                                timeoutTask.cancel()
                                print("❌ Invalid response header: \(receivedData.prefix(10).map { String(format: "%02X", $0) }.joined(separator: " "))")
                                continuation.resume(throwing: NSError(domain: "GW2000", code: -1, userInfo: [
                                    NSLocalizedDescriptionKey: "Invalid response header"
                                ]))
                                return
                            }
                        }
                        
                        // Check if we have the complete message
                        if let expected = expectedLength, receivedData.count >= expected {
                            hasResumed = true
                            timeoutTask.cancel()
                            print("✅ Received complete message: \(receivedData.count) bytes")
                            continuation.resume(returning: receivedData)
                            return
                        }
                        
                        // If connection is complete but we don't have enough data, that's an error
                        if isComplete {
                            if let expected = expectedLength, receivedData.count < expected {
                                hasResumed = true
                                timeoutTask.cancel()
                                print("❌ Connection complete but incomplete data: got \(receivedData.count), expected \(expected)")
                                print("   This might indicate the device closed the connection early")
                                continuation.resume(throwing: NSError(domain: "GW2000", code: -1, userInfo: [
                                    NSLocalizedDescriptionKey: "Device closed connection after sending only \(receivedData.count) of \(expected) bytes"
                                ]))
                                return
                            } else if expectedLength == nil && receivedData.count < 5 {
                                // Connection closed before we even got a header
                                hasResumed = true
                                timeoutTask.cancel()
                                print("❌ Connection closed with insufficient data for header")
                                continuation.resume(throwing: NSError(domain: "GW2000", code: -1, userInfo: [
                                    NSLocalizedDescriptionKey: "Connection closed before receiving complete header"
                                ]))
                                return
                            } else if expectedLength == nil {
                                // We have at least 5 bytes but connection closed, parse what we got
                                hasResumed = true
                                timeoutTask.cancel()
                                print("⚠️ Connection closed early, returning received data: \(receivedData.count) bytes")
                                continuation.resume(returning: receivedData)
                                return
                            } else {
                                // We have all expected data and connection is complete
                                hasResumed = true
                                timeoutTask.cancel()
                                print("✅ Received complete message: \(receivedData.count) bytes (connection closed)")
                                continuation.resume(returning: receivedData)
                                return
                            }
                        }
                        
                        // Continue receiving if connection is still open
                        print("   Waiting for more data... (isComplete: \(isComplete))")
                        receiveNext()
                    } else {
                        // No data and no error
                        if receivedData.isEmpty {
                            hasResumed = true
                            timeoutTask.cancel()
                            print("❌ No data received from device")
                            continuation.resume(throwing: NSError(domain: "GW2000", code: -1, userInfo: [
                                NSLocalizedDescriptionKey: "No data received"
                            ]))
                        } else {
                            // Have some data but got nil, connection might be closing
                            print("⚠️ Received nil data, waiting for connection state...")
                            receiveNext()
                        }
                    }
                }
            }
            
            // Start receiving
            receiveNext()
        }
    }
    
    private func parseSensorIDResponse(_ data: Data) throws -> [SensorInfo] {
        guard data.count >= 6 else {
            throw NSError(domain: "GW2000", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Invalid response length: \(data.count) bytes"
            ])
        }
        
        // Verify header
        guard data[0] == 0xFF && data[1] == 0xFF else {
            throw NSError(domain: "GW2000", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Invalid response header"
            ])
        }
        
        // Verify command echo
        guard data[2] == Command.readSensorIDNew.rawValue else {
            throw NSError(domain: "GW2000", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Unexpected command in response: 0x\(String(format: "%02X", data[2]))"
            ])
        }
        
        // Get payload size
        let payloadSize = Int(data[3]) << 8 | Int(data[4])
        
        guard data.count >= 6 + payloadSize else {
            throw NSError(domain: "GW2000", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Incomplete response: expected \(6 + payloadSize) bytes, got \(data.count)"
            ])
        }
        
        // Get sensor count (first byte of payload)
        let sensorCount = Int(data[5])
        var sensors: [SensorInfo] = []
        
        var offset = 6 // Start of sensor data
        for _ in 0..<sensorCount {
            guard offset + 7 <= data.count else {
                print("⚠️ Warning: Truncated sensor data at offset \(offset)")
                break
            }
            
            let sensorType = data[offset]
            let sensorID = UInt32(data[offset+1]) << 24 |
                          UInt32(data[offset+2]) << 16 |
                          UInt32(data[offset+3]) << 8 |
                          UInt32(data[offset+4])
            let battery = data[offset+5]
            let signal = data[offset+6]
            
            sensors.append(SensorInfo(
                sensorType: sensorType,
                sensorID: sensorID,
                battery: battery,
                signal: signal,
                customLabel: nil
            ))
            
            offset += 7
        }
        
        return sensors
    }
}
