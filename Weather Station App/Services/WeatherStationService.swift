//
//  WeatherStationService.swift
//  Weather Station App
//
//  Created by Curtis Netterville on 10/25/25.
//

import Foundation
import Combine

class WeatherStationService: ObservableObject {
    static let shared = WeatherStationService()
    
    // Using the exact CDN endpoint from your working example
    private let realTimeURL = "https://cdnapi.ecowitt.net/api/v3/device/real_time"
    private let historyURL = "https://api.ecowitt.net/api/v3/device/history"
    private let deviceListURL = "https://api.ecowitt.net/api/v3/device/list"
    
    // Optimized URLSession with connection pooling and caching
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.httpMaximumConnectionsPerHost = 6
        config.timeoutIntervalForRequest = 15.0
        config.timeoutIntervalForResource = 30.0
        config.requestCachePolicy = .useProtocolCachePolicy // Allow intelligent caching
        config.urlCache = URLCache(memoryCapacity: 50 * 1024 * 1024, diskCapacity: 100 * 1024 * 1024)
        return URLSession(configuration: config)
    }()
    
    @Published var credentials: APICredentials = APICredentials(applicationKey: "", apiKey: "")
    @Published var weatherStations: [WeatherStation] = []
    @Published var discoveredStations: [EcowittDevice] = []
    @Published var weatherData: [String: WeatherStationData] = [:]
    @Published var historicalData: [String: HistoricalWeatherData] = [:]
    @Published var isLoading = false
    @Published var isLoadingHistory = false
    @Published var isDiscoveringStations = false
    @Published var errorMessage: String?
    @Published var lastRefreshTime: Date = Date()
    
    // Caching and rate limiting
    private var dataFreshnessDuration: TimeInterval = 120 // 2 minutes freshness
    private var lastRequestTimes: [String: Date] = [:]
    private var pendingRequests: Set<String> = []
    private let requestQueue = DispatchQueue(label: "weatherstation.requests", qos: .userInitiated)
    private var maxConcurrentRequests = 3
    
    private init() {
        loadCredentials()
        loadWeatherStations()
    }
    
    // MARK: - Optimized Data Fetching
    
    func fetchAllWeatherData(forceRefresh: Bool = false) async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        let activeStations = weatherStations.filter { $0.isActive }
        print("📊 Fetching data for \(activeStations.count) active stations (concurrent: \(maxConcurrentRequests))")
        
        // Filter stations that actually need fresh data
        let stationsToFetch: [WeatherStation]
        if forceRefresh {
            stationsToFetch = activeStations
        } else {
            stationsToFetch = activeStations.filter { station in
                shouldFetchFreshData(for: station)
            }
        }
        
        if stationsToFetch.isEmpty {
            await MainActor.run {
                isLoading = false
                print("✅ All station data is still fresh, no API calls needed")
            }
            return
        }
        
        print("📊 \(stationsToFetch.count) stations need fresh data")
        
        // Use TaskGroup for concurrent requests with rate limiting
        await withTaskGroup(of: Void.self) { group in
            let semaphore = AsyncSemaphore(value: maxConcurrentRequests)
            
            for station in stationsToFetch {
                group.addTask {
                    await semaphore.wait()
                    defer { 
                        Task { await semaphore.signal() }
                    }
                    
                    await self.fetchWeatherDataOptimized(for: station)
                    
                    // Small delay to be respectful to the API
                    try? await Task.sleep(nanoseconds: 250_000_000) // 0.25 seconds
                }
            }
        }
        
        await MainActor.run {
            isLoading = false
            lastRefreshTime = Date()
            print("✅ Concurrent fetch completed for \(stationsToFetch.count) stations")
        }
    }
    
    private func shouldFetchFreshData(for station: WeatherStation) -> Bool {
        // Check if we have data and it's still fresh
        if let lastData = weatherData[station.macAddress],
           let lastUpdated = station.lastUpdated,
           TimestampExtractor.isDataFresh(lastUpdated, freshnessDuration: dataFreshnessDuration) {
            let ageSeconds = Int(Date().timeIntervalSince(lastUpdated))
            print("📊 Station \(station.name) has fresh data (age: \(ageSeconds)s)")
            return false
        }
        
        // Check if we're already fetching this station
        if pendingRequests.contains(station.macAddress) {
            print("📊 Station \(station.name) fetch already in progress")
            return false
        }
        
        return true
    }
    
    private func fetchWeatherDataOptimized(for station: WeatherStation) async {
        guard credentials.isValid else {
            await MainActor.run {
                print("❌ Credentials invalid for \(station.name)")
                errorMessage = "API credentials are not configured"
            }
            return
        }
        
        // Request deduplication
        await requestQueue.run {
            self.pendingRequests.insert(station.macAddress)
        }
        
        defer {
            Task {
                await requestQueue.run {
                    self.pendingRequests.remove(station.macAddress)
                }
            }
        }
        
        // Use the working "all" parameter for now to avoid parsing issues
        // We can optimize the callback parameter later once parsing is more robust
        let urlString = "\(realTimeURL)?application_key=\(credentials.applicationKey)&api_key=\(credentials.apiKey)&mac=\(station.macAddress)&call_back=all"
        
        guard let url = URL(string: urlString) else {
            await MainActor.run {
                errorMessage = "Invalid URL for \(station.name): \(urlString)"
            }
            return
        }
        
        print("🌐 [Station: \(station.name)] Requesting data")
        
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.timeoutInterval = 15.0 // Shorter timeout for responsiveness
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("gzip", forHTTPHeaderField: "Accept-Encoding") // Enable compression
            
            // Allow caching for recent requests
            if let lastRequest = lastRequestTimes[station.macAddress],
               Date().timeIntervalSince(lastRequest) < 60 {
                request.cachePolicy = .returnCacheDataElseLoad
            } else {
                request.cachePolicy = .useProtocolCachePolicy
            }
            
            let startTime = Date()
            let (data, response) = try await session.data(for: request)
            let requestDuration = Date().timeIntervalSince(startTime)
            
            await requestQueue.run {
                self.lastRequestTimes[station.macAddress] = Date()
            }
            
            print("📡 [Station: \(station.name)] Response: \(data.count) bytes in \(String(format: "%.2f", requestDuration))s")
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 429 {
                    // Rate limited - back off
                    print("⚠️ Rate limited, reducing concurrent requests")
                    maxConcurrentRequests = max(1, maxConcurrentRequests - 1)
                    await MainActor.run {
                        errorMessage = "API rate limited, reducing request speed"
                    }
                    return
                } else if httpResponse.statusCode != 200 {
                    await MainActor.run {
                        errorMessage = "HTTP \(httpResponse.statusCode) for \(station.name)"
                    }
                    return
                }
            }
            
            // Try safe parsing first
            if let weatherResponse = parseWeatherResponseSafely(from: data, for: station) {
                if weatherResponse.code == 0 {
                    await MainActor.run {
                        weatherData[station.macAddress] = weatherResponse.data
                        updateStationLastUpdated(station, weatherData: weatherResponse.data)
                        print("✅ [Station: \(station.name)] Data updated successfully")
                        
                        // Clear any error for this station
                        if let currentError = errorMessage, currentError.contains(station.name) {
                            errorMessage = nil
                        }
                    }
                    
                    // Increase concurrent requests if we're successful
                    if maxConcurrentRequests < 6 {
                        maxConcurrentRequests += 1
                    }
                } else {
                    await MainActor.run {
                        errorMessage = "API Error for \(station.name): \(weatherResponse.msg) (Code: \(weatherResponse.code))"
                    }
                }
            } else {
                await MainActor.run {
                    errorMessage = "Failed to parse response for \(station.name)"
                }
            }
            
        } catch let networkError {
            await MainActor.run {
                let detailedError = "Network Error for \(station.name): \(networkError.localizedDescription)"
                print("❌ \(detailedError)")
                errorMessage = detailedError
            }
        }
    }
    
    // Legacy method for backward compatibility
    func fetchWeatherData(for station: WeatherStation) async {
        await fetchWeatherDataOptimized(for: station)
    }
    
    // MARK: - Enhanced Data Freshness Management (with TimestampExtractor)
    
    func isDataFresh(for station: WeatherStation) -> Bool {
        guard let lastUpdated = station.lastUpdated else { return false }
        return TimestampExtractor.isDataFresh(lastUpdated, freshnessDuration: dataFreshnessDuration)
    }
    
    func getDataAge(for station: WeatherStation) -> String {
        guard let lastUpdated = station.lastUpdated else { return "Never" }
        return TimestampExtractor.formatDataAge(from: lastUpdated)
    }
    
    /// Returns the formatted data recording time in the station's timezone
    func getFormattedDataTime(for station: WeatherStation, style: DateFormatter.Style = .short) -> String? {
        guard let lastUpdated = station.lastUpdated else { return nil }
        return TimestampExtractor.formatTimestamp(lastUpdated, for: station, style: style)
    }
    
    /// Returns the actual recording time of the weather data in the station's timezone
    func getDataRecordingTime(for station: WeatherStation) -> String? {
        guard let lastUpdated = station.lastUpdated else { return nil }
        return TimestampExtractor.formatTimestamp(lastUpdated, for: station, format: "MMM d, yyyy 'at' h:mm a")
    }
    
    /// Debug method to test timestamp parsing
    func testTimestampParsing(_ timestamp: String = "1761510950") {
        print("🧪 === TIMESTAMP PARSING TEST ===")
        let (parsed, analysis) = TimestampExtractor.testTimestampParsing(timestamp)
        print(analysis)
        
        if let parsedDate = parsed {
            // Test with a sample station
            if let station = weatherStations.first {
                let formatted = TimestampExtractor.formatTimestamp(parsedDate, for: station, style: .medium)
                print("Formatted for station \(station.name): \(formatted)")
                print("Station timezone: \(station.timeZone.identifier)")
            }
        }
        print("🧪 === END TEST ===")
    }
    
    func setDataFreshnessDuration(_ duration: TimeInterval) {
        dataFreshnessDuration = duration
        print("📊 Data freshness duration set to \(Int(duration)) seconds")
    }
    
    // MARK: - Background Refresh Management
    
    func refreshStaleData() async {
        let staleStations = weatherStations.filter { station in
            station.isActive && !isDataFresh(for: station)
        }
        
        if staleStations.isEmpty {
            print("📊 No stale data to refresh")
            return
        }
        
        print("📊 Refreshing \(staleStations.count) stations with stale data")
        
        await withTaskGroup(of: Void.self) { group in
            let semaphore = AsyncSemaphore(value: 2) // More conservative for background refresh
            
            for station in staleStations {
                group.addTask {
                    await semaphore.wait()
                    defer { 
                        Task { await semaphore.signal() }
                    }
                    await self.fetchWeatherDataOptimized(for: station)
                }
            }
        }
    }
    
    func fetchHistoricalData(for station: WeatherStation, timeRange: HistoricalTimeRange, sensors: [String] = ["outdoor", "indoor", "rainfall_piezo", "wind", "pressure"]) async {
        guard credentials.isValid else {
            await MainActor.run {
                errorMessage = "API credentials are not configured"
            }
            return
        }

        await MainActor.run {
            isLoadingHistory = true
            
            // Warn users about data limitations
            if timeRange == .last90Days || timeRange == .last365Days {
                print("⚠️  Note: Requesting \(timeRange.rawValue) of data. API limitations:")
                print("   • Daily data: Only 3 months available")
                print("   • Weekly data: Up to 1 year available")
                print("   • Using \(timeRange.cycleType) cycle for this request")
            }
        }

        let endDate = Date()
        let startDate = endDate.addingTimeInterval(-timeRange.timeInterval)
        
        // For longer periods, we need to adjust the start date based on API retention limits
        let adjustedStartDate: Date
        switch timeRange {
        case .last90Days:
            // Limit to 90 days for daily data (API only retains ~3 months)
            adjustedStartDate = max(startDate, endDate.addingTimeInterval(-90 * 24 * 3600))
        case .last365Days:
            // Use weekly data which has 1 year retention
            adjustedStartDate = startDate
        default:
            adjustedStartDate = startDate
        }

        // Format dates as ISO8601
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        dateFormatter.timeZone = TimeZone.current
        
        let startDateString = dateFormatter.string(from: adjustedStartDate)
        let endDateString = dateFormatter.string(from: endDate)
        let callBack = sensors.joined(separator: ",")
        
        // Build historical data URL
        let urlString = "\(historyURL)?application_key=\(credentials.applicationKey)&api_key=\(credentials.apiKey)&mac=\(station.macAddress)&start_date=\(startDateString)&end_date=\(endDateString)&cycle_type=\(timeRange.cycleType)&call_back=\(callBack)"
        
        guard let url = URL(string: urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "") else {
            await MainActor.run {
                errorMessage = "Invalid historical data URL for \(station.name)"
                isLoadingHistory = false
            }
            return
        }
        
        print("🕒 [Historical: \(station.name)] Requesting \(timeRange.rawValue)")
        print("🕒 Date range: \(startDateString) to \(endDateString)")
        print("🕒 Cycle type: \(timeRange.cycleType)")
        print("🕒 URL: \(url.absoluteString)")
        
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 60.0 // Longer timeout for historical data
            request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            
            let (data, response) = try await session.data(for: request)
            
            print("📡 [Historical: \(station.name)] Response received: \(data.count) bytes")
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 [Historical: \(station.name)] HTTP Status: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode != 200 {
                    await MainActor.run {
                        errorMessage = "HTTP \(httpResponse.statusCode) for historical data: \(station.name)"
                        isLoadingHistory = false
                    }
                    return
                }
            }
            
            // Parse the historical response
            let decoder = JSONDecoder()
            let historicalResponse = try decoder.decode(HistoricalWeatherResponse.self, from: data)
            
            await MainActor.run {
                if historicalResponse.code == 0 {
                    historicalData[station.macAddress] = historicalResponse.data
                    print("✅ [Historical: \(station.name)] Successfully loaded historical data")
                    if let currentError = errorMessage, currentError.contains(station.name) {
                        errorMessage = nil
                    }
                } else {
                    errorMessage = "Historical API Error for \(station.name): \(historicalResponse.msg) (Code: \(historicalResponse.code))"
                }
                isLoadingHistory = false
            }
            
        } catch {
            await MainActor.run {
                errorMessage = "Historical data error for \(station.name): \(error.localizedDescription)"
                isLoadingHistory = false
                print("❌ Historical data error: \(error)")
            }
        }
    }
    
    func discoverWeatherStations() async -> (success: Bool, message: String) {
        guard credentials.isValid else {
            return (false, "API credentials are not configured")
        }
        
        await MainActor.run {
            isDiscoveringStations = true
            discoveredStations = []
            errorMessage = nil
        }
        
        // Build device list URL
        let urlString = "\(deviceListURL)?application_key=\(credentials.applicationKey)&api_key=\(credentials.apiKey)"
        
        guard let url = URL(string: urlString) else {
            await MainActor.run {
                isDiscoveringStations = false
            }
            return (false, "Invalid device list URL")
        }
        
        print("🔍 Discovering weather stations...")
        print("🔍 URL: \(url.absoluteString)")
        
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 30.0
            request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            
            let (data, response) = try await session.data(for: request)
            
            print("📡 Device list response received: \(data.count) bytes")
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 HTTP Status: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode != 200 {
                    await MainActor.run {
                        isDiscoveringStations = false
                    }
                    return (false, "HTTP \(httpResponse.statusCode)")
                }
            }
            
            // Let's see the raw response first
            let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response"
            print("📄 Raw device list response:")
            print("--- START RESPONSE ---")
            print(responseString)
            print("--- END RESPONSE ---")
            
            // Try to parse as basic JSON first to see the structure
            do {
                if let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("📊 Device list JSON structure:")
                    print("📊 Root keys: \(Array(jsonObject.keys))")
                    
                    if let code = jsonObject["code"] as? Int {
                        print("📊 API code: \(code)")
                        
                        if code != 0 {
                            let msg = jsonObject["msg"] as? String ?? "Unknown error"
                            await MainActor.run {
                                isDiscoveringStations = false
                            }
                            return (false, "API Error: \(msg) (Code: \(code))")
                        }
                    }
                    
                    // Check what's in the data field
                    if let dataField = jsonObject["data"] as? [Any] {
                        print("📊 Data field is an array with \(dataField.count) items")
                        
                        // Log the first device structure if available
                        if let firstDevice = dataField.first as? [String: Any] {
                            print("📊 First device keys: \(Array(firstDevice.keys))")
                        }
                    } else {
                        print("📊 Data field structure: \(type(of: jsonObject["data"]))")
                        print("📊 Data field value: \(jsonObject["data"] ?? "nil")")
                    }
                } else {
                    await MainActor.run {
                        isDiscoveringStations = false
                    }
                    return (false, "Invalid JSON response structure")
                }
                
                // Now try our strict model parsing
                print("📊 Attempting to parse with DeviceListResponse model...")
                
                let decoder = JSONDecoder()
                let deviceListResponse = try decoder.decode(DeviceListResponse.self, from: data)
                
                await MainActor.run {
                    isDiscoveringStations = false
                    
                    if deviceListResponse.code == 0 {
                        discoveredStations = deviceListResponse.data.list
                        print("✅ Successfully discovered \(discoveredStations.count) weather stations")
                        
                        // Log discovered stations
                        for device in discoveredStations {
                            print("📍 Found device: \(device.name) (\(device.mac))")
                            print("   Device Type: \(device.type) (\(deviceTypeDescription(device.type)))")
                            if let stationType = device.stationtype {
                                print("   Station Type: \(stationType)")
                            }
                            if let createtime = device.createtime {
                                let date = Date(timeIntervalSince1970: TimeInterval(createtime))
                                print("   Created: \(date)")
                            }
                            if let longitude = device.longitude, let latitude = device.latitude {
                                print("   Location: \(latitude), \(longitude)")
                            }
                        }
                    }
                }
                
                if deviceListResponse.code == 0 {
                    return (true, "Found \(discoveredStations.count) weather station\(discoveredStations.count == 1 ? "" : "s")")
                } else {
                    let errorMsg: String
                    switch deviceListResponse.code {
                    case 40010:
                        errorMsg = "Invalid Application Key"
                    case 40011:
                        errorMsg = "Invalid API Key"
                    case 40012:
                        errorMsg = "Access denied or no devices found"
                    default:
                        errorMsg = "\(deviceListResponse.msg) (Code: \(deviceListResponse.code))"
                    }
                    return (false, "API Error: \(errorMsg)")
                }
                
            } catch let jsonError {
                print("❌ JSON parsing failed: \(jsonError)")
                
                await MainActor.run {
                    isDiscoveringStations = false
                }
                
                return (false, "Discovery failed: Unable to parse API response. Check console for details.")
            }
            
        } catch {
            await MainActor.run {
                isDiscoveringStations = false
            }
            print("❌ Device discovery error: \(error)")
            return (false, "Discovery failed: \(error.localizedDescription)")
        }
    }
    
    func addDiscoveredStation(_ device: EcowittDevice) {
        let newStation = device.toWeatherStation()
        
        // Check if station already exists
        if let existingIndex = weatherStations.firstIndex(where: { $0.macAddress == newStation.macAddress }) {
            // Update existing station with discovery data while preserving user settings
            var updatedStation = weatherStations[existingIndex]
            updatedStation.stationType = newStation.stationType
            updatedStation.creationDate = newStation.creationDate
            updatedStation.deviceType = newStation.deviceType
            updatedStation.latitude = newStation.latitude
            updatedStation.longitude = newStation.longitude
            updatedStation.timeZoneId = newStation.timeZoneId
            
            weatherStations[existingIndex] = updatedStation
            saveWeatherStations()
            print("✅ Updated existing station with discovery data: \(updatedStation.name) (\(updatedStation.macAddress))")
        } else {
            weatherStations.append(newStation)
            saveWeatherStations()
            print("✅ Added new station: \(newStation.name) (\(newStation.macAddress))")
        }
    }
    
    func addAllDiscoveredStations() {
        var addedCount = 0
        
        for device in discoveredStations {
            let station = device.toWeatherStation()
            if !weatherStations.contains(where: { $0.macAddress == station.macAddress }) {
                weatherStations.append(station)
                addedCount += 1
            }
        }
        
        if addedCount > 0 {
            saveWeatherStations()
            print("✅ Added \(addedCount) new weather station\(addedCount == 1 ? "" : "s")")
        }
    }
    
    // Helper function to get available data range info
    func getDataAvailabilityInfo() -> String {
        return """
        Historical Data Availability:
        • Hourly/Sub-hourly data: Available for short periods (hours to days)
        • Daily data: Available for up to 3 months
        • Weekly data: Available for up to 1 year  
        • Monthly data: Available for up to 2 years
        
        Note: Longer time ranges use less frequent data points but cover more time.
        """
    }
    
    // Helper function to convert historical measurement to chart data points
    func getChartData(from measurement: HistoricalMeasurement?) -> [ChartDataPoint] {
        guard let measurement = measurement else { return [] }
        
        var dataPoints: [ChartDataPoint] = []
        
        for (timestampString, valueString) in measurement.list {
            if let timestamp = Double(timestampString),
               let value = Double(valueString) {
                let date = Date(timeIntervalSince1970: timestamp)
                dataPoints.append(ChartDataPoint(timestamp: date, value: value))
            }
        }
        
        return dataPoints.sorted { $0.timestamp < $1.timestamp }
    }
    
    func testAPIConnection() async -> (success: Bool, message: String) {
        guard credentials.isValid else {
            return (false, "API credentials are not configured")
        }
        
        guard let firstStation = weatherStations.first else {
            return (false, "No weather stations configured")
        }
        
        // Build URL exactly like your working example
        let urlString = "\(realTimeURL)?application_key=\(credentials.applicationKey)&api_key=\(credentials.apiKey)&mac=\(firstStation.macAddress)&call_back=all"
        
        guard let url = URL(string: urlString) else {
            return (false, "Invalid URL configuration")
        }
        
        do {
            let (data, response) = try await session.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode != 200 {
                    return (false, "HTTP Error: \(httpResponse.statusCode)")
                }
            }
            
            if data.isEmpty {
                return (false, "Empty response from API")
            }
            
            // Check if it's valid JSON
            if let jsonString = String(data: data, encoding: .utf8) {
                if !jsonString.hasPrefix("{") {
                    return (false, "Invalid response format")
                }
            }
            
            let decodedResponse = try JSONDecoder().decode(WeatherStationResponse.self, from: data)
            
            if decodedResponse.code == 0 {
                return (true, "API connection successful!")
            } else {
                let errorMsg: String
                switch decodedResponse.code {
                case 40010:
                    errorMsg = "Invalid Application Key"
                case 40011:
                    errorMsg = "Invalid API Key"
                case 40012:
                    errorMsg = "Device not found or not authorized"
                case 40013:
                    errorMsg = "Device offline or no data available"
                default:
                    errorMsg = "\(decodedResponse.msg) (Code: \(decodedResponse.code))"
                }
                return (false, "API Error: \(errorMsg)")
            }
            
        } catch {
            return (false, "Connection failed: \(error.localizedDescription)")
        }
    }
    
    func addWeatherStation(_ station: WeatherStation) {
        weatherStations.append(station)
        saveWeatherStations()
    }
    
    func removeWeatherStation(_ station: WeatherStation) {
        weatherStations.removeAll { $0.id == station.id }
        weatherData.removeValue(forKey: station.macAddress)
        saveWeatherStations()
    }
    
    func updateStation(_ station: WeatherStation) {
        updateWeatherStation(station)
    }
    
    func updateWeatherStation(_ station: WeatherStation) {
        if let index = weatherStations.firstIndex(where: { $0.id == station.id }) {
            weatherStations[index] = station
            saveWeatherStations()
        }
    }
    
    // MARK: - Enhanced Timestamp Management (Using TimestampExtractor)
    
    private func updateStationLastUpdated(_ station: WeatherStation, weatherData: WeatherStationData) {
        // Try using TimestampExtractor to get the most recent timestamp from ALL sensor data
        if let mostRecentTimestamp = TimestampExtractor.extractMostRecentTimestamp(from: weatherData) {
            if let index = weatherStations.firstIndex(where: { $0.id == station.id }) {
                let oldTimestamp = weatherStations[index].lastUpdated
                weatherStations[index].lastUpdated = mostRecentTimestamp
                saveWeatherStations()
                
                print("🕐 Updated \(station.name) timestamp (from all sensors):")
                print("   Old: \(oldTimestamp?.description ?? "never")")
                print("   New: \(mostRecentTimestamp.description)")
                print("   Station timezone: \(station.timeZone.identifier)")
                print("   Data age: \(TimestampExtractor.formatDataAge(from: mostRecentTimestamp))")
                
                // Warn if timestamp seems problematic
                let currentTime = Date()
                let timeDifference = abs(currentTime.timeIntervalSince(mostRecentTimestamp))
                if timeDifference > 86400 { // More than 1 day difference
                    print("⚠️ WARNING: Weather data timestamp is \(Int(timeDifference/3600)) hours off from current time")
                }
            } else {
                print("❌ Could not find station \(station.name) to update timestamp")
            }
            return
        }
        
        // Fallback to original method using outdoor temperature timestamp if TimestampExtractor fails
        print("⚠️ TimestampExtractor failed, falling back to outdoor temperature timestamp")
        let timestampString = weatherData.outdoor.temperature.time
        
        // Parse the timestamp - it could be Unix timestamp or formatted date string
        let actualDataTime: Date
        
        if let unixTimestamp = Double(timestampString) {
            // It's a Unix timestamp (seconds since 1970)
            actualDataTime = Date(timeIntervalSince1970: unixTimestamp)
        } else {
            // Try parsing as formatted date string - need to determine the format from actual data
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            dateFormatter.timeZone = TimeZone.current
            
            if let parsedDate = dateFormatter.date(from: timestampString) {
                actualDataTime = parsedDate
            } else {
                // If we can't parse the timestamp, fall back to current time
                print("⚠️ Could not parse timestamp '\(timestampString)' for \(station.name), using current time")
                actualDataTime = Date()
            }
        }
        
        if let index = weatherStations.firstIndex(where: { $0.id == station.id }) {
            let oldTimestamp = weatherStations[index].lastUpdated
            weatherStations[index].lastUpdated = actualDataTime
            saveWeatherStations()
            
            print("🕐 Updated \(station.name) timestamp (fallback method):")
            print("   Old: \(oldTimestamp?.description ?? "never")")
            print("   New: \(actualDataTime.description) (from weather data)")
            print("   Raw timestamp: \(timestampString)")
        } else {
            print("❌ Could not find station \(station.name) to update timestamp")
        }
    }
    
    func updateCredentials(applicationKey: String, apiKey: String) {
        credentials = APICredentials(applicationKey: applicationKey, apiKey: apiKey)
        saveCredentials()
    }
    
    // MARK: - Persistence
    
    private func saveCredentials() {
        if let data = try? JSONEncoder().encode(credentials) {
            UserDefaults.standard.set(data, forKey: "WeatherStationCredentials")
        }
    }
    
    private func loadCredentials() {
        if let data = UserDefaults.standard.data(forKey: "WeatherStationCredentials"),
           let savedCredentials = try? JSONDecoder().decode(APICredentials.self, from: data) {
            credentials = savedCredentials
        }
    }
    
    private func saveWeatherStations() {
        if let data = try? JSONEncoder().encode(weatherStations) {
            UserDefaults.standard.set(data, forKey: "WeatherStations")
        }
    }
    
    private func loadWeatherStations() {
        if let data = UserDefaults.standard.data(forKey: "WeatherStations"),
           let savedStations = try? JSONDecoder().decode([WeatherStation].self, from: data) {
            weatherStations = savedStations
        }
    }
    
    func fetchStationInfo(for station: WeatherStation) async -> (success: Bool, message: String) {
        guard credentials.isValid else {
            return (false, "API credentials are not configured")
        }
        
        // Build device info URL
        let urlString = "https://api.ecowitt.net/api/v3/device/info?application_key=\(credentials.applicationKey)&api_key=\(credentials.apiKey)&mac=\(station.macAddress)&call_back=all"
        
        guard let url = URL(string: urlString) else {
            return (false, "Invalid device info URL")
        }
        
        print("🔍 Fetching station info for \(station.name)...")
        print("🔍 URL: \(url.absoluteString)")
        
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 30.0
            request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 Station info HTTP Status: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode != 200 {
                    return (false, "HTTP \(httpResponse.statusCode)")
                }
            }
            
            // Parse the response
            if let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let code = jsonObject["code"] as? Int {
                
                print("📊 Device info JSON response: \(jsonObject)")
                
                if code == 0,
                   let dataField = jsonObject["data"] as? [String: Any] {
                    
                    // Extract station info
                    let latitude = dataField["latitude"] as? Double
                    let longitude = dataField["longitude"] as? Double
                    let timeZoneId = dataField["date_zone_id"] as? String
                    let stationType = dataField["stationtype"] as? String
                    let createtime = dataField["createtime"] as? Int
                    
                    // Look for camera-related fields
                    print("🔍 Checking for camera fields in device info...")
                    for (key, value) in dataField {
                        if key.lowercased().contains("camera") || 
                           key.lowercased().contains("image") || 
                           key.lowercased().contains("photo") || 
                           key.lowercased().contains("picture") {
                            print("📷 Found potential camera field: \(key) = \(value)")
                        }
                    }
                    
                    // Update the station with the new info
                    await MainActor.run {
                        if let index = weatherStations.firstIndex(where: { $0.macAddress == station.macAddress }) {
                            var updatedStation = weatherStations[index]
                            
                            if let lat = latitude { updatedStation.latitude = lat }
                            if let lon = longitude { updatedStation.longitude = lon }
                            if let tzId = timeZoneId { updatedStation.timeZoneId = tzId }
                            if let stType = stationType { updatedStation.stationType = stType }
                            if let createTime = createtime { 
                                updatedStation.creationDate = Date(timeIntervalSince1970: TimeInterval(createTime))
                            }
                            
                            weatherStations[index] = updatedStation
                            saveWeatherStations()
                            
                            print("✅ Updated station info for \(station.name):")
                            if let tzId = timeZoneId {
                                print("   Timezone: \(tzId)")
                            }
                            if let lat = latitude, let lon = longitude {
                                print("   Location: \(lat), \(lon)")
                            }
                        }
                    }
                    
                    return (true, "Station info updated successfully")
                } else {
                    let msg = jsonObject["msg"] as? String ?? "Unknown error"
                    return (false, "API Error: \(msg) (Code: \(code))")
                }
            }
            
            return (false, "Invalid response format")
            
        } catch {
            print("❌ Station info fetch error: \(error)")
            return (false, "Failed to fetch station info: \(error.localizedDescription)")
        }
    }
    
    func fetchCameraImage(for station: WeatherStation) async -> String? {
        guard credentials.isValid else {
            print("❌ Credentials invalid for camera image fetch")
            return nil
        }
        
        // Only proceed if station has an associated camera
        guard let cameraMAC = station.associatedCameraMAC else {
            print("❌ No associated camera for station: \(station.name)")
            return nil
        }
        
        print("🔍 Starting camera image search for station: \(station.name)")
        print("🔍 Using associated camera MAC: \(cameraMAC)")
        
        // Construct the camera endpoint URL carefully
        let baseURL = "https://cdnapi.ecowitt.net/api/v3/device/real_time"
        let applicationKey = credentials.applicationKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let apiKey = credentials.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let url = URL(string: "\(baseURL)?application_key=\(applicationKey)&api_key=\(apiKey)&mac=\(cameraMAC)&call_back=camera") else {
            print("❌ Invalid camera URL construction")
            return nil
        }
        
        print("🔍 Camera endpoint URL: \(url.absoluteString)")
        
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 30.0
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 Camera HTTP Status: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 200 {
                    print("📊 Response size: \(data.count) bytes")
                    
                    // Log the raw response for debugging
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("📄 Camera raw response: \(responseString)")
                    }
                    
                    // Check if data field is an empty array (no camera data available)
                    if let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let dataField = jsonObject["data"] as? [Any],
                       dataField.isEmpty {
                        print("❌ Camera API returned empty data array - no camera data available for this device")
                        return nil
                    }
                    
                    // Try to parse as camera response
                    do {
                        let decoder = JSONDecoder()
                        let cameraResponse = try decoder.decode(CameraResponse.self, from: data)
                        
                        if cameraResponse.code == 0 {
                            let imageUrl = cameraResponse.data.camera.photo.url
                            let imageTime = cameraResponse.data.camera.photo.time
                            
                            print("✅ Found camera image URL: \(imageUrl)")
                            print("📷 Image timestamp: \(imageTime)")
                            
                            return imageUrl
                        } else {
                            print("❌ Camera API error: \(cameraResponse.msg) (Code: \(cameraResponse.code))")
                        }
                    } catch {
                        print("❌ Failed to parse camera response: \(error)")
                        print("❌ This likely means the device is not a camera or has no camera data available")
                        
                        return nil
                    }
                } else {
                    print("❌ HTTP Error: \(httpResponse.statusCode)")
                    
                    // Log error response body
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("❌ Error response: \(responseString)")
                    }
                }
            }
            
        } catch {
            print("❌ Camera request error: \(error.localizedDescription)")
        }
        
        print("❌ No camera image URL found for station: \(station.name)")
        return nil
    }
    
    private func extractImageURL(from json: [String: Any]) -> String? {
        // Check the specific camera structure we found: data.camera.photo.url
        if let data = json["data"] as? [String: Any],
           let camera = data["camera"] as? [String: Any],
           let photo = camera["photo"] as? [String: Any],
           let url = photo["url"] as? String {
            return url
        }
        
        // Try other possible structures
        let possibleKeys = [
            "image_url", "imageUrl", "camera_url", "cameraUrl", 
            "latest_image", "latestImage", "picture_url", "pictureUrl",
            "snapshot_url", "snapshotUrl", "live_image", "liveImage", "url"
        ]
        
        // Check root level
        for key in possibleKeys {
            if let url = json[key] as? String, !url.isEmpty {
                return url
            }
        }
        
        // Check in data field
        if let data = json["data"] as? [String: Any] {
            for key in possibleKeys {
                if let url = data[key] as? String, !url.isEmpty {
                    return url
                }
            }
            
            // Check in camera field within data
            if let camera = data["camera"] as? [String: Any] {
                for key in possibleKeys {
                    if let url = camera[key] as? String, !url.isEmpty {
                        return url
                    }
                }
            }
        }
        
        return nil
    }
    
    func associateCamerasWithStations(distanceThresholdKm: Double = 2.0) {
        print("🔗 Starting automatic camera-station association...")
        print("🔗 Distance threshold: \(distanceThresholdKm) km")
        
        // Get all camera devices (type 2)
        let cameraDevices = discoveredStations.filter { $0.type == 2 }
        
        // Get all weather station devices (any type, or specifically type 1)
        let stationDevices = weatherStations.filter { station in
            // Accept stations without device type or with device type 1
            station.deviceType == nil || station.deviceType == 1
        }
        
        print("📷 Found \(cameraDevices.count) camera devices")
        print("🌡️ Found \(stationDevices.count) weather stations")
        
        // Debug: show all stations
        for station in weatherStations {
            print("🌡️ Station: \(station.name), deviceType: \(station.deviceType?.description ?? "nil"), location: \(station.latitude?.description ?? "nil"), \(station.longitude?.description ?? "nil")")
        }
        
        for camera in cameraDevices {
            guard let cameraLat = camera.latitude, let cameraLon = camera.longitude else {
                print("📷 Camera \(camera.name) has no location data, skipping")
                continue
            }
            
            print("📷 Processing camera: \(camera.name) at (\(cameraLat), \(cameraLon))")
            
            var associatedStations: [WeatherStation] = []
            
            // Find ALL stations within the threshold distance
            for station in stationDevices {
                guard let stationLat = station.latitude, let stationLon = station.longitude else {
                    print("📍 Station \(station.name) has no location data, skipping")
                    continue
                }
                
                let distance = calculateDistance(
                    lat1: cameraLat, lon1: cameraLon,
                    lat2: stationLat, lon2: stationLon
                )
                
                print("📍 Distance to \(station.name): \(String(format: "%.3f", distance)) km")
                
                if distance <= distanceThresholdKm {
                    associatedStations.append(station)
                    print("✅ Station \(station.name) is within threshold (\(String(format: "%.3f", distance)) km)")
                }
            }
            
            // Associate camera with all nearby stations
            if !associatedStations.isEmpty {
                for station in associatedStations {
                    if let index = weatherStations.firstIndex(where: { $0.id == station.id }) {
                        weatherStations[index].associatedCameraMAC = camera.mac
                        print("✅ Associated camera \(camera.name) with station \(station.name)")
                    }
                }
                saveWeatherStations()
                print("🎉 Camera \(camera.name) associated with \(associatedStations.count) station(s)")
            } else {
                print("❌ No weather stations found within \(distanceThresholdKm) km for camera \(camera.name)")
            }
        }
        
        print("🔗 Camera-station association complete")
    }
    
    private func calculateDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let earthRadius = 6371.0 // Earth's radius in kilometers
        
        let dLat = (lat2 - lat1) * .pi / 180.0
        let dLon = (lon2 - lon1) * .pi / 180.0
        
        let a = sin(dLat / 2) * sin(dLat / 2) +
                cos(lat1 * .pi / 180.0) * cos(lat2 * .pi / 180.0) *
                sin(dLon / 2) * sin(dLon / 2)
        
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return earthRadius * c
    }
    
    private func deviceTypeDescription(_ type: Int) -> String {
        switch type {
        case 1: return "Weather Station Gateway"
        case 2: return "Weather Camera"
        default: return "Device Type \(type)"
        }
    }
    
    // MARK: - Model Validation and Recovery
    
    private func parseWeatherResponseSafely(from data: Data, for station: WeatherStation) -> WeatherStationResponse? {
        let decoder = JSONDecoder()
        
        // First, try standard parsing
        do {
            return try decoder.decode(WeatherStationResponse.self, from: data)
        } catch {
            print("❌ Standard parsing failed for \(station.name): \(error)")
        }
        
        // If standard parsing fails, try to parse as generic JSON and extract what we can
        do {
            if let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let code = jsonObject["code"] as? Int,
               let msg = jsonObject["msg"] as? String {
                
                print("📊 [Station: \(station.name)] API Response - Code: \(code), Message: \(msg)")
                
                if code != 0 {
                    return WeatherStationResponse(code: code, msg: msg, data: WeatherStationData.empty())
                }
                
                // Try to extract basic weather data even if some fields are missing
                if let dataField = jsonObject["data"] as? [String: Any] {
                    let extractedData = extractWeatherDataSafely(from: dataField, for: station)
                    return WeatherStationResponse(code: code, msg: msg, data: extractedData)
                }
            }
        } catch {
            print("❌ Even generic JSON parsing failed for \(station.name): \(error)")
        }
        
        return nil
    }
    
    private func extractWeatherDataSafely(from dataDict: [String: Any], for station: WeatherStation) -> WeatherStationData {
        print("📊 [Station: \(station.name)] Attempting safe data extraction from available fields")
        
        // Create empty data structure and fill what we can
        var extractedData = WeatherStationData.empty()
        
        // Extract outdoor data if available
        if let outdoorDict = dataDict["outdoor"] as? [String: Any] {
            print("📊 Found outdoor data for \(station.name)")
            // Try to extract basic outdoor measurements
            // This would need implementation based on your WeatherStationData model
        }
        
        // Extract indoor data if available
        if let indoorDict = dataDict["indoor"] as? [String: Any] {
            print("📊 Found indoor data for \(station.name)")
            // Try to extract basic indoor measurements
        }
        
        // Extract other sensor data
        for (key, value) in dataDict {
            print("📊 Available data field: \(key) (\(type(of: value)))")
        }
        
        return extractedData
    }
}

// MARK: - Utility Classes

actor AsyncSemaphore {
    private var value: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []
    
    init(value: Int) {
        self.value = value
    }
    
    func wait() async {
        value -= 1
        if value >= 0 {
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }
    
    func signal() {
        value += 1
        if !waiters.isEmpty {
            let waiter = waiters.removeFirst()
            waiter.resume()
        }
    }
}

extension DispatchQueue {
    func run<T>(_ block: @escaping () -> T) async -> T {
        await withCheckedContinuation { continuation in
            self.async {
                let result = block()
                continuation.resume(returning: result)
            }
        }
    }
}