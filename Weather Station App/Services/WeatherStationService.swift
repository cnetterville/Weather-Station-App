import Foundation
import Combine
import AppKit
import Darwin.Mach

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
    @Published var chartHistoricalData: [String: HistoricalWeatherData] = [:] // NEW: Separate data for charts
    @Published var isLoading = false
    @Published var isLoadingHistory = false
    @Published var isDiscoveringStations = false
    @Published var errorMessage: String?
    @Published var lastRefreshTime: Date = Date()
    @Published var isMemoryConstrained: Bool = false
    @Published var memoryPressureLevel: Int = 0 // 0=normal, 1=warning, 2=urgent, 3=critical
    
    // Timer management - properly retain references to prevent leaks
    private var memoryWarningCancellable: AnyCancellable?
    private var maintenanceTimer: AnyCancellable?
    private var memoryMonitorTimer: AnyCancellable?
    
    // Memory optimization settings
    private var maxHistoricalDataAge: TimeInterval = 24 * 60 * 60 // 24 hours
    private var maxWeatherDataEntries: Int = 50 // Limit concurrent station data
    private var shouldReduceUIUpdates: Bool = false
    
    // Caching and rate limiting
    private var dataFreshnessDuration: TimeInterval = 120 // 2 minutes freshness
    private var lastRequestTimes: [String: Date] = [:]
    private var pendingRequests: Set<String> = []
    private var pendingRequestTasks: [String: Task<Void, Never>] = [:] // Track actual tasks for deduplication
    private let requestQueue = DispatchQueue(label: "weatherstation.requests", qos: .userInitiated)
    private var maxConcurrentRequests = 3
    
    // Request deduplication - share results between identical concurrent requests
    private var sharedRequestResults: [String: Task<WeatherStationResponse?, Never>] = [:]
    private let sharedRequestQueue = DispatchQueue(label: "weatherstation.shared.requests", attributes: .concurrent)
    
    private init() {
        loadCredentials()
        loadWeatherStations()
        
        // PHASE 1: Initialize memory management
        setupMemoryManagement()
        
        // Setup observer for iCloud credential changes
        setupCredentialChangeObserver()
    }
    
    deinit {
        // PHASE 1: Ensure all timers and observers are properly cancelled
        cleanup()
    }
    
    // MARK: - Optimized Data Fetching
    
    func fetchAllWeatherData(forceRefresh: Bool = false) async {
        // PHASE 1: Respect memory constraints
        guard memoryPressureLevel < 3 || forceRefresh else {
            logMemory("Skipping data fetch due to critical memory pressure")
            return
        }
        
        await MainActor.run {
            // PHASE 1: Only update loading state if UI updates are allowed
            if shouldPerformUIUpdate() {
                isLoading = true
                errorMessage = nil
            }
        }
        
        let activeStations = weatherStations.filter { $0.isActive }
        
        // PHASE 1: Adjust concurrency based on memory pressure
        let adjustedConcurrency = memoryPressureLevel > 1 ? 
            min(maxConcurrentRequests, 2) : maxConcurrentRequests
        let optimalConcurrency = min(adjustedConcurrency, max(1, activeStations.count))
        
        logNetwork("Fetching data for \(activeStations.count) active stations (concurrent: \(optimalConcurrency), memory level: \(memoryPressureLevel))")
        
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
                if shouldPerformUIUpdate() {
                    isLoading = false
                }
                logRefresh("All station data is still fresh, no API calls needed")
            }
            return
        }
        
        logDebug(" \(stationsToFetch.count) stations need fresh data")
        
        // Use TaskGroup for concurrent requests with optimal concurrency
        await withTaskGroup(of: Void.self) { group in
            let semaphore = AsyncSemaphore(value: optimalConcurrency)
            
            for station in stationsToFetch {
                group.addTask {
                    await semaphore.wait()
                    defer { 
                        Task { await semaphore.signal() }
                    }
                    
                    // Fetch current data
                    await self.fetchWeatherDataOptimized(for: station)
                    
                    // PHASE 1: Skip historical data fetch under memory pressure
                    if await self.memoryPressureLevel < 2 {
                        // Also fetch today's historical data for high/low calculations (if not already cached)
                        if await !self.hasTodaysHistoricalData(for: station) {
                            await self.fetchTodaysHistoricalData(for: station)
                        }
                    }

                    
                    // PHASE 1: Increased delay under memory pressure
                    let baseDelay = stationsToFetch.count <= 2 ? 100_000_000 : 250_000_000 // 0.1s vs 0.25s
                    let memoryDelayMultiplier = await self.memoryPressureLevel > 1 ? 2 : 1
                    let delay = baseDelay * memoryDelayMultiplier
                    try? await Task.sleep(nanoseconds: UInt64(delay))
                }
            }
        }
        
        await MainActor.run {
            if shouldPerformUIUpdate() {
                isLoading = false
                lastRefreshTime = Date()
            }
            logRefresh(" Concurrent fetch completed for \(stationsToFetch.count) stations")
        }
    }
    
    private func shouldFetchFreshData(for station: WeatherStation) -> Bool {
        // Check if we have data and it's still fresh
        if let _ = weatherData[station.macAddress],
           let lastUpdated = station.lastUpdated,
           TimestampExtractor.isDataFresh(lastUpdated, freshnessDuration: dataFreshnessDuration) {
            let ageSeconds = Int(Date().timeIntervalSince(lastUpdated))
            logData(" Station \(station.name) has fresh data (age: \(ageSeconds)s)")
            return false
        }
        
        // Check if we're already fetching this station
        if pendingRequests.contains(station.macAddress) {
            logData(" Station \(station.name) fetch already in progress")
            return false
        }
        
        return true
    }
    
    func fetchWeatherDataOptimized(for station: WeatherStation) async {
        // Check if we should skip this request entirely
        if !shouldFetchFreshData(for: station) {
            return
        }
        
        // Mark request as pending for deduplication tracking
        _ = await requestQueue.run {
            self.pendingRequests.insert(station.macAddress)
        }
        
        defer {
            Task {
                _ = await requestQueue.run {
                    self.pendingRequests.remove(station.macAddress)
                }
            }
        }
        
        // Use shared request deduplication
        guard let sharedTask = getOrCreateSharedRequest(for: station) else {
            logNetwork(" [Station: \(station.name)] Failed to create request task")
            return
        }
        
        // Await the shared result
        let weatherResponse = await sharedTask.value
        
        // Process the result
        if let response = weatherResponse {
            if response.code == 0 {
                await MainActor.run {
                    weatherData[station.macAddress] = response.data
                    updateStationLastUpdated(station, weatherData: response.data)
                    logNetwork(" [Station: \(station.name)] Data updated successfully")
                    
                    // Clear any error for this station
                    if let currentError = errorMessage, currentError.contains(station.name) {
                        errorMessage = nil
                    }
                    
                    // Post notification that weather data was updated
                    NotificationCenter.default.post(name: .weatherDataUpdated, object: nil)
                }
            } else {
                await MainActor.run {
                    errorMessage = "API Error for \(station.name): \(response.msg) (Code: \(response.code))"
                }
            }
        } else {
            await MainActor.run {
                errorMessage = "Failed to get response for \(station.name)"
            }
        }
    }
    
    func fetchWeatherData(for station: WeatherStation) async {
        await fetchWeatherDataOptimized(for: station)
        
        // After successful data fetch, post notification
        await MainActor.run {
            NotificationCenter.default.post(name: .weatherDataUpdated, object: nil)
        }
    }
    
    // MARK: - Enhanced Request Deduplication
    
    /// Generate a unique request key for deduplication
    private func generateRequestKey(for station: WeatherStation) -> String {
        return "\(credentials.applicationKey)_\(credentials.apiKey)_\(station.macAddress)"
    }
    
    /// Get or create a shared request task for a station to prevent duplicate concurrent requests
    private func getOrCreateSharedRequest(for station: WeatherStation) -> Task<WeatherStationResponse?, Never>? {
        let requestKey = generateRequestKey(for: station)
        
        return sharedRequestQueue.sync {
            // Check if there's already a request in progress for this station
            if let existingTask = sharedRequestResults[requestKey] {
                logNetwork(" [Station: \(station.name)] Reusing existing request task")
                return existingTask
            }
            
            // Create new shared request task
            let newTask = Task<WeatherStationResponse?, Never> {
                defer {
                    // Clean up when task completes
                    sharedRequestQueue.async(flags: .barrier) {
                        self.sharedRequestResults.removeValue(forKey: requestKey)
                    }
                }
                
                return await self.performActualWeatherRequest(for: station)
            }
            
            sharedRequestResults[requestKey] = newTask
            logNetwork(" [Station: \(station.name)] Created new shared request task")
            return newTask
        }
    }
    
    /// Perform the actual network request (separated from deduplication logic)
    private func performActualWeatherRequest(for station: WeatherStation) async -> WeatherStationResponse? {
        guard credentials.isValid else {
            await MainActor.run {
                logError(" Credentials invalid for \(station.name)")
                errorMessage = "API credentials are not configured"
            }
            return nil
        }
        
        let urlString = "\(realTimeURL)?application_key=\(credentials.applicationKey)&api_key=\(credentials.apiKey)&mac=\(station.macAddress)&call_back=all"
        
        guard let url = URL(string: urlString) else {
            await MainActor.run {
                errorMessage = "Invalid URL for \(station.name): \(urlString)"
            }
            return nil
        }
        
        logNetwork(" [Station: \(station.name)] Performing actual network request")
        
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.timeoutInterval = 15.0
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("gzip", forHTTPHeaderField: "Accept-Encoding")
            
            // Intelligent caching
            if let lastRequest = await requestQueue.run({ self.lastRequestTimes[station.macAddress] }),
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
            
            logNetwork(" [Station: \(station.name)] Response: \(data.count) bytes in \(String(format: "%.2f", requestDuration))s")
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 429 {
                    logWarning(" Rate limited, reducing concurrent requests")
                    maxConcurrentRequests = max(1, maxConcurrentRequests - 1)
                    await MainActor.run {
                        errorMessage = "API rate limited, reducing request speed"
                    }
                    return nil
                } else if httpResponse.statusCode != 200 {
                    await MainActor.run {
                        errorMessage = "HTTP \(httpResponse.statusCode) for \(station.name)"
                    }
                    return nil
                }
            }
            
            // Parse response
            if let weatherResponse = parseWeatherResponseSafely(from: data, for: station) {
                if weatherResponse.code == 0 {
                    // Increase concurrent requests if successful
                    if maxConcurrentRequests < 6 {
                        maxConcurrentRequests += 1
                    }
                }
                return weatherResponse
            }
            
        } catch let networkError {
            await MainActor.run {
                let detailedError = "Network Error for \(station.name): \(networkError.localizedDescription)"
                logNetwork(" [Station: \(station.name)] \(detailedError)")
                errorMessage = detailedError
            }
        }
        
        return nil
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
        logDebug(" === TIMESTAMP PARSING TEST ===")
        let (parsed, analysis) = TimestampExtractor.testTimestampParsing(timestamp)
        print(analysis)
        
        if let parsedDate = parsed {
            // Test with a sample station
            if let station = weatherStations.first {
                let formatted = TimestampExtractor.formatTimestamp(parsedDate, for: station, style: .medium)
                logDebug("Formatted for station \(station.name): \(formatted)")
                logDebug("Station timezone: \(station.timeZone.identifier)")
            }
        }
        logDebug(" === END TEST ===")
    }
    
    func setDataFreshnessDuration(_ duration: TimeInterval) {
        dataFreshnessDuration = duration
        logDebug(" Data freshness duration set to \(Int(duration)) seconds")
    }
    
    // MARK: - Background Refresh Management
    
    func refreshStaleData() async {
        let staleStations = weatherStations.filter { station in
            station.isActive && !isDataFresh(for: station)
        }
        
        if staleStations.isEmpty {
            logRefresh(" No stale data to refresh")
            return
        }
        
        logRefresh(" Refreshing \(staleStations.count) stations with stale data")
        
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
    
    // Helper method to check if we have today's historical data
    private func hasTodaysHistoricalData(for station: WeatherStation) -> Bool {
        guard let historical = historicalData[station.macAddress],
              let outdoor = historical.outdoor,
              let temperature = outdoor.temperature else {
            return false
        }
        
        // Check if we have any temperature data from today
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Track the most recent timestamp to check staleness
        var mostRecentTimestamp: Double = 0
        var hasDataFromToday = false
        
        for (timestampString, _) in temperature.list {
            if let timestamp = Double(timestampString) {
                let readingDate = Date(timeIntervalSince1970: timestamp)
                if calendar.isDate(readingDate, inSameDayAs: today) {
                    hasDataFromToday = true
                    mostRecentTimestamp = max(mostRecentTimestamp, timestamp)
                }
            }
        }
        
        // If we have no data from today, return false
        guard hasDataFromToday else {
            return false
        }
        
        // Check if the most recent data is stale (older than 10 minutes)
        let mostRecentDate = Date(timeIntervalSince1970: mostRecentTimestamp)
        let ageInMinutes = Date().timeIntervalSince(mostRecentDate) / 60
        
        // Consider data stale if it's older than 10 minutes
        let isStale = ageInMinutes > 10
        
        if isStale {
            logData(" Historical data for \(station.name) is stale (age: \(Int(ageInMinutes)) minutes)")
        }
        
        // Return false if data is stale, forcing a refresh
        return !isStale
    }
    
    private func hasRecentLightningHistoricalData(for station: WeatherStation, daysBack: Int = 7) -> Bool {
        guard let historical = historicalData[station.macAddress],
              let lightning = historical.lightning,
              let lightningCount = lightning.count else {
            return false
        }
        
        let calendar = Calendar.current
        let cutoffDate = calendar.date(byAdding: .day, value: -daysBack, to: Date()) ?? Date()
        
        // Check if we have lightning data from the last 7 days
        for (timestampString, _) in lightningCount.list {
            if let timestamp = Double(timestampString) {
                let readingDate = Date(timeIntervalSince1970: timestamp)
                if readingDate >= cutoffDate {
                    return true
                }
            }
        }
        
        return false
    }
    
    // Fetch today's historical data for high/low temperature calculations
    private func fetchTodaysHistoricalData(for station: WeatherStation) async {
        logData(" Fetching today's historical data (from 00:00) for \(station.name)...")
        
        // First fetch extended lightning data (30 days) and store it
        logData(" Fetching extended lightning historical data for \(station.name)...")
        await fetchExtendedLightningData(for: station)
        
        // Store the lightning data before it gets overwritten
        let lightningData = historicalData[station.macAddress]?.lightning
        
        // UPDATED: Use today from 00:00 with 5-minute resolution for accurate daily high/low
        // This provides precise timing and covers the actual calendar day
        await fetchHistoricalData(
            for: station,
            timeRange: .todayFrom00, // NEW: From midnight today with 5-minute resolution
            sensors: ["outdoor", "indoor", "temp_and_humidity_ch1", "temp_and_humidity_ch2", "temp_and_humidity_ch3", "rainfall", "rainfall_piezo", "wind", "pressure", "pm25_ch1", "pm25_ch2", "pm25_ch3"] 
        )
        
        // Restore the extended lightning data after the regular fetch
        if let existingData = historicalData[station.macAddress], let savedLightningData = lightningData {
            let mergedData = HistoricalWeatherData(
                outdoor: existingData.outdoor,
                indoor: existingData.indoor,
                solarAndUvi: existingData.solarAndUvi,
                rainfall: existingData.rainfall,
                rainfallPiezo: existingData.rainfallPiezo,
                wind: existingData.wind,
                pressure: existingData.pressure,
                lightning: savedLightningData, // Use the 7-day high-resolution lightning data
                pm25Ch1: existingData.pm25Ch1,
                pm25Ch2: existingData.pm25Ch2,
                pm25Ch3: existingData.pm25Ch3,
                tempAndHumidityCh1: existingData.tempAndHumidityCh1,
                tempAndHumidityCh2: existingData.tempAndHumidityCh2,
                tempAndHumidityCh3: existingData.tempAndHumidityCh3
            )
            historicalData[station.macAddress] = mergedData
            logLightning(" Lightning data preserved: \(savedLightningData.count?.list.count ?? 0) readings")
        }
        
        // DEBUG: Check final lightning data
        if let lightningData = historicalData[station.macAddress]?.lightning?.count {
            logDebug(" Final lightning data: \(lightningData.list.count) readings")
            
            // Show sample of recent data
            let recent = lightningData.list.prefix(5)
            for (timestamp, count) in recent {
                if let ts = Double(timestamp) {
                    let date = Date(timeIntervalSince1970: ts)
                    logDebug("   - \(date): \(count)")
                }
            }
        } else {
            logDebug(" No lightning data in final result")
        }
        
        logData(" Completed today's 5-minute resolution historical data fetch from 00:00 for: \(station.name)")
    }
    
    private func fetchExtendedLightningData(for station: WeatherStation) async {
        guard credentials.isValid else {
            return
        }

        // Use 30 days with 4hour cycle for better lightning data retention and coverage
        let timeRange = HistoricalTimeRange.last30Days
        let sensors = ["lightning"]
        
        let calendar = Calendar.current
        let now = Date()
        let endDate = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: now) ?? now
        let startDate = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now)) ?? now

        // Format dates exactly as API example: 2022-01-01 00:00:00
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        dateFormatter.timeZone = TimeZone.current
        
        let startDateString = dateFormatter.string(from: startDate)
        let endDateString = dateFormatter.string(from: endDate)
        let callBack = sensors.joined(separator: ",")
        
        // Build historical data URL
        let urlString = "\(historyURL)?application_key=\(credentials.applicationKey)&api_key=\(credentials.apiKey)&mac=\(station.macAddress)&start_date=\(startDateString)&end_date=\(endDateString)&cycle_type=\(timeRange.cycleType)&call_back=\(callBack)"
        
        guard let url = URL(string: urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "") else {
            return
        }
        
        logLightning(" [Extended Lightning: \(station.name)] Requesting \(timeRange.rawValue)")
        logData(" Date range: \(startDateString) to \(endDateString)")
        logData(" Cycle type: \(timeRange.cycleType)")
        logDebug(" URL: \(url.absoluteString)")
        
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 60.0
            request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 429 {
                    logWarning(" Rate limited, reducing concurrent requests")
                    maxConcurrentRequests = max(1, maxConcurrentRequests - 1)
                    await MainActor.run {
                        errorMessage = "API rate limited, reducing request speed"
                    }
                    return
                } else if httpResponse.statusCode != 200 {
                    await MainActor.run {
                        errorMessage = "HTTP \(httpResponse.statusCode)"
                    }
                    return
                }
            }
            
            // Parse response
            let decoder = JSONDecoder()
            let historicalResponse = try decoder.decode(HistoricalWeatherResponse.self, from: data)
            
            await MainActor.run {
                if historicalResponse.code == 0 {
                    // Merge lightning data into existing historical data instead of replacing it
                    if let existingData = historicalData[station.macAddress] {
                        // Create new HistoricalWeatherData with updated lightning data
                        let mergedData = HistoricalWeatherData(
                            outdoor: existingData.outdoor,
                            indoor: existingData.indoor,
                            solarAndUvi: existingData.solarAndUvi,
                            rainfall: existingData.rainfall,
                            rainfallPiezo: existingData.rainfallPiezo,
                            wind: existingData.wind,
                            pressure: existingData.pressure,
                            lightning: historicalResponse.data.lightning,
                            pm25Ch1: existingData.pm25Ch1,
                            pm25Ch2: existingData.pm25Ch2,
                            pm25Ch3: existingData.pm25Ch3,
                            tempAndHumidityCh1: existingData.tempAndHumidityCh1,
                            tempAndHumidityCh2: existingData.tempAndHumidityCh2,
                            tempAndHumidityCh3: existingData.tempAndHumidityCh3
                        )
                        historicalData[station.macAddress] = mergedData
                        logSuccess(" Successfully merged 7-day high-resolution lightning data")
                    } else {
                        // If no existing data, just store the lightning data
                        historicalData[station.macAddress] = historicalResponse.data
                        logSuccess(" Successfully stored 7-day high-resolution lightning data")
                    }
                }
            }
            
        } catch {
            logLightning(" [Extended Lightning: \(station.name)] Error: \(error.localizedDescription)")
        }
    }
    
    func fetchHistoricalData(for station: WeatherStation, timeRange: HistoricalTimeRange, sensors: [String] = ["outdoor", "indoor", "temp_and_humidity_ch1", "temp_and_humidity_ch2", "temp_and_humidity_ch3", "rainfall", "rainfall_piezo", "wind", "pressure", "pm25_ch1", "pm25_ch2", "pm25_ch3"]) async {
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
                logDebug("  Note: Requesting \(timeRange.rawValue) of data. API limitations:")
                logDebug("   • Daily data: Only 3 months available")
                logDebug("   • Weekly data: Up to 1 year available")
                logDebug("   • Using \(timeRange.cycleType) cycle for this request")
            }
        }

        // Use proper calendar day boundaries for daily data ranges
        let calendar = Calendar.current
        let now = Date()
        let startDate: Date
        let endDate: Date
        
        switch timeRange {
        case .lastHour:
            // Precise 1-hour window using 5min resolution (within API limits)
            let now = Date()
            endDate = now
            startDate = now.addingTimeInterval(-3600) // Exactly 1 hour ago
            
            let actualDuration = endDate.timeIntervalSince(startDate) / 3600
            logDebug(" 1-Hour range (5min resolution): \(startDate) to \(endDate)")
            logDebug(" Duration: \(String(format: "%.3f", actualDuration)) hours (well under 24hr limit)")
            logDebug(" Expected data points: ~12 (every 5 minutes for 1 hour)")
        case .last6Hours:
            // Last 6 hours from current time  
            endDate = now
            startDate = now.addingTimeInterval(-6 * 3600) // Exactly 6 hours ago
            logDebug(" 6-Hour range: \(startDate) to \(endDate) (duration: \(endDate.timeIntervalSince(startDate)/3600) hours)")
            
        case .last24Hours:
            // Last 24 hours from current time
            endDate = now
            startDate = now.addingTimeInterval(-24 * 3600) // Exactly 24 hours ago
            logDebug(" 24-Hour range: \(startDate) to \(endDate) (duration: \(endDate.timeIntervalSince(startDate)/3600) hours)")
            
        case .todayFrom00:
            // NEW: From midnight (00:00:00) of current day to now
            // This gives us the actual daily high/low for today's calendar day
            startDate = calendar.startOfDay(for: now)
            endDate = now
            logDebug(" Today from 00:00 range: \(startDate) to \(endDate)")
            
        case .last7Days:
            // Last 7 full calendar days
            endDate = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: now) ?? now
            startDate = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now)) ?? now
            
        case .last30Days:
            // Last 30 full calendar days
            endDate = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: now) ?? now
            startDate = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now)) ?? now
            
        case .last90Days:
            // Last 90 full calendar days (limited to API retention)
            endDate = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: now) ?? now
            startDate = calendar.date(byAdding: .day, value: -89, to: calendar.startOfDay(for: now)) ?? now
            
        case .last365Days:
            // Last 365 full calendar days
            endDate = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: now) ?? now
            startDate = calendar.date(byAdding: .day, value: -364, to: calendar.startOfDay(for: now)) ?? now
        }
        
        // For longer periods, we need to adjust the start date based on API retention limits
        let adjustedStartDate: Date
        switch timeRange {
        case .last90Days:
            // Limit to 90 days for daily data (API only retains ~3 months)
            let maxRetentionDate = endDate.addingTimeInterval(-90 * 24 * 3600)
            adjustedStartDate = max(startDate, maxRetentionDate)
        case .last365Days:
            // Use weekly data which has 1 year retention - no additional limiting needed
            adjustedStartDate = startDate
        case .todayFrom00:
            adjustedStartDate = calendar.startOfDay(for: Date())
        default:
            adjustedStartDate = startDate
        }

        // FIXED: Format dates with station's local timezone instead of UTC
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        // Use the station's timezone instead of UTC to avoid confusion
        dateFormatter.timeZone = station.timeZone
        
        // Use station's local time for API request
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
        
        logData(" [Historical: \(station.name)] Requesting \(timeRange.rawValue)")
        logData(" Date range: \(startDateString) to \(endDateString)")
        logData(" Cycle type: \(timeRange.cycleType)")
        logDebug(" URL: \(url.absoluteString)")
        
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 60.0 // Longer timeout for historical data
            request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            
            let (data, response) = try await session.data(for: request)
            
            logData(" [Historical: \(station.name)] Response received: \(data.count) bytes")
            
            if let httpResponse = response as? HTTPURLResponse {
                logData(" [Historical: \(station.name)] HTTP Status: \(httpResponse.statusCode)")
                
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
                    // FIXED: Store chart data separately from weather card daily stats data
                    // Chart data goes to chartHistoricalData (for user-requested time ranges)
                    chartHistoricalData[station.macAddress] = historicalResponse.data
                    
                    // Only update main historicalData for daily stats if this is the daily range
                    // This preserves weather card daily stats while allowing chart flexibility
                    if timeRange == .todayFrom00 {
                        // This is daily data - merge it properly for weather cards
                        if let existingData = historicalData[station.macAddress] {
                            let mergedData = mergeHistoricalDataPreservingDaily(
                                existing: existingData, 
                                new: historicalResponse.data, 
                                newTimeRange: timeRange
                            )
                            historicalData[station.macAddress] = mergedData
                        } else {
                            historicalData[station.macAddress] = historicalResponse.data
                        }
                    }
                    
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
                logError(" Historical data error: \(error)")
            }
        }
    }
    
    private func mergeHistoricalDataPreservingDaily(existing: HistoricalWeatherData, new: HistoricalWeatherData, newTimeRange: HistoricalTimeRange) -> HistoricalWeatherData {
        // For short time ranges (1-hour, 6-hour), we want to preserve existing daily data
        // but update with the new data for chart display
        // For longer time ranges, we replace with the comprehensive new data
        
        let shouldPreserveDailyData = (newTimeRange == .lastHour || newTimeRange == .last6Hours)
        
        return HistoricalWeatherData(
            outdoor: mergeOutdoorData(existing: existing.outdoor, new: new.outdoor, preserveExisting: shouldPreserveDailyData),
            indoor: mergeIndoorData(existing: existing.indoor, new: new.indoor, preserveExisting: shouldPreserveDailyData),
            solarAndUvi: shouldPreserveDailyData ? (existing.solarAndUvi ?? new.solarAndUvi) : (new.solarAndUvi ?? existing.solarAndUvi),
            rainfall: shouldPreserveDailyData ? (existing.rainfall ?? new.rainfall) : (new.rainfall ?? existing.rainfall),
            rainfallPiezo: shouldPreserveDailyData ? (existing.rainfallPiezo ?? new.rainfallPiezo) : (new.rainfallPiezo ?? existing.rainfallPiezo),
            wind: shouldPreserveDailyData ? (existing.wind ?? new.wind) : (new.wind ?? existing.wind),
            pressure: shouldPreserveDailyData ? (existing.pressure ?? new.pressure) : (new.pressure ?? existing.pressure),
            lightning: existing.lightning, // Always preserve lightning data (it's special long-term data)
            pm25Ch1: shouldPreserveDailyData ? (existing.pm25Ch1 ?? new.pm25Ch1) : (new.pm25Ch1 ?? existing.pm25Ch1),
            pm25Ch2: shouldPreserveDailyData ? (existing.pm25Ch2 ?? new.pm25Ch2) : (new.pm25Ch2 ?? existing.pm25Ch2),
            pm25Ch3: shouldPreserveDailyData ? (existing.pm25Ch3 ?? new.pm25Ch3) : (new.pm25Ch3 ?? existing.pm25Ch3),
            tempAndHumidityCh1: mergeTempHumidityData(existing: existing.tempAndHumidityCh1, new: new.tempAndHumidityCh1, preserveExisting: shouldPreserveDailyData),
            tempAndHumidityCh2: mergeTempHumidityData(existing: existing.tempAndHumidityCh2, new: new.tempAndHumidityCh2, preserveExisting: shouldPreserveDailyData),
            tempAndHumidityCh3: mergeTempHumidityData(existing: existing.tempAndHumidityCh3, new: new.tempAndHumidityCh3, preserveExisting: shouldPreserveDailyData)
        )
    }
    
    private func mergeOutdoorData(existing: HistoricalOutdoorData?, new: HistoricalOutdoorData?, preserveExisting: Bool) -> HistoricalOutdoorData? {
        guard let existing = existing else { return new }
        guard let new = new else { return existing }
        
        if preserveExisting {
            // For short time ranges, preserve existing comprehensive data but merge in new data
            return HistoricalOutdoorData(
                temperature: mergeTemperatureData(existing: existing.temperature, new: new.temperature, preserveExisting: true),
                feelsLike: existing.feelsLike ?? new.feelsLike,
                appTemp: existing.appTemp ?? new.appTemp,
                dewPoint: existing.dewPoint ?? new.dewPoint,
                humidity: mergeHumidityData(existing: existing.humidity, new: new.humidity, preserveExisting: true)
            )
        } else {
            // For longer time ranges, prefer new comprehensive data
            return HistoricalOutdoorData(
                temperature: mergeTemperatureData(existing: existing.temperature, new: new.temperature, preserveExisting: false),
                feelsLike: new.feelsLike ?? existing.feelsLike,
                appTemp: new.appTemp ?? existing.appTemp,
                dewPoint: new.dewPoint ?? existing.dewPoint,
                humidity: mergeHumidityData(existing: existing.humidity, new: new.humidity, preserveExisting: false)
            )
        }
    }
    
    private func mergeIndoorData(existing: HistoricalIndoorData?, new: HistoricalIndoorData?, preserveExisting: Bool) -> HistoricalIndoorData? {
        guard let existing = existing else { return new }
        guard let new = new else { return existing }
        
        if preserveExisting {
            return HistoricalIndoorData(
                temperature: mergeTemperatureData(existing: existing.temperature, new: new.temperature, preserveExisting: true),
                humidity: mergeHumidityData(existing: existing.humidity, new: new.humidity, preserveExisting: true),
                dewPoint: existing.dewPoint ?? new.dewPoint,
                feelsLike: existing.feelsLike ?? new.feelsLike
            )
        } else {
            return HistoricalIndoorData(
                temperature: mergeTemperatureData(existing: existing.temperature, new: new.temperature, preserveExisting: false),
                humidity: mergeHumidityData(existing: existing.humidity, new: new.humidity, preserveExisting: false),
                dewPoint: new.dewPoint ?? existing.dewPoint,
                feelsLike: new.feelsLike ?? existing.feelsLike
            )
        }
    }
    
    private func mergeTempHumidityData(existing: HistoricalTempHumidityData?, new: HistoricalTempHumidityData?, preserveExisting: Bool) -> HistoricalTempHumidityData? {
        guard let existing = existing else { return new }
        guard let new = new else { return existing }
        
        return HistoricalTempHumidityData(
            temperature: mergeTemperatureData(existing: existing.temperature, new: new.temperature, preserveExisting: preserveExisting),
            humidity: mergeHumidityData(existing: existing.humidity, new: new.humidity, preserveExisting: preserveExisting)
        )
    }
    
    private func mergeTemperatureData(existing: HistoricalMeasurement?, new: HistoricalMeasurement?, preserveExisting: Bool) -> HistoricalMeasurement? {
        guard let existing = existing else { return new }
        guard let new = new else { return existing }
        
        if preserveExisting {
            logDebug("   Temperature data merge: preserving existing \(existing.list.count) points, adding new \(new.list.count) points")
            
            // Merge the data: combine existing comprehensive data with new specific time range data
            var mergedList = existing.list
            for (timestamp, value) in new.list {
                mergedList[timestamp] = value  // New data overwrites existing for same timestamps
            }
            
            return HistoricalMeasurement(unit: existing.unit, list: mergedList)
        } else {
            logDebug("   Temperature data merge: using new data (\(new.list.count) points) for chart display")
            return new
        }
    }
    
    private func mergeHumidityData(existing: HistoricalMeasurement?, new: HistoricalMeasurement?, preserveExisting: Bool) -> HistoricalMeasurement? {
        guard let existing = existing else { return new }
        guard let new = new else { return existing }
        
        if preserveExisting {
            logDebug("   Humidity data merge: preserving existing \(existing.list.count) points, adding new \(new.list.count) points")
            
            // Merge the data: combine existing comprehensive data with new specific time range data
            var mergedList = existing.list
            for (timestamp, value) in new.list {
                mergedList[timestamp] = value  // New data overwrites existing for same timestamps
            }
            
            return HistoricalMeasurement(unit: existing.unit, list: mergedList)
        } else {
            logDebug("   Humidity data merge: using new data (\(new.list.count) points) for chart display")
            return new
        }
    }
    
    /// Helper function to convert historical measurement to chart data points
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
    
    /// Get chart data from the separate chart historical data
    func getChartHistoricalData(for station: WeatherStation) -> HistoricalWeatherData? {
        return chartHistoricalData[station.macAddress]
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
        
        logNetwork(" Discovering weather stations...")
        logDebug(" URL: \(url.absoluteString)")
        
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 30.0
            request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            
            let (data, response) = try await session.data(for: request)
            
            logNetwork(" Device list response received: \(data.count) bytes")
            
            if let httpResponse = response as? HTTPURLResponse {
                logNetwork(" HTTP Status: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode != 200 {
                    await MainActor.run {
                        isDiscoveringStations = false
                    }
                    return (false, "HTTP \(httpResponse.statusCode)")
                }
            }
            
            // Let's see the raw response first
            let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response"
            logDebug(" Raw device list response:")
            logDebug("--- START RESPONSE ---")
            print(responseString)
            logDebug("--- END RESPONSE ---")
            
            // Try to parse as basic JSON first to see the structure
            do {
                if let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    logNetwork(" Device list JSON structure:")
                    logDebug(" Root keys: \(Array(jsonObject.keys))")
                    
                    if let code = jsonObject["code"] as? Int {
                        logDebug(" API code: \(code)")
                        
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
                        logDebug(" Data field is an array with \(dataField.count) items")
                        
                        // Log the first device structure if available
                        if let firstDevice = dataField.first as? [String: Any] {
                            logDebug(" First device keys: \(Array(firstDevice.keys))")
                        }
                    } else {
                        logDebug(" Data field structure: \(type(of: jsonObject["data"]))")
                        logDebug(" Data field value: \(jsonObject["data"] ?? "nil")")
                    }
                } else {
                    await MainActor.run {
                        isDiscoveringStations = false
                    }
                    return (false, "Invalid JSON response structure")
                }
                
                // Now try our strict model parsing
                logDebug(" Attempting to parse with DeviceListResponse model...")
                
                let decoder = JSONDecoder()
                let deviceListResponse = try decoder.decode(DeviceListResponse.self, from: data)
                
                await MainActor.run {
                    isDiscoveringStations = false
                    
                    if deviceListResponse.code == 0 {
                        discoveredStations = deviceListResponse.data.list
                        logSuccess(" Successfully discovered \(discoveredStations.count) weather stations")

                        
                        // Log discovered stations
                        for device in discoveredStations {
                            logInfo(" Found device: \(device.name) (\(device.mac))")
                            logDebug("   Device Type: \(device.type) (\(self.deviceTypeDescription(device.type)))")
                            if let stationType = device.stationtype {
                                logDebug("   Station Type: \(stationType)")
                            }
                            if let createtime = device.createtime {
                                let date = Date(timeIntervalSince1970: TimeInterval(createtime))
                                logDebug("   Created: \(date)")
                            }
                            if let longitude = device.longitude, let latitude = device.latitude {
                                logDebug("   Location: \(latitude), \(longitude)")
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
                logError(" JSON parsing failed: \(jsonError)")
                
                await MainActor.run {
                    isDiscoveringStations = false
                }
                
                return (false, "Discovery failed: Unable to parse API response. Check console for details.")
            }
            
        } catch {
            await MainActor.run {
                isDiscoveringStations = false
            }
            logDebug(" Device discovery error: \(error)")
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
            logSuccess(" Updated existing station with discovery data: \(updatedStation.name) (\(updatedStation.macAddress))")
        } else {
            weatherStations.append(newStation)
            saveWeatherStations()
            logSuccess(" Added new station: \(newStation.name) (\(newStation.macAddress))")
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
            logSuccess(" Added \(addedCount) new weather station\(addedCount == 1 ? "" : "s")")
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
    
    
    func updateStationCardOrder(_ station: WeatherStation, newOrder: [CardType]) {
        if let index = weatherStations.firstIndex(where: { $0.id == station.id }) {
            objectWillChange.send()
            weatherStations[index].cardOrder = newOrder
            saveWeatherStations()
            logSuccess(" Updated card order for: \(station.name)")
            logDebug("   New order: \(newOrder.map { $0.displayName })")
        }
    }
    func updateStation(_ station: WeatherStation) {
        updateWeatherStation(station)
    }
    
    func updateWeatherStation(_ station: WeatherStation) {
        if let index = weatherStations.firstIndex(where: { $0.id == station.id }) {
            // Trigger objectWillChange BEFORE updating to ensure UI refresh
            objectWillChange.send()
            weatherStations[index] = station
            saveWeatherStations()
            logSuccess(" Updated station: \(station.name)")
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
                
                logSuccess(" Updated \(station.name) timestamp (from all sensors):")
                logDebug("   Old: \(oldTimestamp?.description ?? "never")")
                logDebug("   New: \(mostRecentTimestamp.description)")
                logDebug("   Station timezone: \(station.timeZone.identifier)")
                logDebug("   Data age: \(TimestampExtractor.formatDataAge(from: mostRecentTimestamp))")
                
                // Warn if timestamp seems problematic
                let currentTime = Date()
                let timeDifference = abs(currentTime.timeIntervalSince(mostRecentTimestamp))
                if timeDifference > 86400 { // More than 1 day difference
                    logWarning(" Weather data timestamp is \(Int(timeDifference/3600)) hours off from current time")
                }
            } else {
                logWarning(" Could not find station \(station.name) to update timestamp")
            }
            return
        }
        
        // Fallback to original method using outdoor temperature timestamp if TimestampExtractor fails
        logDebug(" TimestampExtractor failed, falling back to outdoor temperature timestamp")
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
                logWarning(" Could not parse timestamp '\(timestampString)' for \(station.name), using current time")
                actualDataTime = Date()
            }
        }
        
        if let index = weatherStations.firstIndex(where: { $0.id == station.id }) {
            let oldTimestamp = weatherStations[index].lastUpdated
            weatherStations[index].lastUpdated = actualDataTime
            saveWeatherStations()
            
            logSuccess(" Updated \(station.name) timestamp (fallback method):")
            logDebug("   Old: \(oldTimestamp?.description ?? "never")")
            logDebug("   New: \(actualDataTime.description) (from weather data)")
            logDebug("   Raw timestamp: \(timestampString)")
        } else {
            logWarning(" Could not find station \(station.name) to update timestamp")
        }
    }
    
    func updateCredentials(applicationKey: String, apiKey: String) {
        let newCredentials = APICredentials(applicationKey: applicationKey, apiKey: apiKey)
        credentials = newCredentials
        
        // Use iCloud sync service to save credentials
        APICredentialsSync.shared.saveCredentials(newCredentials)
    }
    
    // MARK: - Persistence
    
    private func saveCredentials() {
        // Use iCloud sync service to save credentials
        APICredentialsSync.shared.saveCredentials(credentials)
    }
    
    private func loadCredentials() {
        // Load credentials from iCloud sync service
        credentials = APICredentialsSync.shared.loadCredentials()
    }
    
    /// Setup observer to handle credential changes from iCloud
    private func setupCredentialChangeObserver() {
        NotificationCenter.default.addObserver(
            forName: .apiCredentialsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let userInfo = notification.userInfo,
                  let newCredentials = userInfo["credentials"] as? APICredentials else {
                return
            }
            
            // Update local credentials when changed from another device
            self.credentials = newCredentials
            self.logSync("✅ Credentials updated from iCloud")
        }
    }
    
    // MARK: - Sync Logging
    
    private func logSync(_ message: String) {
        #if DEBUG
        print("[WeatherStationService] \(message)")
        #endif
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
            
            // Post notification that stations were loaded
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .weatherStationsUpdated, object: nil)
            }
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
        
        logData(" Fetching station info for \(station.name)...")
        logDebug(" URL: \(url.absoluteString)")
        
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 30.0
            request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                logData(" Station info HTTP Status: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode != 200 {
                    return (false, "HTTP \(httpResponse.statusCode)")
                }
            }
            
            // Parse the response
            if let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let code = jsonObject["code"] as? Int {
                
                logDebug(" Device info JSON response: \(jsonObject)")
                
                if code == 0,
                   let dataField = jsonObject["data"] as? [String: Any] {
                    
                    // Extract station info
                    let latitude = dataField["latitude"] as? Double
                    let longitude = dataField["longitude"] as? Double
                    let timeZoneId = dataField["date_zone_id"] as? String
                    let stationType = dataField["stationtype"] as? String
                    let createtime = dataField["createtime"] as? Int
                    
                    // Look for camera-related fields
                    logDebug(" Checking for camera fields in device info...")
                    for (key, value) in dataField {
                        if key.lowercased().contains("camera") || 
                           key.lowercased().contains("image") || 
                           key.lowercased().contains("photo") || 
                           key.lowercased().contains("picture") {
                            logDebug(" Found potential camera field: \(key) = \(value)")
                        }
                    }
                    
                    // Update the station with the new info
                    await MainActor.run {
                        if let index = weatherStations.firstIndex(where: { $0.id == station.id }) {
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
                            
                            logSuccess(" Updated station info for \(station.name):")
                            if let tzId = timeZoneId {
                                logDebug("   Timezone: \(tzId)")
                            }
                            if let lat = latitude, let lon = longitude {
                                logDebug("   Location: \(lat), \(lon)")
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
            logData(" Station info fetch error: \(error)")
            return (false, "Failed to fetch station info: \(error.localizedDescription)")
        }
    }
    
    func fetchCameraImage(for station: WeatherStation) async -> (imageURL: String?, photoTime: Date?, updatedTime: Date?)? {
        guard credentials.isValid else {
            logError(" Credentials invalid for camera image fetch")
            return nil
        }
        
        // Only proceed if station has an associated camera
        guard let cameraMAC = station.associatedCameraMAC else {
            logDebug(" No associated camera for station: \(station.name)")
            return nil
        }
        
        logDebug(" Starting camera image search for station: \(station.name)")
        logDebug(" Using associated camera MAC: \(cameraMAC)")
        
        // Construct the camera endpoint URL carefully
        let baseURL = "https://cdnapi.ecowitt.net/api/v3/device/real_time"
        let applicationKey = credentials.applicationKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let apiKey = credentials.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let url = URL(string: "\(baseURL)?application_key=\(applicationKey)&api_key=\(apiKey)&mac=\(cameraMAC)&call_back=camera") else {
            logDebug(" Invalid camera URL construction")
            return nil
        }
        
        logCamera(" Camera endpoint URL: \(url.absoluteString)")
        
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 30.0
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                logCamera(" Camera HTTP Status: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 200 {
                    logDebug(" Response size: \(data.count) bytes")
                    
                    // Log the raw response for debugging
                    if let responseString = String(data: data, encoding: .utf8) {
                        logCamera(" Camera raw response: \(responseString)")
                    }
                    
                    // Check if data field is an empty array (no camera data available)
                    if let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let dataField = jsonObject["data"] as? [Any],
                       dataField.isEmpty {
                        logCamera(" Camera API returned empty data array - no camera data available for this device")
                        return nil
                    }
                    
                    // Try to parse as camera response
                    do {
                        let decoder = JSONDecoder()
                        let cameraResponse = try decoder.decode(CameraResponse.self, from: data)
                        
                        if cameraResponse.code == 0 {
                            let imageUrl = cameraResponse.data.camera.photo.url
                            let imageTimeString = cameraResponse.data.camera.photo.time
                            
                            // Parse the photo timestamp
                            let photoTime: Date?
                            if let timestamp = Double(imageTimeString) {
                                photoTime = Date(timeIntervalSince1970: timestamp)
                            } else {
                                photoTime = nil
                            }
                            
                            // Updated time is now (when we fetched the data)
                            let updatedTime = Date()
                            
                            logDebug(" Found camera image URL: \(imageUrl)")
                            logDebug(" Photo timestamp: \(imageTimeString)")
                            if let photoTime = photoTime {
                                logDebug(" Parsed photo time: \(photoTime)")
                            }
                            
                            return (imageURL: imageUrl, photoTime: photoTime, updatedTime: updatedTime)
                        } else {
                            logCamera(" Camera API error: \(cameraResponse.msg) (Code: \(cameraResponse.code))")
                        }
                    } catch {
                        logDebug(" Failed to parse camera response: \(error)")
                        logDebug(" This likely means the device is not a camera or has no camera data available")
                        
                        return nil
                    }
                } else {
                    logDebug(" HTTP Error: \(httpResponse.statusCode)")
                    
                    // Log error response body
                    if let responseString = String(data: data, encoding: .utf8) {
                        logDebug(" Error response: \(responseString)")
                    }
                }
            }
            
        } catch {
            logCamera(" Camera request error: \(error.localizedDescription)")
        }
        
        logDebug(" No camera image URL found for station: \(station.name)")
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
        logDebug(" Starting automatic camera-station association...")
        logDebug(" Distance threshold: \(distanceThresholdKm) km")
        
        // Get all camera devices (type 2)
        let cameraDevices = discoveredStations.filter { $0.type == 2 }
        
        // Get all weather station devices (any type, or specifically type 1)
        let stationDevices = weatherStations.filter { station in
            // Accept stations without device type or with device type 1
            station.deviceType == nil || station.deviceType == 1
        }
        
        logDebug(" Found \(cameraDevices.count) camera devices")
        logDebug(" Found \(stationDevices.count) weather stations")
        
        // Debug: show all stations
        for station in weatherStations {
            logData(" Station: \(station.name), deviceType: \(station.deviceType?.description ?? "nil"), location: \(station.latitude?.description ?? "nil"), \(station.longitude?.description ?? "nil")")
        }
        
        for camera in cameraDevices {
            guard let cameraLat = camera.latitude, let cameraLon = camera.longitude else {
                logCamera(" Camera \(camera.name) has no location data, skipping")
                continue
            }
            
            logDebug(" Processing camera: \(camera.name) at (\(cameraLat), \(cameraLon))")
            
            var associatedStations: [WeatherStation] = []
            
            // Find ALL stations within the threshold distance
            for station in stationDevices {
                guard let stationLat = station.latitude, let stationLon = station.longitude else {
                    logData(" Station \(station.name) has no location data, skipping")
                    continue
                }
                
                let distance = calculateDistance(
                    lat1: cameraLat, lon1: cameraLon,
                    lat2: stationLat, lon2: stationLon
                )
                
                logDebug(" Distance to \(station.name): \(String(format: "%.3f", distance)) km")
                
                if distance <= distanceThresholdKm {
                    associatedStations.append(station)
                    logData(" Station \(station.name) is within threshold (\(String(format: "%.3f", distance)) km)")
                }
            }
            
            // Associate camera with all nearby stations
            if !associatedStations.isEmpty {
                for station in associatedStations {
                    if let index = weatherStations.firstIndex(where: { $0.id == station.id }) {
                        weatherStations[index].associatedCameraMAC = camera.mac
                        logDebug(" Associated camera \(camera.name) with station \(station.name)")
                    }
                }
                saveWeatherStations()
                logCamera(" Camera \(camera.name) associated with \(associatedStations.count) station(s)")
            } else {
                logDebug(" No weather stations found within \(distanceThresholdKm) km for camera \(camera.name)")
            }
        }
        
        logCamera(" Camera-station association complete")
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
            logDebug(" Standard parsing failed for \(station.name): \(error)")
        }
        
        // If standard parsing fails, try to parse as generic JSON and extract what we can
        do {
            if let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let code = jsonObject["code"] as? Int,
               let msg = jsonObject["msg"] as? String {
                
                logNetwork(" [Station: \(station.name)] API Response - Code: \(code), Message: \(msg)")
                
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
            logDebug(" Even generic JSON parsing failed for \(station.name): \(error)")
        }
        
        return nil
    }
    
    private func extractWeatherDataSafely(from dataDict: [String: Any], for station: WeatherStation) -> WeatherStationData {
        logNetwork(" [Station: \(station.name)] Attempting safe data extraction from available fields")
        
        // Create empty data structure and fill what we can
        let extractedData = WeatherStationData.empty()
        
        // Extract outdoor data if available
        if dataDict["outdoor"] != nil {
            logNetwork(" [Station: \(station.name)] Found outdoor data")
            // Try to extract basic outdoor measurements
            // This would need implementation based on your WeatherStationData model
        }
        
        // Extract indoor data if available
        if dataDict["indoor"] != nil {
            logNetwork(" [Station: \(station.name)] Found indoor data")
            // Try to extract basic indoor measurements
        }
        
        // Extract other sensor data
        for (key, value) in dataDict {
            logNetwork(" [Station: \(station.name)] Available data field: \(key) (\(type(of: value)))")
        }
        
        return extractedData
    }
    
    /// Clean up stale shared requests (call periodically)
    private func cleanupStaleSharedRequests() {
        sharedRequestQueue.async(flags: .barrier) {
            self.sharedRequestResults = self.sharedRequestResults.filter { _, task in
                !task.isCancelled
            }
        }
    }
    
    /// Get request optimization statistics
    func getRequestOptimizationStats() -> (pendingCount: Int, sharedCount: Int, maxConcurrency: Int) {
        let pending = pendingRequests.count
        let shared = sharedRequestQueue.sync { sharedRequestResults.count }
        return (pendingCount: pending, sharedCount: shared, maxConcurrency: maxConcurrentRequests)
    }
    
    // MARK: - Memory Management Implementation
    
    private func setupMemoryManagement() {
        // Monitor memory warnings
        setupMemoryPressureMonitoring()
        
        // Start maintenance timer for cleanup
        startMaintenanceTimer()
        
        logDebug(" Memory management initialized")
    }
    
    private func setupMemoryPressureMonitoring() {
        // Cancel any existing observer
        memoryWarningCancellable?.cancel()
        
        // For macOS, listen for NSApplication memory warnings and system notifications
        memoryWarningCancellable = NotificationCenter.default
            .publisher(for: NSApplication.didBecomeActiveNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.checkMemoryPressure()
            }
        
        // Start periodic memory monitoring
        memoryMonitorTimer?.cancel()
        memoryMonitorTimer = Timer.publish(every: 30.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.monitorMemoryUsage()
            }
    }
    
    private func handleMemoryWarning() {
        logDebug(" Memory warning received - implementing aggressive cleanup")
        
        isMemoryConstrained = true
        memoryPressureLevel = 3 // Critical
        shouldReduceUIUpdates = true
        
        // Aggressive memory cleanup
        performAggressiveMemoryCleanup()
        
        // Reduce refresh frequency
        dataFreshnessDuration = max(dataFreshnessDuration * 2, 300) // At least 5 minutes
        
        // Reduce concurrent requests
        maxConcurrentRequests = 1
        
        logDebug(" Memory warning handled - reduced operations to minimum")
    }
    
    private func checkMemoryPressure() {
        // Check for memory pressure indicators on macOS
        let processInfo = ProcessInfo.processInfo
        
        // Check for low memory conditions
        if processInfo.isLowPowerModeEnabled || processInfo.thermalState != .nominal {
            handleMemoryWarning()
        }
    }
    
    private func monitorMemoryUsage() {
        var memoryInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &memoryInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let memoryUsageMB = Double(memoryInfo.resident_size) / 1024.0 / 1024.0
            
            // Update memory pressure level based on usage (more generous thresholds for macOS)
            let previousLevel = memoryPressureLevel
            
            if memoryUsageMB > 400 {
                memoryPressureLevel = 3 // Critical
            } else if memoryUsageMB > 300 {
                memoryPressureLevel = 2 // Urgent
            } else if memoryUsageMB > 200 {
                memoryPressureLevel = 1 // Warning
            } else {
                memoryPressureLevel = 0 // Normal
            }
            
            // Only update UI if memory pressure changed significantly
            if abs(previousLevel - memoryPressureLevel) > 0 {
                isMemoryConstrained = memoryPressureLevel > 1
                shouldReduceUIUpdates = memoryPressureLevel > 2
                
                if memoryPressureLevel > previousLevel && memoryPressureLevel > 1 {
                    logDebug(" Memory pressure increased to level \(memoryPressureLevel) (\(String(format: "%.1f", memoryUsageMB)) MB)")
                    performMemoryOptimizations()
                }
            }
        }
    }
    
    private func performMemoryOptimizations() {
        switch memoryPressureLevel {
        case 1: // Warning
            performLightMemoryCleanup()
        case 2: // Urgent
            performModerateMemoryCleanup()
        case 3: // Critical
            performAggressiveMemoryCleanup()
        default:
            break
        }
    }
    
    private func performLightMemoryCleanup() {
        logDebug(" Performing light memory cleanup")
        
        // Clean old chart data (keep only last 7 days)
        cleanOldChartData(maxAge: 7 * 24 * 60 * 60)
        
        // Clear caches older than 1 hour
        clearOldCachedData(maxAge: 60 * 60)
    }
    
    private func performModerateMemoryCleanup() {
        logDebug(" Performing moderate memory cleanup")
        
        performLightMemoryCleanup()
        
        // Clean chart data more aggressively (keep only last 3 days)
        cleanOldChartData(maxAge: 3 * 24 * 60 * 60)
        
        // Clear inactive station data
        cleanInactiveStationData()
        
        // Reduce UI update frequency
        shouldReduceUIUpdates = true
    }
    
    private func performAggressiveMemoryCleanup() {
        logDebug(" Performing aggressive memory cleanup")
        
        performModerateMemoryCleanup()
        
        // Keep only today's chart data
        cleanOldChartData(maxAge: 24 * 60 * 60)
        
        // Clear all non-essential cached data
        clearOldCachedData(maxAge: 0)
        
        // Clear shared request results
        sharedRequestQueue.async(flags: .barrier) { [weak self] in
            self?.sharedRequestResults.removeAll()
        }
        
        // Force garbage collection
        autoreleasepool {
            // This will help ensure ARC cleans up any remaining references
        }
        
        // Reduce concurrent operations to absolute minimum
        maxConcurrentRequests = 1
        dataFreshnessDuration = max(dataFreshnessDuration, 600) // 10 minutes minimum
    }
    
    private func cleanOldChartData(maxAge: TimeInterval) {
        let cutoffDate = Date().addingTimeInterval(-maxAge)
        var removedCount = 0
        
        for (stationId, historicalData) in chartHistoricalData {
            var shouldRemove = false
            
            // Check if any data is older than cutoff
            if let outdoor = historicalData.outdoor?.temperature {
                for (timestampString, _) in outdoor.list {
                    if let timestamp = Double(timestampString) {
                        let dataDate = Date(timeIntervalSince1970: timestamp)
                        if dataDate < cutoffDate {
                            shouldRemove = true
                            break
                        }
                    }
                }
            }
            
            if shouldRemove {
                chartHistoricalData.removeValue(forKey: stationId)
                removedCount += 1
            }
        }
        
        if removedCount > 0 {
            logDebug(" Cleaned \(removedCount) old chart data entries")
        }
    }
    
    private func clearOldCachedData(maxAge: TimeInterval) {
        let cutoffDate = Date().addingTimeInterval(-maxAge)
        
        // Clean old request times
        let oldCount = lastRequestTimes.count
        lastRequestTimes = lastRequestTimes.filter { _, date in
            date > cutoffDate
        }
        
        if lastRequestTimes.count < oldCount {
            logDebug(" Cleaned \(oldCount - lastRequestTimes.count) old request time entries")
        }
    }
    
    private func cleanInactiveStationData() {
        let activeStationIds = Set(weatherStations.filter { $0.isActive }.map { $0.macAddress })
        
        let oldWeatherDataCount = weatherData.count
        weatherData = weatherData.filter { stationId, _ in
            activeStationIds.contains(stationId)
        }
        
        let oldHistoricalDataCount = historicalData.count
        historicalData = historicalData.filter { stationId, _ in
            activeStationIds.contains(stationId)
        }
        
        let oldChartDataCount = chartHistoricalData.count
        chartHistoricalData = chartHistoricalData.filter { stationId, _ in
            activeStationIds.contains(stationId)
        }
        
        let removedWeather = oldWeatherDataCount - weatherData.count
        let removedHistorical = oldHistoricalDataCount - historicalData.count
        let removedChart = oldChartDataCount - chartHistoricalData.count
        
        if removedWeather > 0 || removedHistorical > 0 || removedChart > 0 {
            logDebug(" Cleaned inactive station data: \(removedWeather) weather, \(removedHistorical) historical, \(removedChart) chart")
        }
    }
    
    private func startMaintenanceTimer() {
        // Cancel any existing timer
        maintenanceTimer?.cancel()
        
        // Run maintenance every 5 minutes, but reduce frequency under memory pressure
        let interval: TimeInterval = memoryPressureLevel > 1 ? 300 : 180 // 5 min vs 3 min
        
        maintenanceTimer = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.performRoutineMaintenance()
            }
    }
    
    private func performRoutineMaintenance() {
        // Only perform maintenance if not under severe memory pressure
        guard memoryPressureLevel < 3 else { return }
        
        // Light cleanup during routine maintenance
        if memoryPressureLevel > 0 {
            performLightMemoryCleanup()
        }
        
        // Clean up completed tasks
        requestQueue.async { [weak self] in
            self?.pendingRequestTasks = self?.pendingRequestTasks.filter { _, task in
                !task.isCancelled
            } ?? [:]
        }
        
        // Adjust settings based on memory pressure
        adjustSettingsForMemoryPressure()
    }
    
    private func adjustSettingsForMemoryPressure() {
        switch memoryPressureLevel {
        case 0: // Normal - restore optimal settings
            maxConcurrentRequests = min(6, maxConcurrentRequests + 1)
            dataFreshnessDuration = max(120, dataFreshnessDuration - 30) // Gradually reduce to 2 minutes
            shouldReduceUIUpdates = false
            
        case 1: // Warning - slight reduction
            maxConcurrentRequests = min(4, maxConcurrentRequests)
            dataFreshnessDuration = max(180, dataFreshnessDuration) // 3 minutes minimum
            
        case 2: // Urgent - significant reduction
            maxConcurrentRequests = min(2, maxConcurrentRequests)
            dataFreshnessDuration = max(300, dataFreshnessDuration) // 5 minutes minimum
            shouldReduceUIUpdates = true
            
        case 3: // Critical - minimum operations
            maxConcurrentRequests = 1
            dataFreshnessDuration = max(600, dataFreshnessDuration) // 10 minutes minimum
            shouldReduceUIUpdates = true
            
        default:
            break
        }
    }
    
    private func cleanup() {
        logDebug(" Cleaning up WeatherStationService")
        
        // Cancel all timers and observers
        memoryWarningCancellable?.cancel()
        maintenanceTimer?.cancel()
        memoryMonitorTimer?.cancel()
        
        // Cancel all pending tasks
        requestQueue.async { [weak self] in
            for (_, task) in self?.pendingRequestTasks ?? [:] {
                task.cancel()
            }
            self?.pendingRequestTasks.removeAll()
        }
        
        sharedRequestQueue.async(flags: .barrier) { [weak self] in
            self?.sharedRequestResults.removeAll()
        }
        
        // Clear large data structures
        weatherData.removeAll()
        historicalData.removeAll()
        chartHistoricalData.removeAll()
        lastRequestTimes.removeAll()
        pendingRequests.removeAll()
    }
    
    // MARK: - Memory-Optimized UI Update Methods
    
    func shouldPerformUIUpdate() -> Bool {
        // Reduce UI updates under memory pressure
        return !shouldReduceUIUpdates || memoryPressureLevel < 2
    }
    
    func getMemoryStatusInfo() -> String {
        let levelNames = ["Normal", "Warning", "Urgent", "Critical"]
        let levelName = levelNames[min(memoryPressureLevel, levelNames.count - 1)]
        
        let constrainedStatus = isMemoryConstrained ? "Constrained" : "Optimal"
        let updateStatus = shouldReduceUIUpdates ? "Reduced" : "Normal"
        
        return """
        Memory Status: \(levelName) (\(constrainedStatus))
        UI Updates: \(updateStatus)
        Max Concurrent Requests: \(maxConcurrentRequests)
        Data Freshness: \(Int(dataFreshnessDuration))s
        Weather Data Entries: \(weatherData.count)
        Historical Data Entries: \(historicalData.count)
        Chart Data Entries: \(chartHistoricalData.count)
        """
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