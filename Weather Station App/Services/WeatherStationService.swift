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
    @Published var chartHistoricalData: [String: HistoricalWeatherData] = [:] // NEW: Separate data for charts
    @Published var isLoading = false
    @Published var isLoadingHistory = false
    @Published var isDiscoveringStations = false
    @Published var errorMessage: String?
    @Published var lastRefreshTime: Date = Date()
    
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
    }
    
    // MARK: - Optimized Data Fetching
    
    func fetchAllWeatherData(forceRefresh: Bool = false) async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        let activeStations = weatherStations.filter { $0.isActive }
        
        // Dynamically adjust concurrent requests based on number of stations
        let optimalConcurrency = min(maxConcurrentRequests, max(1, activeStations.count))
        print(" Fetching data for \(activeStations.count) active stations (concurrent: \(optimalConcurrency))")
        
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
                print(" All station data is still fresh, no API calls needed")
            }
            return
        }
        
        print(" \(stationsToFetch.count) stations need fresh data")
        
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
                    
                    // Also fetch today's historical data for high/low calculations (if not already cached)
                    if await !self.hasTodaysHistoricalData(for: station) {
                        await self.fetchTodaysHistoricalData(for: station)
                    }

                    
                    // Smaller delay for fewer stations
                    let delay = stationsToFetch.count <= 2 ? 100_000_000 : 250_000_000 // 0.1s vs 0.25s
                    try? await Task.sleep(nanoseconds: UInt64(delay))
                }
            }
        }
        
        await MainActor.run {
            isLoading = false
            lastRefreshTime = Date()
            print(" Concurrent fetch completed for \(stationsToFetch.count) stations")
        }
    }
    
    private func shouldFetchFreshData(for station: WeatherStation) -> Bool {
        // Check if we have data and it's still fresh
        if let _ = weatherData[station.macAddress],
           let lastUpdated = station.lastUpdated,
           TimestampExtractor.isDataFresh(lastUpdated, freshnessDuration: dataFreshnessDuration) {
            let ageSeconds = Int(Date().timeIntervalSince(lastUpdated))
            print(" Station \(station.name) has fresh data (age: \(ageSeconds)s)")
            return false
        }
        
        // Check if we're already fetching this station
        if pendingRequests.contains(station.macAddress) {
            print(" Station \(station.name) fetch already in progress")
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
            print(" [Station: \(station.name)] Failed to create request task")
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
                    print(" [Station: \(station.name)] Data updated successfully")
                    
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
                print(" [Station: \(station.name)] Reusing existing request task")
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
            print(" [Station: \(station.name)] Created new shared request task")
            return newTask
        }
    }
    
    /// Perform the actual network request (separated from deduplication logic)
    private func performActualWeatherRequest(for station: WeatherStation) async -> WeatherStationResponse? {
        guard credentials.isValid else {
            await MainActor.run {
                print(" Credentials invalid for \(station.name)")
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
        
        print(" [Station: \(station.name)] Performing actual network request")
        
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
            
            print(" [Station: \(station.name)] Response: \(data.count) bytes in \(String(format: "%.2f", requestDuration))s")
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 429 {
                    print(" Rate limited, reducing concurrent requests")
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
                print(" [Station: \(station.name)] \(detailedError)")
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
        print(" === TIMESTAMP PARSING TEST ===")
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
        print(" === END TEST ===")
    }
    
    func setDataFreshnessDuration(_ duration: TimeInterval) {
        dataFreshnessDuration = duration
        print(" Data freshness duration set to \(Int(duration)) seconds")
    }
    
    // MARK: - Background Refresh Management
    
    func refreshStaleData() async {
        let staleStations = weatherStations.filter { station in
            station.isActive && !isDataFresh(for: station)
        }
        
        if staleStations.isEmpty {
            print(" No stale data to refresh")
            return
        }
        
        print(" Refreshing \(staleStations.count) stations with stale data")
        
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
        
        for (timestampString, _) in temperature.list {
            if let timestamp = Double(timestampString) {
                let readingDate = Date(timeIntervalSince1970: timestamp)
                if calendar.isDate(readingDate, inSameDayAs: today) {
                    return true
                }
            }
        }
        
        return false
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
        print(" Fetching today's historical data (from 00:00) for \(station.name)...")
        
        // First fetch extended lightning data (30 days) and store it
        print(" Fetching extended lightning historical data for \(station.name)...")
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
                lightning: savedLightningData, // Use the 30-day lightning data
                pm25Ch1: existingData.pm25Ch1,
                pm25Ch2: existingData.pm25Ch2,
                pm25Ch3: existingData.pm25Ch3,
                tempAndHumidityCh1: existingData.tempAndHumidityCh1,
                tempAndHumidityCh2: existingData.tempAndHumidityCh2,
                tempAndHumidityCh3: existingData.tempAndHumidityCh3
            )
            historicalData[station.macAddress] = mergedData
            print(" Lightning data preserved: \(savedLightningData.count?.list.count ?? 0) readings")
        }
        
        // DEBUG: Check final lightning data
        if let lightningData = historicalData[station.macAddress]?.lightning?.count {
            print(" Final lightning data: \(lightningData.list.count) readings")
            
            // Show sample of recent data
            let recent = lightningData.list.prefix(5)
            for (timestamp, count) in recent {
                if let ts = Double(timestamp) {
                    let date = Date(timeIntervalSince1970: ts)
                    print("   - \(date): \(count)")
                }
            }
        } else {
            print(" No lightning data in final result")
        }
        
        print(" Completed today's 5-minute resolution historical data fetch from 00:00 for: \(station.name)")
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
        let startDate = calendar.date(byAdding: .day, value: -29, to: calendar.startOfDay(for: now)) ?? now

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
        
        print(" [Extended Lightning: \(station.name)] Requesting \(timeRange.rawValue)")
        print(" Date range: \(startDateString) to \(endDateString)")
        print(" Cycle type: \(timeRange.cycleType)")
        print(" URL: \(url.absoluteString)")
        
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
                    print(" Rate limited, reducing concurrent requests")
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
                        print(" Successfully merged 30-day lightning data")
                    } else {
                        // If no existing data, just store the lightning data
                        historicalData[station.macAddress] = historicalResponse.data
                        print(" Successfully stored 30-day lightning data")
                    }
                }
            }
            
        } catch {
            print(" [Extended Lightning: \(station.name)] Error: \(error.localizedDescription)")
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
                print("  Note: Requesting \(timeRange.rawValue) of data. API limitations:")
                print("   • Daily data: Only 3 months available")
                print("   • Weekly data: Up to 1 year available")
                print("   • Using \(timeRange.cycleType) cycle for this request")
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
            print("🕐 1-Hour range (5min resolution): \(startDate) to \(endDate)")
            print("🕐 Duration: \(String(format: "%.3f", actualDuration)) hours (well under 24hr limit)")
            print("🕐 Expected data points: ~12 (every 5 minutes for 1 hour)")
        case .last6Hours:
            // Last 6 hours from current time  
            endDate = now
            startDate = now.addingTimeInterval(-6 * 3600) // Exactly 6 hours ago
            print("🕐 6-Hour range: \(startDate) to \(endDate) (duration: \(endDate.timeIntervalSince(startDate)/3600) hours)")
            
        case .last24Hours:
            // Last 24 hours from current time
            endDate = now
            startDate = now.addingTimeInterval(-24 * 3600) // Exactly 24 hours ago
            print("🕐 24-Hour range: \(startDate) to \(endDate) (duration: \(endDate.timeIntervalSince(startDate)/3600) hours)")
            
        case .todayFrom00:
            // NEW: From midnight (00:00:00) of current day to now
            // This gives us the actual daily high/low for today's calendar day
            startDate = calendar.startOfDay(for: now)
            endDate = now
            print("🌡️ Today from 00:00 range: \(startDate) to \(endDate)")
            
        case .last7Days:
            // Last 7 full calendar days
            endDate = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: now) ?? now
            startDate = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now)) ?? now
            
        case .last30Days:
            // Last 30 full calendar days
            endDate = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: now) ?? now
            startDate = calendar.date(byAdding: .day, value: -29, to: calendar.startOfDay(for: now)) ?? now
            
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
        
        print(" [Historical: \(station.name)] Requesting \(timeRange.rawValue)")
        print(" Date range: \(startDateString) to \(endDateString)")
        print(" Cycle type: \(timeRange.cycleType)")
        print(" URL: \(url.absoluteString)")
        
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 60.0 // Longer timeout for historical data
            request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            
            let (data, response) = try await session.data(for: request)
            
            print(" [Historical: \(station.name)] Response received: \(data.count) bytes")
            
            if let httpResponse = response as? HTTPURLResponse {
                print(" [Historical: \(station.name)] HTTP Status: \(httpResponse.statusCode)")
                
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
                print(" Historical data error: \(error)")
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
            print("   Temperature data merge: preserving existing \(existing.list.count) points, adding new \(new.list.count) points")
            
            // Merge the data: combine existing comprehensive data with new specific time range data
            var mergedList = existing.list
            for (timestamp, value) in new.list {
                mergedList[timestamp] = value  // New data overwrites existing for same timestamps
            }
            
            return HistoricalMeasurement(unit: existing.unit, list: mergedList)
        } else {
            print("   Temperature data merge: using new data (\(new.list.count) points) for chart display")
            return new
        }
    }
    
    private func mergeHumidityData(existing: HistoricalMeasurement?, new: HistoricalMeasurement?, preserveExisting: Bool) -> HistoricalMeasurement? {
        guard let existing = existing else { return new }
        guard let new = new else { return existing }
        
        if preserveExisting {
            print("   Humidity data merge: preserving existing \(existing.list.count) points, adding new \(new.list.count) points")
            
            // Merge the data: combine existing comprehensive data with new specific time range data
            var mergedList = existing.list
            for (timestamp, value) in new.list {
                mergedList[timestamp] = value  // New data overwrites existing for same timestamps
            }
            
            return HistoricalMeasurement(unit: existing.unit, list: mergedList)
        } else {
            print("   Humidity data merge: using new data (\(new.list.count) points) for chart display")
            return new
        }
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
    
    // NEW: Get chart data from the separate chart historical data
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
        
        print(" Discovering weather stations...")
        print(" URL: \(url.absoluteString)")
        
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 30.0
            request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            
            let (data, response) = try await session.data(for: request)
            
            print(" Device list response received: \(data.count) bytes")
            
            if let httpResponse = response as? HTTPURLResponse {
                print(" HTTP Status: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode != 200 {
                    await MainActor.run {
                        isDiscoveringStations = false
                    }
                    return (false, "HTTP \(httpResponse.statusCode)")
                }
            }
            
            // Let's see the raw response first
            let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response"
            print(" Raw device list response:")
            print("--- START RESPONSE ---")
            print(responseString)
            print("--- END RESPONSE ---")
            
            // Try to parse as basic JSON first to see the structure
            do {
                if let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print(" Device list JSON structure:")
                    print(" Root keys: \(Array(jsonObject.keys))")
                    
                    if let code = jsonObject["code"] as? Int {
                        print(" API code: \(code)")
                        
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
                        print(" Data field is an array with \(dataField.count) items")
                        
                        // Log the first device structure if available
                        if let firstDevice = dataField.first as? [String: Any] {
                            print(" First device keys: \(Array(firstDevice.keys))")
                        }
                    } else {
                        print(" Data field structure: \(type(of: jsonObject["data"]))")
                        print(" Data field value: \(jsonObject["data"] ?? "nil")")
                    }
                } else {
                    await MainActor.run {
                        isDiscoveringStations = false
                    }
                    return (false, "Invalid JSON response structure")
                }
                
                // Now try our strict model parsing
                print(" Attempting to parse with DeviceListResponse model...")
                
                let decoder = JSONDecoder()
                let deviceListResponse = try decoder.decode(DeviceListResponse.self, from: data)
                
                await MainActor.run {
                    isDiscoveringStations = false
                    
                    if deviceListResponse.code == 0 {
                        discoveredStations = deviceListResponse.data.list
                        print(" Successfully discovered \(discoveredStations.count) weather stations")
                        
                        // Log discovered stations
                        for device in discoveredStations {
                            print(" Found device: \(device.name) (\(device.mac))")
                            print("   Device Type: \(device.type) (\(self.deviceTypeDescription(device.type)))")
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
                print(" JSON parsing failed: \(jsonError)")
                
                await MainActor.run {
                    isDiscoveringStations = false
                }
                
                return (false, "Discovery failed: Unable to parse API response. Check console for details.")
            }
            
        } catch {
            await MainActor.run {
                isDiscoveringStations = false
            }
            print(" Device discovery error: \(error)")
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
            print(" Updated existing station with discovery data: \(updatedStation.name) (\(updatedStation.macAddress))")
        } else {
            weatherStations.append(newStation)
            saveWeatherStations()
            print(" Added new station: \(newStation.name) (\(newStation.macAddress))")
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
            print(" Added \(addedCount) new weather station\(addedCount == 1 ? "" : "s")")
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
                
                print(" Updated \(station.name) timestamp (from all sensors):")
                print("   Old: \(oldTimestamp?.description ?? "never")")
                print("   New: \(mostRecentTimestamp.description)")
                print("   Station timezone: \(station.timeZone.identifier)")
                print("   Data age: \(TimestampExtractor.formatDataAge(from: mostRecentTimestamp))")
                
                // Warn if timestamp seems problematic
                let currentTime = Date()
                let timeDifference = abs(currentTime.timeIntervalSince(mostRecentTimestamp))
                if timeDifference > 86400 { // More than 1 day difference
                    print(" WARNING: Weather data timestamp is \(Int(timeDifference/3600)) hours off from current time")
                }
            } else {
                print(" Could not find station \(station.name) to update timestamp")
            }
            return
        }
        
        // Fallback to original method using outdoor temperature timestamp if TimestampExtractor fails
        print(" TimestampExtractor failed, falling back to outdoor temperature timestamp")
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
                print(" Could not parse timestamp '\(timestampString)' for \(station.name), using current time")
                actualDataTime = Date()
            }
        }
        
        if let index = weatherStations.firstIndex(where: { $0.id == station.id }) {
            let oldTimestamp = weatherStations[index].lastUpdated
            weatherStations[index].lastUpdated = actualDataTime
            saveWeatherStations()
            
            print(" Updated \(station.name) timestamp (fallback method):")
            print("   Old: \(oldTimestamp?.description ?? "never")")
            print("   New: \(actualDataTime.description) (from weather data)")
            print("   Raw timestamp: \(timestampString)")
        } else {
            print(" Could not find station \(station.name) to update timestamp")
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
        
        print(" Fetching station info for \(station.name)...")
        print(" URL: \(url.absoluteString)")
        
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 30.0
            request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print(" Station info HTTP Status: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode != 200 {
                    return (false, "HTTP \(httpResponse.statusCode)")
                }
            }
            
            // Parse the response
            if let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let code = jsonObject["code"] as? Int {
                
                print(" Device info JSON response: \(jsonObject)")
                
                if code == 0,
                   let dataField = jsonObject["data"] as? [String: Any] {
                    
                    // Extract station info
                    let latitude = dataField["latitude"] as? Double
                    let longitude = dataField["longitude"] as? Double
                    let timeZoneId = dataField["date_zone_id"] as? String
                    let stationType = dataField["stationtype"] as? String
                    let createtime = dataField["createtime"] as? Int
                    
                    // Look for camera-related fields
                    print(" Checking for camera fields in device info...")
                    for (key, value) in dataField {
                        if key.lowercased().contains("camera") || 
                           key.lowercased().contains("image") || 
                           key.lowercased().contains("photo") || 
                           key.lowercased().contains("picture") {
                            print(" Found potential camera field: \(key) = \(value)")
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
                            
                            print(" Updated station info for \(station.name):")
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
            print(" Station info fetch error: \(error)")
            return (false, "Failed to fetch station info: \(error.localizedDescription)")
        }
    }
    
    func fetchCameraImage(for station: WeatherStation) async -> String? {
        guard credentials.isValid else {
            print(" Credentials invalid for camera image fetch")
            return nil
        }
        
        // Only proceed if station has an associated camera
        guard let cameraMAC = station.associatedCameraMAC else {
            print(" No associated camera for station: \(station.name)")
            return nil
        }
        
        print(" Starting camera image search for station: \(station.name)")
        print(" Using associated camera MAC: \(cameraMAC)")
        
        // Construct the camera endpoint URL carefully
        let baseURL = "https://cdnapi.ecowitt.net/api/v3/device/real_time"
        let applicationKey = credentials.applicationKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let apiKey = credentials.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let url = URL(string: "\(baseURL)?application_key=\(applicationKey)&api_key=\(apiKey)&mac=\(cameraMAC)&call_back=camera") else {
            print(" Invalid camera URL construction")
            return nil
        }
        
        print(" Camera endpoint URL: \(url.absoluteString)")
        
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 30.0
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print(" Camera HTTP Status: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 200 {
                    print(" Response size: \(data.count) bytes")
                    
                    // Log the raw response for debugging
                    if let responseString = String(data: data, encoding: .utf8) {
                        print(" Camera raw response: \(responseString)")
                    }
                    
                    // Check if data field is an empty array (no camera data available)
                    if let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let dataField = jsonObject["data"] as? [Any],
                       dataField.isEmpty {
                        print(" Camera API returned empty data array - no camera data available for this device")
                        return nil
                    }
                    
                    // Try to parse as camera response
                    do {
                        let decoder = JSONDecoder()
                        let cameraResponse = try decoder.decode(CameraResponse.self, from: data)
                        
                        if cameraResponse.code == 0 {
                            let imageUrl = cameraResponse.data.camera.photo.url
                            let imageTime = cameraResponse.data.camera.photo.time
                            
                            print(" Found camera image URL: \(imageUrl)")
                            print(" Image timestamp: \(imageTime)")
                            
                            return imageUrl
                        } else {
                            print(" Camera API error: \(cameraResponse.msg) (Code: \(cameraResponse.code))")
                        }
                    } catch {
                        print(" Failed to parse camera response: \(error)")
                        print(" This likely means the device is not a camera or has no camera data available")
                        
                        return nil
                    }
                } else {
                    print(" HTTP Error: \(httpResponse.statusCode)")
                    
                    // Log error response body
                    if let responseString = String(data: data, encoding: .utf8) {
                        print(" Error response: \(responseString)")
                    }
                }
            }
            
        } catch {
            print(" Camera request error: \(error.localizedDescription)")
        }
        
        print(" No camera image URL found for station: \(station.name)")
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
        print(" Starting automatic camera-station association...")
        print(" Distance threshold: \(distanceThresholdKm) km")
        
        // Get all camera devices (type 2)
        let cameraDevices = discoveredStations.filter { $0.type == 2 }
        
        // Get all weather station devices (any type, or specifically type 1)
        let stationDevices = weatherStations.filter { station in
            // Accept stations without device type or with device type 1
            station.deviceType == nil || station.deviceType == 1
        }
        
        print(" Found \(cameraDevices.count) camera devices")
        print(" Found \(stationDevices.count) weather stations")
        
        // Debug: show all stations
        for station in weatherStations {
            print(" Station: \(station.name), deviceType: \(station.deviceType?.description ?? "nil"), location: \(station.latitude?.description ?? "nil"), \(station.longitude?.description ?? "nil")")
        }
        
        for camera in cameraDevices {
            guard let cameraLat = camera.latitude, let cameraLon = camera.longitude else {
                print(" Camera \(camera.name) has no location data, skipping")
                continue
            }
            
            print(" Processing camera: \(camera.name) at (\(cameraLat), \(cameraLon))")
            
            var associatedStations: [WeatherStation] = []
            
            // Find ALL stations within the threshold distance
            for station in stationDevices {
                guard let stationLat = station.latitude, let stationLon = station.longitude else {
                    print(" Station \(station.name) has no location data, skipping")
                    continue
                }
                
                let distance = calculateDistance(
                    lat1: cameraLat, lon1: cameraLon,
                    lat2: stationLat, lon2: stationLon
                )
                
                print(" Distance to \(station.name): \(String(format: "%.3f", distance)) km")
                
                if distance <= distanceThresholdKm {
                    associatedStations.append(station)
                    print(" Station \(station.name) is within threshold (\(String(format: "%.3f", distance)) km)")
                }
            }
            
            // Associate camera with all nearby stations
            if !associatedStations.isEmpty {
                for station in associatedStations {
                    if let index = weatherStations.firstIndex(where: { $0.id == station.id }) {
                        weatherStations[index].associatedCameraMAC = camera.mac
                        print(" Associated camera \(camera.name) with station \(station.name)")
                    }
                }
                saveWeatherStations()
                print(" Camera \(camera.name) associated with \(associatedStations.count) station(s)")
            } else {
                print(" No weather stations found within \(distanceThresholdKm) km for camera \(camera.name)")
            }
        }
        
        print(" Camera-station association complete")
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
            print(" Standard parsing failed for \(station.name): \(error)")
        }
        
        // If standard parsing fails, try to parse as generic JSON and extract what we can
        do {
            if let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let code = jsonObject["code"] as? Int,
               let msg = jsonObject["msg"] as? String {
                
                print(" [Station: \(station.name)] API Response - Code: \(code), Message: \(msg)")
                
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
            print(" Even generic JSON parsing failed for \(station.name): \(error)")
        }
        
        return nil
    }
    
    private func extractWeatherDataSafely(from dataDict: [String: Any], for station: WeatherStation) -> WeatherStationData {
        print(" [Station: \(station.name)] Attempting safe data extraction from available fields")
        
        // Create empty data structure and fill what we can
        let extractedData = WeatherStationData.empty()
        
        // Extract outdoor data if available
        if dataDict["outdoor"] != nil {
            print(" [Station: \(station.name)] Found outdoor data")
            // Try to extract basic outdoor measurements
            // This would need implementation based on your WeatherStationData model
        }
        
        // Extract indoor data if available
        if dataDict["indoor"] != nil {
            print(" [Station: \(station.name)] Found indoor data")
            // Try to extract basic indoor measurements
        }
        
        // Extract other sensor data
        for (key, value) in dataDict {
            print(" [Station: \(station.name)] Available data field: \(key) (\(type(of: value)))")
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
