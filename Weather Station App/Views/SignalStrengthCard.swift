//
//  SignalStrengthCard.swift
//  Weather Station App
//
//  Display signal strength for all sensors from local GW2000 device
//

import SwiftUI

struct SignalStrengthCard: View {
    let station: WeatherStation
    let onTitleChange: (String) -> Void
    
    @StateObject private var localDeviceManager = LocalDeviceManager.shared
    @State private var showingLabelEditor = false
    @State private var editingSensor: LocalDeviceManager.SensorData?
    
    private var associatedDevice: LocalDeviceManager.LocalDevice? {
        localDeviceManager.getDevice(forStationMAC: station.macAddress)
    }
    
    private var sensors: [LocalDeviceManager.SensorData] {
        localDeviceManager.getSensors(forStationMAC: station.macAddress)
    }
    
    var body: some View {
        EditableWeatherCard(
            title: .constant(station.customLabels.signalStrength),
            systemImage: "antenna.radiowaves.left.and.right",
            onTitleChange: onTitleChange
        ) {
            VStack(alignment: .leading, spacing: 12) {
                if let device = associatedDevice {
                    // Device info header
                    DeviceInfoHeader(device: device)
                    
                    Divider()
                    
                    if sensors.isEmpty {
                        NoSensorsView(device: device)
                    } else {
                        // Sensor list
                        SensorListView(
                            sensors: sensors,
                            device: device,
                            onEditLabel: { sensor in
                                editingSensor = sensor
                                showingLabelEditor = true
                            }
                        )
                    }
                } else {
                    NoDeviceAssociatedView(stationName: station.name)
                }
            }
        }
        .sheet(isPresented: $showingLabelEditor) {
            if let sensor = editingSensor, let device = associatedDevice {
                SensorLabelEditorSheet(
                    sensor: sensor,
                    device: device,
                    isPresented: $showingLabelEditor
                )
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .localDeviceDataUpdated)) { _ in
            // Trigger view update when sensor data changes
        }
    }
}

// MARK: - Device Info Header

struct DeviceInfoHeader: View {
    let device: LocalDeviceManager.LocalDevice
    @StateObject private var localDeviceManager = LocalDeviceManager.shared
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "antenna.radiowaves.left.and.right.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(device.name)
                            .font(.headline)
                        Text(device.ipAddress)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .font(.system(.caption, design: .monospaced))
                    }
                }
                
                if let lastUpdated = device.lastUpdated {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("Updated \(timeAgoString(from: lastUpdated))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Refresh button
            Button(action: {
                Task {
                    await localDeviceManager.refreshDevice(device)
                }
            }) {
                Image(systemName: "arrow.clockwise")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(localDeviceManager.isRefreshing)
            .help("Refresh sensor data")
        }
    }
    
    private func timeAgoString(from date: Date) -> String {
        let seconds = Date().timeIntervalSince(date)
        
        if seconds < 60 {
            return "just now"
        } else if seconds < 3600 {
            let minutes = Int(seconds / 60)
            return "\(minutes)m ago"
        } else if seconds < 86400 {
            let hours = Int(seconds / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(seconds / 86400)
            return "\(days)d ago"
        }
    }
}

// MARK: - Sensor List View

struct SensorListView: View {
    let sensors: [LocalDeviceManager.SensorData]
    let device: LocalDeviceManager.LocalDevice
    let onEditLabel: (LocalDeviceManager.SensorData) -> Void
    
    var body: some View {
        VStack(spacing: 4) {
            // Table-style list - single column, very compact
            ForEach(sensors) { sensor in
                SensorInfoCard(
                    sensor: sensor,
                    onEditLabel: {
                        onEditLabel(sensor)
                    }
                )
            }
        }
    }
}

// MARK: - Sensor Summary Stats

struct SensorSummaryStats: View {
    let sensors: [LocalDeviceManager.SensorData]
    
    private var signalStats: (excellent: Int, good: Int, fair: Int, poor: Int) {
        var stats = (excellent: 0, good: 0, fair: 0, poor: 0)
        for sensor in sensors {
            switch sensor.signalStrength {
            case .excellent: stats.excellent += 1
            case .good: stats.good += 1
            case .fair: stats.fair += 1
            case .poor: stats.poor += 1
            case .unknown: break
            }
        }
        return stats
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Signal summary
            VStack(alignment: .leading, spacing: 4) {
                Text("Signal Quality")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fontWeight(.medium)
                
                HStack(spacing: 8) {
                    StatBadge(count: signalStats.excellent, color: .green, icon: "wifi")
                    StatBadge(count: signalStats.good, color: .blue, icon: "wifi")
                    StatBadge(count: signalStats.fair, color: .orange, icon: "wifi.exclamationmark")
                    StatBadge(count: signalStats.poor, color: .red, icon: "wifi.slash")
                }
            }
            
            Spacer()
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(6)
    }
}

struct StatBadge: View {
    let count: Int
    let color: Color
    let icon: String
    
    var body: some View {
        Image(systemName: icon)
            .font(.caption2)
            .foregroundColor(color)
            .opacity(count > 0 ? 1.0 : 0.3)
    }
}

// MARK: - Sensor Info Card

struct SensorInfoCard: View {
    let sensor: LocalDeviceManager.SensorData
    let onEditLabel: () -> Void
    
    private func getRSSI(for sensor: LocalDeviceManager.SensorData) -> String? {
        guard let rssi = sensor.rssi, rssi != "--", !rssi.isEmpty else {
            return nil
        }
        return rssi
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // Icon
            Image(systemName: sensor.sensorIcon)
                .foregroundColor(.blue)
                .font(.caption2)
                .frame(width: 16)
            
            // Name
            Text(sensor.displayLabel)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
                .frame(minWidth: 80, alignment: .leading)
            
            Spacer()
            
            // Signal bars
            SignalBarsView(strength: sensor.signalStrength)
            
            // Signal quality text
            Text(sensor.signalStrength.description)
                .font(.system(size: 9))
                .foregroundColor(Color(sensor.signalStrength.color))
                .fontWeight(.medium)
                .frame(width: 50, alignment: .leading)
            
            // RSSI value
            if let rssi = getRSSI(for: sensor) {
                Text("\(rssi)dBm")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 45, alignment: .trailing)
            } else {
                Text("--")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 45, alignment: .trailing)
            }
            
            // Edit button
            Button(action: onEditLabel) {
                Image(systemName: "pencil")
                    .font(.system(size: 9))
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .help("Edit label")
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
        .cornerRadius(3)
        .overlay(
            RoundedRectangle(cornerRadius: 3)
                .stroke(Color(sensor.signalStrength.color).opacity(0.2), lineWidth: 0.5)
        )
    }
}

// MARK: - Signal Bars View

struct SignalBarsView: View {
    let strength: GW2000LocalAPI.SignalStrength
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<4, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(index < strength.bars ? Color(strength.color) : Color.gray.opacity(0.3))
                    .frame(width: 3, height: CGFloat(4 + index * 2))
            }
        }
    }
}

// MARK: - Empty States

struct NoDeviceAssociatedView: View {
    let stationName: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            
            Text("No Local Device Associated")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Associate a local GW2000 device with '\(stationName)' in Settings to view signal strength data.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Open Settings") {
                // Open Settings window using standard macOS command
                if #available(macOS 13, *) {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                } else {
                    NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}

struct NoSensorsView: View {
    let device: LocalDeviceManager.LocalDevice
    @StateObject private var localDeviceManager = LocalDeviceManager.shared
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "sensor")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            
            Text("No Sensors Found")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("No sensor data available from '\(device.name)'. Try refreshing the connection.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Refresh Now") {
                Task {
                    await localDeviceManager.refreshDevice(device)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(localDeviceManager.isRefreshing)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}

// MARK: - Sensor Label Editor Sheet

struct SensorLabelEditorSheet: View {
    let sensor: LocalDeviceManager.SensorData
    let device: LocalDeviceManager.LocalDevice
    @Binding var isPresented: Bool
    
    @StateObject private var localDeviceManager = LocalDeviceManager.shared
    @State private var customLabel: String = ""
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Edit Sensor Label")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("Cancel") {
                    isPresented = false
                }
            }
            
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: sensor.sensorIcon)
                        .foregroundColor(.blue)
                        .font(.title3)
                    
                    VStack(alignment: .leading) {
                        Text(sensor.sensorTypeName)
                            .font(.headline)
                        Text("ID: \(String(format: "%08X", sensor.sensorID))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .font(.system(.caption, design: .monospaced))
                    }
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Custom Label")
                        .font(.headline)
                    
                    TextField("Enter custom label", text: $customLabel)
                        .textFieldStyle(.roundedBorder)
                    
                    Text("Leave empty to use default sensor name")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            .cornerRadius(8)
            
            HStack {
                Button("Reset to Default") {
                    customLabel = ""
                    localDeviceManager.updateSensorLabel(
                        deviceID: device.id,
                        sensorID: sensor.sensorID,
                        label: nil
                    )
                    isPresented = false
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Save") {
                    let label = customLabel.trimmingCharacters(in: .whitespacesAndNewlines)
                    localDeviceManager.updateSensorLabel(
                        deviceID: device.id,
                        sensorID: sensor.sensorID,
                        label: label.isEmpty ? nil : label
                    )
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
            }
            
            Spacer()
        }
        .padding()
        .frame(width: 400, height: 300)
        .onAppear {
            customLabel = sensor.customLabel ?? ""
        }
    }
}

// MARK: - Preview

#Preview {
    SignalStrengthCard(
        station: WeatherStation(name: "Test Station", macAddress: "A0:A3:B3:7B:28:8B"),
        onTitleChange: { _ in }
    )
}
