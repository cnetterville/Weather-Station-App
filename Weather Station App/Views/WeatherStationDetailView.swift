//
//  WeatherStationDetailView.swift
//  Weather Station App
//
//  Created by Curtis Netterville on 10/25/25.
//

import SwiftUI

struct WeatherStationDetailView: View {
    @Binding var station: WeatherStation
    let weatherData: WeatherStationData?
    @StateObject private var weatherService = WeatherStationService.shared
    
    @State private var showingHistory = false
    @State private var scrollViewID = UUID()
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 16) {
                    // Station Information Card
                    StationInfoCard(station: station)
                    
                    if let data = weatherData {
                        let columns = WeatherDetailLayoutHelper.calculateColumns(for: geometry.size.width)
                        let tileSize = WeatherDetailLayoutHelper.calculateTileSize(for: geometry.size.width, columns: columns)
                        LazyVGrid(columns: Array(repeating: GridItem(.fixed(tileSize), spacing: 16), count: columns), spacing: 16) {
                            
                            WeatherSensorGridView(
                                station: $station,
                                data: data,
                                weatherService: weatherService
                            )
                        }
                    } else {
                        NoDataView(stationName: station.name)
                    }
                }
                .padding()
            }
            .id(scrollViewID)
            .focusable()
            .onAppear {
                // Refresh scroll view to ensure it's focusable
                scrollViewID = UUID()
            }
            .clipped()
        }
        .navigationTitle(station.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("History") {
                    showingHistory = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .sheet(isPresented: $showingHistory) {
            VStack(spacing: 0) {
                // Header with Done button
                HStack {
                    Text("Historical Weather Data - \(station.name)")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Button("Done") {
                        showingHistory = false
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                
                Divider()
                
                // Chart content
                HistoricalChartView(station: station)
            }
            .frame(minWidth: 800, minHeight: 600)
        }
        .id(station.id)
        .animation(.none, value: station.id)
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            // Reset scroll view when window becomes key to restore scroll functionality
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                scrollViewID = UUID()
            }
        }
    }
}

struct WeatherSensorGridView: View {
    @Binding var station: WeatherStation
    let data: WeatherStationData
    let weatherService: WeatherStationService
    
    var body: some View {
        Group {
            // TEMPERATURE SENSORS SECTION
            TemperatureSensorsSection(station: $station, data: data, weatherService: weatherService)
            
            // OTHER SENSORS SECTION
            OtherSensorsSection(station: $station, data: data, weatherService: weatherService)
        }
    }
}

struct NoDataView: View {
    let stationName: String
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("No Data Available")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Tap refresh to load weather data for \(stationName)")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct PreviewWeatherStationDetailView: PreviewProvider {
    static var previews: some View {
        NavigationView {
            WeatherStationDetailView(station: .constant(WeatherStation(name: "Test Station", macAddress: "A0:A3:B3:7B:28:8B")), weatherData: nil)
        }
    }
}