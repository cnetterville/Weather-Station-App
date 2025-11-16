//
//  WeatherStationDetailView.swift
//  Weather Station App
//
//  Created by Curtis Netterville on 10/25/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct WeatherStationDetailView: View {
    @Binding var station: WeatherStation
    let weatherData: WeatherStationData?
    @StateObject private var weatherService = WeatherStationService.shared
    
    @State private var showingHistory = false
    @State private var scrollViewID = UUID()
    @State private var isReorderMode = false
    @State private var refreshTrigger = UUID()
    
    var body: some View {
        GeometryReader { geometry in
            if let data = weatherData {
                if isReorderMode {
                    // Reorder mode: Show full-screen list
                    ReorderModeView(
                        station: $station,
                        data: data,
                        weatherService: weatherService
                    )
                } else {
                    // Normal mode: Scrollable grid with Station Info at top
                    ScrollView {
                        VStack(spacing: 16) {
                            // Station Information Card - Always at top
                            StationInfoCard(station: station)
                            
                            let columns = WeatherDetailLayoutHelper.calculateColumns(for: geometry.size.width)
                            let tileSize = WeatherDetailLayoutHelper.calculateTileSize(for: geometry.size.width, columns: columns)
                            LazyVGrid(columns: Array(repeating: GridItem(.fixed(tileSize), spacing: 16), count: columns), spacing: 16) {
                                ReorderableWeatherCardsView(
                                    station: $station,
                                    data: data,
                                    weatherService: weatherService,
                                    isReorderMode: isReorderMode
                                )
                            }
                        }
                        .padding()
                    }
                    .id(refreshTrigger)
                    .clipped()
                }
            } else {
                NoDataView(stationName: station.name)
            }
        }
        .navigationTitle(station.name)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(isReorderMode ? "Done" : "Rearrange Cards") {
                    if !isReorderMode {
                        // Entering reorder mode
                        logUI("Entering reorder mode")
                        logUI("  Current card order: \(station.cardOrder.map { $0.displayName })")
                    } else {
                        // Exiting reorder mode
                        logUI("Exiting reorder mode")
                        
                        // Fetch fresh station from service
                        if let updatedStation = weatherService.weatherStations.first(where: { $0.id == station.id }) {
                            logUI("  Service has card order: \(updatedStation.cardOrder.map { $0.displayName })")
                            logUI("  Current binding has: \(station.cardOrder.map { $0.displayName })")
                            
                            // Update binding
                            station = updatedStation
                            
                            logUI("  After assignment: \(station.cardOrder.map { $0.displayName })")
                            
                            // Force refresh
                            refreshTrigger = UUID()
                        }
                    }
                    
                    withAnimation {
                        isReorderMode.toggle()
                    }
                }
            }
            
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

struct ReorderModeView: View {
    @Binding var station: WeatherStation
    let data: WeatherStationData
    let weatherService: WeatherStationService
    
    var visibleCards: [CardType] {
        let cards = station.cardOrder.filter { cardType in
            self.shouldShowCard(cardType, station: station, data: data)
        }
        return cards
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("Rearrange Cards")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Drag cards to reorder them. Changes save when you click Done.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.top)
            
            // List of cards
            List {
                ForEach(visibleCards) { cardType in
                    HStack(spacing: 16) {
                        Image(systemName: "line.3.horizontal")
                            .font(.title3)
                            .foregroundColor(.secondary)
                        
                        Image(systemName: self.iconForCardType(cardType))
                            .font(.title3)
                            .foregroundColor(.blue)
                            .frame(width: 30)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(cardType.displayName)
                                .font(.body)
                                .fontWeight(.medium)
                            
                            Text(self.getCardLabel(for: cardType))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .onMove { sourceIndices, destinationIndex in
                    self.handleMove(from: sourceIndices, to: destinationIndex)
                }
            }
            .listStyle(.inset)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func handleMove(from sourceIndices: IndexSet, to destinationIndex: Int) {
        logUI("Moving cards from \(sourceIndices) to \(destinationIndex)")
        
        // Get current visible cards
        var reorderedCards = visibleCards
        
        // Move the cards
        reorderedCards.move(fromOffsets: sourceIndices, toOffset: destinationIndex)
        logUI("  After move: \(reorderedCards.map { $0.displayName })")
        
        // Get invisible cards
        let invisibleCards = station.cardOrder.filter { cardType in
            !self.shouldShowCard(cardType, station: station, data: data)
        }
        
        // Rebuild full order: visible cards first (in new order), then invisible cards
        let newOrder = reorderedCards + invisibleCards
        
        // Update via the service to ensure proper persistence
        weatherService.updateStationCardOrder(station, newOrder: newOrder)
        
        // Update local binding after service update
        DispatchQueue.main.async {
            station.cardOrder = newOrder
        }
        
        logSuccess("Saved new order")
    }
    
    private func getCardLabel(for cardType: CardType) -> String {
        switch cardType {
        case .stationInfo: return station.name
        case .outdoorTemp: return station.customLabels.outdoorTemp
        case .forecast: return station.customLabels.forecast
        case .radar: return station.customLabels.radar
        case .indoorTemp: return station.customLabels.indoorTemp
        case .tempHumidityCh1: return station.customLabels.tempHumidityCh1
        case .tempHumidityCh2: return station.customLabels.tempHumidityCh2
        case .tempHumidityCh3: return station.customLabels.tempHumidityCh3
        case .wind: return station.customLabels.wind
        case .pressure: return station.customLabels.pressure
        case .rainfall: return station.customLabels.rainfall
        case .rainfallPiezo: return station.customLabels.rainfallPiezo
        case .airQualityCh1: return station.customLabels.airQualityCh1
        case .airQualityCh2: return station.customLabels.airQualityCh2
        case .airQualityCh3: return station.customLabels.airQualityCh3
        case .solar: return station.customLabels.solar
        case .lightning: return station.customLabels.lightning
        case .batteryStatus: return station.customLabels.batteryStatus
        case .signalStrength: return station.customLabels.signalStrength
        case .sunriseSunset: return station.customLabels.sunriseSunset
        case .lunar: return station.customLabels.lunar
        case .camera: return station.customLabels.camera
        }
    }
    
    private func shouldShowCard(_ cardType: CardType, station: WeatherStation, data: WeatherStationData) -> Bool {
        switch cardType {
        case .stationInfo: return false // Station Info is fixed at top, not reorderable
        case .outdoorTemp: return station.sensorPreferences.showOutdoorTemp
        case .forecast: return station.sensorPreferences.showForecast
        case .radar: return station.sensorPreferences.showRadar && station.latitude != nil && station.longitude != nil
        case .indoorTemp: return station.sensorPreferences.showIndoorTemp
        case .tempHumidityCh1: return station.sensorPreferences.showTempHumidityCh1
        case .tempHumidityCh2: return station.sensorPreferences.showTempHumidityCh2
        case .tempHumidityCh3: return station.sensorPreferences.showTempHumidityCh3 && data.tempAndHumidityCh3 != nil
        case .wind: return station.sensorPreferences.showWind
        case .pressure: return station.sensorPreferences.showPressure
        case .rainfall: return station.sensorPreferences.showRainfall && data.rainfall != nil
        case .rainfallPiezo: return station.sensorPreferences.showRainfallPiezo
        case .airQualityCh1: return station.sensorPreferences.showAirQualityCh1 && data.pm25Ch1.pm25.value != "0" && !data.pm25Ch1.pm25.value.isEmpty
        case .airQualityCh2: return station.sensorPreferences.showAirQualityCh2 && data.pm25Ch2 != nil && data.pm25Ch2!.pm25.value != "0" && !data.pm25Ch2!.pm25.value.isEmpty
        case .airQualityCh3: return station.sensorPreferences.showAirQualityCh3 && data.pm25Ch3 != nil && data.pm25Ch3!.pm25.value != "0" && !data.pm25Ch3!.pm25.value.isEmpty
        case .solar: return station.sensorPreferences.showSolar
        case .lightning: return station.sensorPreferences.showLightning
        case .batteryStatus: return station.sensorPreferences.showBatteryStatus
        case .signalStrength: return station.sensorPreferences.showSignalStrength
        case .sunriseSunset: return station.sensorPreferences.showSunriseSunset && station.latitude != nil && station.longitude != nil
        case .lunar: return station.sensorPreferences.showLunar && station.latitude != nil && station.longitude != nil
        case .camera: return station.sensorPreferences.showCamera && station.associatedCameraMAC != nil
        }
    }
    
    private func iconForCardType(_ cardType: CardType) -> String {
        switch cardType {
        case .stationInfo: return "info.circle.fill"
        case .outdoorTemp: return "thermometer"
        case .forecast: return "calendar"
        case .radar: return "waveform.path.ecg"
        case .indoorTemp: return "house.fill"
        case .tempHumidityCh1, .tempHumidityCh2, .tempHumidityCh3: return "thermometer"
        case .wind: return "wind"
        case .pressure: return "barometer"
        case .rainfall, .rainfallPiezo: return "cloud.rain.fill"
        case .airQualityCh1, .airQualityCh2, .airQualityCh3: return "aqi.medium"
        case .solar: return "sun.max.fill"
        case .lightning: return "bolt.fill"
        case .batteryStatus: return "battery.100"
        case .signalStrength: return "antenna.radiowaves.left.and.right"
        case .sunriseSunset: return "sunrise.fill"
        case .lunar: return "moon.fill"
        case .camera: return "camera.fill"
        }
    }
}

struct ReorderableWeatherCardsView: View {
    @Binding var station: WeatherStation
    let data: WeatherStationData
    let weatherService: WeatherStationService
    let isReorderMode: Bool
    
    @State private var draggingCard: CardType?
    
    var body: some View {
        ForEach(station.cardOrder) { cardType in
            if shouldShowCard(cardType) {
                if isReorderMode {
                    reorderModeCard(for: cardType)
                } else {
                    cardView(for: cardType)
                }
            }
        }
    }
    
    @ViewBuilder
    private func reorderModeCard(for cardType: CardType) -> some View {
        cardView(for: cardType)
            .overlay(reorderOverlay())
            .overlay(dragHandle(), alignment: .topTrailing)
            .opacity(draggingCard == cardType ? 0.5 : 1.0)
            .onDrag {
                logUI("onDrag started for: \(cardType.displayName)")
                draggingCard = cardType
                logUI("  Set draggingCard to: \(draggingCard?.displayName ?? "nil")")
                return createDragItem(for: cardType)
            }
            .onDrop(of: [.text], delegate: CardReorderDropDelegate(
                destinationCard: cardType,
                cardOrder: $station.cardOrder,
                draggingCard: $draggingCard
            ))
    }
    
    private func reorderOverlay() -> some View {
        RoundedRectangle(cornerRadius: 16)
            .stroke(Color.blue.opacity(0.5), lineWidth: 2)
    }
    
    private func dragHandle() -> some View {
        Image(systemName: "line.3.horizontal")
            .font(.title2)
            .foregroundColor(.white)
            .padding(8)
            .background(Color.blue)
            .clipShape(Circle())
            .padding(8)
    }
    
    private func createDragItem(for cardType: CardType) -> NSItemProvider {
        let itemProvider = NSItemProvider()
        itemProvider.registerDataRepresentation(forTypeIdentifier: UTType.text.identifier, visibility: .all) { completion in
            Task { @MainActor in
                let data = cardType.rawValue.data(using: .utf8) ?? Data()
                completion(data, nil)
            }
            return nil
        }
        return itemProvider
    }
    
    private func shouldShowCard(_ cardType: CardType) -> Bool {
        switch cardType {
        case .stationInfo: return false // Station Info is now fixed at top
        case .outdoorTemp: return station.sensorPreferences.showOutdoorTemp
        case .forecast: return station.sensorPreferences.showForecast
        case .radar: return station.sensorPreferences.showRadar && station.latitude != nil && station.longitude != nil
        case .indoorTemp: return station.sensorPreferences.showIndoorTemp
        case .tempHumidityCh1: return station.sensorPreferences.showTempHumidityCh1
        case .tempHumidityCh2: return station.sensorPreferences.showTempHumidityCh2
        case .tempHumidityCh3: return station.sensorPreferences.showTempHumidityCh3 && data.tempAndHumidityCh3 != nil
        case .wind: return station.sensorPreferences.showWind
        case .pressure: return station.sensorPreferences.showPressure
        case .rainfall: return station.sensorPreferences.showRainfall && data.rainfall != nil
        case .rainfallPiezo: return station.sensorPreferences.showRainfallPiezo
        case .airQualityCh1: return station.sensorPreferences.showAirQualityCh1 && data.pm25Ch1.pm25.value != "0" && !data.pm25Ch1.pm25.value.isEmpty
        case .airQualityCh2: return station.sensorPreferences.showAirQualityCh2 && data.pm25Ch2 != nil && data.pm25Ch2!.pm25.value != "0" && !data.pm25Ch2!.pm25.value.isEmpty
        case .airQualityCh3: return station.sensorPreferences.showAirQualityCh3 && data.pm25Ch3 != nil && data.pm25Ch3!.pm25.value != "0" && !data.pm25Ch3!.pm25.value.isEmpty
        case .solar: return station.sensorPreferences.showSolar
        case .lightning: return station.sensorPreferences.showLightning
        case .batteryStatus: return station.sensorPreferences.showBatteryStatus
        case .signalStrength: return station.sensorPreferences.showSignalStrength
        case .sunriseSunset: return station.sensorPreferences.showSunriseSunset && station.latitude != nil && station.longitude != nil
        case .lunar: return station.sensorPreferences.showLunar && station.latitude != nil && station.longitude != nil
        case .camera: return station.sensorPreferences.showCamera && station.associatedCameraMAC != nil
        }
    }
    
    @ViewBuilder
    private func cardView(for cardType: CardType) -> some View {
        switch cardType {
        case .stationInfo:
            stationInfoCardView()
        case .outdoorTemp:
            outdoorTempCardView()
        case .forecast:
            forecastCardView()
        case .radar:
            radarCardView()
        case .indoorTemp:
            indoorTempCardView()
        case .tempHumidityCh1:
            tempHumidityCardView(channel: 1)
        case .tempHumidityCh2:
            tempHumidityCardView(channel: 2)
        case .tempHumidityCh3:
            tempHumidityCardView(channel: 3)
        case .wind:
            windCardView()
        case .pressure:
            pressureCardView()
        case .rainfall:
            rainfallCardView()
        case .rainfallPiezo:
            rainfallPiezoCardView()
        case .airQualityCh1:
            airQualityCardView(channel: 1)
        case .airQualityCh2:
            airQualityCardView(channel: 2)
        case .airQualityCh3:
            airQualityCardView(channel: 3)
        case .solar:
            solarCardView()
        case .lightning:
            lightningCardView()
        case .batteryStatus:
            batteryStatusCardView()
        case .sunriseSunset:
            sunriseSunsetCardView()
        case .lunar:
            lunarCardView()
        case .camera:
            cameraCardView()
        case .signalStrength:
            signalStrengthCardView()
        }
    }
    
    // MARK: - Individual Card Views
    
    private func stationInfoCardView() -> some View {
        StationInfoCard(station: station)
    }
    
    private func outdoorTempCardView() -> some View {
        OutdoorTemperatureCard(
            station: station,
            data: data,
            onTitleChange: { newTitle in
                updateStationLabel(\.outdoorTemp, with: newTitle)
            },
            getDailyTemperatureStats: {
                DailyTemperatureCalculator.getFlexibleDailyStats(
                    weatherData: data,
                    historicalData: weatherService.historicalData[station.macAddress],
                    station: station
                )
            },
            getDailyHumidityStats: {
                getOutdoorHumidityStats()
            }
        )
    }
    
    private func forecastCardView() -> some View {
        ForecastCard(
            station: station,
            onTitleChange: { newTitle in
                updateStationLabel(\.forecast, with: newTitle)
            }
        )
    }
    
    private func radarCardView() -> some View {
        RadarTileView(
            station: station,
            onTitleChange: { newTitle in
                updateStationLabel(\.radar, with: newTitle)
            }
        )
    }
    
    private func indoorTempCardView() -> some View {
        IndoorTemperatureCard(
            station: station,
            data: data,
            onTitleChange: { newTitle in
                updateStationLabel(\.indoorTemp, with: newTitle)
            },
            getDailyTemperatureStats: {
                DailyTemperatureCalculator.getFlexibleIndoorDailyStats(
                    weatherData: data,
                    historicalData: weatherService.historicalData[station.macAddress],
                    station: station
                )
            },
            getDailyHumidityStats: {
                getIndoorHumidityStats()
            }
        )
    }
    
    @ViewBuilder
    private func tempHumidityCardView(channel: Int) -> some View {
        switch channel {
        case 1:
            ChannelTemperatureCard(
                station: station,
                data: data.tempAndHumidityCh1,
                title: station.customLabels.tempHumidityCh1,
                onTitleChange: { newTitle in
                    updateStationLabel(\.tempHumidityCh1, with: newTitle)
                },
                getDailyTemperatureStats: {
                    DailyTemperatureCalculator.getFlexibleTempHumidityCh1DailyStats(
                        weatherData: data,
                        historicalData: weatherService.historicalData[station.macAddress],
                        station: station
                    )
                },
                getDailyHumidityStats: {
                    getTempHumidityCh1HumidityStats()
                }
            )
        case 2:
            ChannelTemperatureCard(
                station: station,
                data: data.tempAndHumidityCh2,
                title: station.customLabels.tempHumidityCh2,
                onTitleChange: { newTitle in
                    updateStationLabel(\.tempHumidityCh2, with: newTitle)
                },
                getDailyTemperatureStats: {
                    DailyTemperatureCalculator.getFlexibleTempHumidityCh2DailyStats(
                        weatherData: data,
                        historicalData: weatherService.historicalData[station.macAddress],
                        station: station
                    )
                },
                getDailyHumidityStats: {
                    getTempHumidityCh2HumidityStats()
                }
            )
        case 3:
            if let ch3Data = data.tempAndHumidityCh3 {
                ChannelTemperatureCard(
                    station: station,
                    data: ch3Data,
                    title: station.customLabels.tempHumidityCh3,
                    onTitleChange: { newTitle in
                        updateStationLabel(\.tempHumidityCh3, with: newTitle)
                    },
                    getDailyTemperatureStats: {
                        DailyTemperatureCalculator.getFlexibleTempHumidityCh3DailyStats(
                            weatherData: data,
                            historicalData: weatherService.historicalData[station.macAddress],
                            station: station
                        )
                    },
                    getDailyHumidityStats: {
                        getTempHumidityCh3HumidityStats()
                    }
                )
            } else {
                EmptyView()
            }
        default:
            EmptyView()
        }
    }
    
    private func windCardView() -> some View {
        WindCard(
            station: station,
            data: data,
            onTitleChange: { newTitle in
                updateStationLabel(\.wind, with: newTitle)
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
    
    private func pressureCardView() -> some View {
        PressureCard(
            station: station,
            data: data,
            onTitleChange: { newTitle in
                updateStationLabel(\.pressure, with: newTitle)
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
    
    @ViewBuilder
    private func rainfallCardView() -> some View {
        if let rainfallData = data.rainfall {
            TraditionalRainfallCard(
                station: station,
                data: data,
                rainfallData: rainfallData,
                onTitleChange: { newTitle in
                    updateStationLabel(\.rainfall, with: newTitle)
                }
            )
        }
    }
    
    private func rainfallPiezoCardView() -> some View {
        RainfallCard(
            station: station,
            data: data,
            onTitleChange: { newTitle in
                updateStationLabel(\.rainfallPiezo, with: newTitle)
            }
        )
    }
    
    @ViewBuilder
    private func airQualityCardView(channel: Int) -> some View {
        switch channel {
        case 1:
            AirQualityCard(
                title: station.customLabels.airQualityCh1,
                data: data.pm25Ch1,
                systemImage: "aqi.medium",
                onTitleChange: { newTitle in
                    updateStationLabel(\.airQualityCh1, with: newTitle)
                },
                getDailyPM25Stats: {
                    DailyTemperatureCalculator.getDailyPM25Ch1Stats(
                        weatherData: data,
                        historicalData: weatherService.historicalData[station.macAddress],
                        station: station
                    )
                }
            )
        case 2:
            if let pm25Ch2 = data.pm25Ch2 {
                AirQualityCard(
                    title: station.customLabels.airQualityCh2,
                    data: pm25Ch2,
                    systemImage: "aqi.medium",
                    onTitleChange: { newTitle in
                        updateStationLabel(\.airQualityCh2, with: newTitle)
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
        case 3:
            if let pm25Ch3 = data.pm25Ch3 {
                AirQualityCard(
                    title: station.customLabels.airQualityCh3,
                    data: pm25Ch3,
                    systemImage: "aqi.medium",
                    onTitleChange: { newTitle in
                        updateStationLabel(\.airQualityCh3, with: newTitle)
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
        default:
            EmptyView()
        }
    }
    
    private func solarCardView() -> some View {
        SolarUVCard(
            station: station,
            data: data,
            onTitleChange: { newTitle in
                updateStationLabel(\.solar, with: newTitle)
            }
        )
    }
    
    private func lightningCardView() -> some View {
        LightningCard(
            station: station,
            data: data,
            onTitleChange: { newTitle in
                updateStationLabel(\.lightning, with: newTitle)
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
    
    private func batteryStatusCardView() -> some View {
        BatteryStatusCard(
            station: station,
            data: data,
            onTitleChange: { newTitle in
                updateStationLabel(\.batteryStatus, with: newTitle)
            }
        )
    }
    
    private func sunriseSunsetCardView() -> some View {
        SunriseSunsetCard(
            station: station,
            onTitleChange: { newTitle in
                updateStationLabel(\.sunriseSunset, with: newTitle)
            }
        )
    }
    
    private func lunarCardView() -> some View {
        LunarCard(
            station: station,
            onTitleChange: { newTitle in
                updateStationLabel(\.lunar, with: newTitle)
            }
        )
    }
    
    private func cameraCardView() -> some View {
        CameraTileView(
            station: station,
            onTitleChange: { newTitle in
                updateStationLabel(\.camera, with: newTitle)
            }
        )
    }
    
    private func signalStrengthCardView() -> some View {
        SignalStrengthCard(
            station: station,
            onTitleChange: { newTitle in
                updateStationLabel(\.signalStrength, with: newTitle)
            }
        )
    }
    
    // MARK: - Helper Methods
    
    private func updateStationLabel(_ keyPath: WritableKeyPath<SensorLabels, String>, with newTitle: String) {
        var updatedStation = station
        updatedStation.customLabels[keyPath: keyPath] = newTitle
        station = updatedStation
        weatherService.updateStation(station)
    }
    
    private func getOutdoorHumidityStats() -> DailyHumidityStats? {
        if let dailyStats = DailyTemperatureCalculator.getDailyHumidityStats(
            weatherData: data,
            historicalData: weatherService.historicalData[station.macAddress],
            station: station
        ) {
            return dailyStats
        }
        guard let historical = weatherService.historicalData[station.macAddress] else { return nil }
        return DailyTemperatureCalculator.calculateHumidityStatsFromAvailableData(from: historical.outdoor)
    }
    
    private func getIndoorHumidityStats() -> DailyHumidityStats? {
        if let dailyStats = DailyTemperatureCalculator.getIndoorDailyHumidityStats(
            weatherData: data,
            historicalData: weatherService.historicalData[station.macAddress],
            station: station
        ) {
            return dailyStats
        }
        guard let historical = weatherService.historicalData[station.macAddress] else { return nil }
        return DailyTemperatureCalculator.calculateIndoorHumidityStatsFromAvailableData(from: historical.indoor)
    }
    
    private func getTempHumidityCh1HumidityStats() -> DailyHumidityStats? {
        if let dailyStats = DailyTemperatureCalculator.getTempHumidityCh1DailyHumidityStats(
            weatherData: data,
            historicalData: weatherService.historicalData[station.macAddress],
            station: station
        ) {
            return dailyStats
        }
        guard let historical = weatherService.historicalData[station.macAddress] else { return nil }
        return DailyTemperatureCalculator.calculateChannelHumidityStatsFromAvailableData(from: historical.tempAndHumidityCh1)
    }
    
    private func getTempHumidityCh2HumidityStats() -> DailyHumidityStats? {
        if let dailyStats = DailyTemperatureCalculator.getTempHumidityCh2DailyHumidityStats(
            weatherData: data,
            historicalData: weatherService.historicalData[station.macAddress],
            station: station
        ) {
            return dailyStats
        }
        guard let historical = weatherService.historicalData[station.macAddress] else { return nil }
        return DailyTemperatureCalculator.calculateChannelHumidityStatsFromAvailableData(from: historical.tempAndHumidityCh2)
    }
    
    private func getTempHumidityCh3HumidityStats() -> DailyHumidityStats? {
        if let dailyStats = DailyTemperatureCalculator.getTempHumidityCh3DailyHumidityStats(
            weatherData: data,
            historicalData: weatherService.historicalData[station.macAddress],
            station: station
        ) {
            return dailyStats
        }
        guard let historical = weatherService.historicalData[station.macAddress] else { return nil }
        return DailyTemperatureCalculator.calculateChannelHumidityStatsFromAvailableData(from: historical.tempAndHumidityCh3)
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