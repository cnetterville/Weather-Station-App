//
//  SignalStrengthCard.swift
//  Weather Station App
//
//  Display cloud API device status (connection, signal strength, firmware)
//

import SwiftUI

struct SignalStrengthCard: View {
    let station: WeatherStation
    let data: WeatherStationData?
    let onTitleChange: (String) -> Void
    
    var body: some View {
        EditableWeatherCard(
            title: .constant(station.customLabels.signalStrength),
            systemImage: "antenna.radiowaves.left.and.right",
            onTitleChange: onTitleChange
        ) {
            if let deviceStatus = data?.deviceStatus {
                CloudAPIDeviceStatusView(station: station, deviceStatus: deviceStatus)
            } else {
                NoDeviceStatusView()
            }
        }
    }
}

// MARK: - Cloud API Device Status View

struct CloudAPIDeviceStatusView: View {
    let station: WeatherStation
    let deviceStatus: DeviceStatus
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Connection Status with Large Visual Indicator
            HStack(spacing: 16) {
                // Status Icon
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    deviceStatus.isOnline ? Color.green.opacity(0.3) : Color.red.opacity(0.3),
                                    deviceStatus.isOnline ? Color.green.opacity(0.1) : Color.red.opacity(0.1),
                                    Color.clear
                                ]),
                                center: .center,
                                startRadius: 0,
                                endRadius: 40
                            )
                        )
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: deviceStatus.isOnline ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(deviceStatus.isOnline ? .green : .red)
                        .shadow(color: deviceStatus.isOnline ? .green.opacity(0.3) : .red.opacity(0.3), radius: 4)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(deviceStatus.isOnline ? "Online" : "Offline")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(deviceStatus.isOnline ? .green : .red)
                    
                    Text(deviceStatus.isOnline ? "Station is connected" : "Station is disconnected")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if let lastComm = deviceStatus.lastCommunication {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .font(.caption)
                                .foregroundColor(.blue)
                            Text("Last seen \(formatRelativeTime(lastComm))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 2)
                    }
                }
                
                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(deviceStatus.isOnline ? Color.green.opacity(0.08) : Color.red.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(deviceStatus.isOnline ? Color.green.opacity(0.2) : Color.red.opacity(0.2), lineWidth: 1)
            )
            
            // Signal Strength Section
            if let signalStrength = deviceStatus.signalStrength {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Signal Strength")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    HStack(spacing: 20) {
                        // Circular Gauge
                        ZStack {
                            // Background circle
                            Circle()
                                .stroke(Color.gray.opacity(0.2), lineWidth: 10)
                                .frame(width: 100, height: 100)
                            
                            // Progress circle
                            Circle()
                                .trim(from: 0, to: CGFloat(signalStrength) / 100.0)
                                .stroke(
                                    AngularGradient(
                                        gradient: Gradient(colors: [
                                            signalColor(signalStrength).opacity(0.6),
                                            signalColor(signalStrength),
                                            signalColor(signalStrength).opacity(0.6)
                                        ]),
                                        center: .center
                                    ),
                                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                                )
                                .frame(width: 100, height: 100)
                                .rotationEffect(.degrees(-90))
                                .shadow(color: signalColor(signalStrength).opacity(0.4), radius: 4)
                            
                            // Center content
                            VStack(spacing: 4) {
                                Image(systemName: signalIcon(for: signalStrength))
                                    .font(.system(size: 28))
                                    .foregroundColor(signalColor(signalStrength))
                                
                                Text("\(signalStrength)%")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(signalColor(signalStrength))
                            }
                        }
                        
                        // Signal Info
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Quality:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(connectionQualityText(for: signalStrength))
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(signalColor(signalStrength))
                            }
                            
                            // Signal bars visualization
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Strength")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        // Background
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.gray.opacity(0.2))
                                            .frame(height: 12)
                                        
                                        // Progress
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(
                                                LinearGradient(
                                                    colors: [
                                                        signalColor(signalStrength).opacity(0.8),
                                                        signalColor(signalStrength)
                                                    ],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                            .frame(width: geometry.size.width * CGFloat(signalStrength) / 100.0, height: 12)
                                            .shadow(color: signalColor(signalStrength).opacity(0.3), radius: 2)
                                    }
                                }
                                .frame(height: 12)
                            }
                            
                            // Quality description
                            Text(signalQualityDescription(for: signalStrength))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 2)
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
                )
            }
            
            // Device Information Section
            VStack(alignment: .leading, spacing: 12) {
                Text("Device Information")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                VStack(spacing: 10) {
                    if let firmware = deviceStatus.firmwareVersion {
                        DeviceInfoRow(
                            icon: "gear.circle.fill",
                            iconColor: .blue,
                            label: "Firmware Version",
                            value: "v\(firmware)"
                        )
                    }
                    
                    DeviceInfoRow(
                        icon: "network",
                        iconColor: .purple,
                        label: "MAC Address",
                        value: station.macAddress
                    )
                    
                    if let stationType = station.stationType {
                        DeviceInfoRow(
                            icon: "thermometer",
                            iconColor: .orange,
                            label: "Station Type",
                            value: stationType
                        )
                    }
                    
                    DeviceInfoRow(
                        icon: "mappin.circle.fill",
                        iconColor: .red,
                        label: "Station Name",
                        value: station.name
                    )
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
            )
        }
    }
    
    private func signalColor(_ strength: Int) -> Color {
        switch strength {
        case 75...100: return .green
        case 50..<75: return .yellow
        case 25..<50: return .orange
        default: return .red
        }
    }
    
    private func signalIcon(for strength: Int) -> String {
        switch strength {
        case 75...100: return "wifi"
        case 50..<75: return "wifi.exclamationmark"
        case 25..<50: return "wifi.slash"
        default: return "wifi.slash"
        }
    }
    
    private func connectionQualityText(for strength: Int) -> String {
        switch strength {
        case 75...100: return "Excellent"
        case 50..<75: return "Good"
        case 25..<50: return "Fair"
        default: return "Poor"
        }
    }
    
    private func signalQualityDescription(for strength: Int) -> String {
        switch strength {
        case 75...100: return "Strong and stable connection"
        case 50..<75: return "Good connection quality"
        case 25..<50: return "Weak signal, may experience delays"
        default: return "Very weak signal, connection issues likely"
        }
    }
    
    private func formatRelativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Device Info Row

struct DeviceInfoRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(iconColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - No Device Status View

struct NoDeviceStatusView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            
            VStack(spacing: 8) {
                Text("Device Status Unavailable")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text("Cloud API device status information is not available for this station. This data may not be provided by your weather station's API.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Preview

#Preview {
    SignalStrengthCard(
        station: WeatherStation(name: "Test Station", macAddress: "A0:A3:B3:7B:28:8B"),
        data: WeatherStationData(
            outdoor: OutdoorData(
                temperature: MeasurementData(time: "0", unit: "°F", value: "72"),
                feelsLike: MeasurementData(time: "0", unit: "°F", value: "70"),
                appTemp: MeasurementData(time: "0", unit: "°F", value: "71"),
                dewPoint: MeasurementData(time: "0", unit: "°F", value: "55"),
                vpd: MeasurementData(time: "0", unit: "kPa", value: "1.2"),
                humidity: MeasurementData(time: "0", unit: "%", value: "60")
            ),
            indoor: IndoorData(
                temperature: MeasurementData(time: "0", unit: "°F", value: "72"),
                humidity: MeasurementData(time: "0", unit: "%", value: "45"),
                dewPoint: MeasurementData(time: "0", unit: "°F", value: "50"),
                feelsLike: MeasurementData(time: "0", unit: "°F", value: "72"),
                appTempIn: MeasurementData(time: "0", unit: "°F", value: "72")
            ),
            solarAndUvi: SolarAndUVIData(
                solar: MeasurementData(time: "0", unit: "W/m²", value: "500"),
                uvi: MeasurementData(time: "0", unit: "", value: "3")
            ),
            rainfall: nil,
            rainfallPiezo: RainfallPiezoData(
                rainRate: MeasurementData(time: "0", unit: "in/hr", value: "0"),
                daily: MeasurementData(time: "0", unit: "in", value: "0"),
                state: MeasurementData(time: "0", unit: "", value: "0"),
                event: MeasurementData(time: "0", unit: "in", value: "0"),
                oneHour: MeasurementData(time: "0", unit: "in", value: "0"),
                twentyFourHours: MeasurementData(time: "0", unit: "in", value: "0"),
                weekly: MeasurementData(time: "0", unit: "in", value: "0"),
                monthly: MeasurementData(time: "0", unit: "in", value: "0"),
                yearly: MeasurementData(time: "0", unit: "in", value: "0")
            ),
            wind: WindData(
                windSpeed: MeasurementData(time: "0", unit: "mph", value: "5"),
                windGust: MeasurementData(time: "0", unit: "mph", value: "10"),
                windDirection: MeasurementData(time: "0", unit: "°", value: "180"),
                tenMinuteAverageWindDirection: MeasurementData(time: "0", unit: "°", value: "180")
            ),
            pressure: PressureData(
                relative: MeasurementData(time: "0", unit: "inHg", value: "29.92"),
                absolute: MeasurementData(time: "0", unit: "inHg", value: "29.92")
            ),
            lightning: LightningData(
                distance: MeasurementData(time: "0", unit: "mi", value: "0"),
                count: MeasurementData(time: "0", unit: "", value: "0")
            ),
            pm25Ch1: PM25Data(
                realTimeAqi: MeasurementData(time: "0", unit: "", value: "50"),
                pm25: MeasurementData(time: "0", unit: "µg/m³", value: "12"),
                twentyFourHoursAqi: MeasurementData(time: "0", unit: "", value: "50")
            ),
            pm25Ch2: nil,
            pm25Ch3: nil,
            tempAndHumidityCh1: TempHumidityData(
                temperature: MeasurementData(time: "0", unit: "°F", value: "72"),
                humidity: MeasurementData(time: "0", unit: "%", value: "60")
            ),
            tempAndHumidityCh2: TempHumidityData(
                temperature: MeasurementData(time: "0", unit: "°F", value: "72"),
                humidity: MeasurementData(time: "0", unit: "%", value: "60")
            ),
            tempAndHumidityCh3: nil,
            battery: BatteryData(
                console: nil,
                hapticArrayBattery: nil,
                hapticArrayCapacitor: nil,
                rainfallSensor: nil,
                lightningSensor: nil,
                pm25SensorCh1: nil,
                pm25SensorCh2: nil,
                tempHumiditySensorCh1: nil,
                tempHumiditySensorCh2: nil,
                tempHumiditySensorCh3: nil
            ),
            camera: nil,
            deviceStatus: DeviceStatus(
                isOnline: true,
                signalStrength: 85,
                firmwareVersion: "2.1.5",
                lastCommunication: Date().addingTimeInterval(-300)
            )
        ),
        onTitleChange: { _ in }
    )
    .frame(width: 400, height: 600)
}
