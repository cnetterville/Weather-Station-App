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
    private let session = URLSession.shared
    
    @Published var credentials: APICredentials = APICredentials(applicationKey: "", apiKey: "")
    @Published var weatherStations: [WeatherStation] = []
    @Published var discoveredStations: [EcowittDevice] = []
    @Published var weatherData: [String: WeatherStationData] = [:]
    @Published var historicalData: [String: HistoricalWeatherData] = [:]
    @Published var isLoading = false
    @Published var isLoadingHistory = false
    @Published var isDiscoveringStations = false
    @Published var errorMessage: String?
    
    private init() {
        loadCredentials()
        loadWeatherStations()
    }
    
    func fetchWeatherData(for station: WeatherStation) async {
        guard credentials.isValid else {
            await MainActor.run {
                print("❌ Credentials invalid for \(station.name)")
                errorMessage = "API credentials are not configured"
            }
            return
        }
        
        // Build URL exactly like your working example
        let urlString = "\(realTimeURL)?application_key=\(credentials.applicationKey)&api_key=\(credentials.apiKey)&mac=\(station.macAddress)&call_back=all"
        
        guard let url = URL(string: urlString) else {
            await MainActor.run {
                errorMessage = "Invalid URL for \(station.name): \(urlString)"
            }
            return
        }
        
        print("🌐 [Station: \(station.name)] Requesting: \(url.absoluteString)")
        
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 30.0
            request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            
            let (data, response) = try await session.data(for: request)
            
            print("📡 [Station: \(station.name)] Response received: \(data.count) bytes")
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 [Station: \(station.name)] HTTP Status: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode != 200 {
                    await MainActor.run {
                        errorMessage = "HTTP \(httpResponse.statusCode) for \(station.name)"
                    }
                    return
                }
            }
            
            // Try to parse as basic JSON first to see the structure
            do {
                if let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("📊 [Station: \(station.name)] JSON structure:")
                    print("📊 Root keys: \(Array(jsonObject.keys))")
                    
                    if let code = jsonObject["code"] as? Int {
                        print("📊 API code: \(code)")
                        
                        if code != 0 {
                            let msg = jsonObject["msg"] as? String ?? "Unknown error"
                            await MainActor.run {
                                errorMessage = "API Error for \(station.name): \(msg) (Code: \(code))"
                            }
                            return
                        }
                    }
                    
                    // Check what's in the data field
                    if let dataField = jsonObject["data"] as? [String: Any] {
                        print("📊 Data field keys: \(Array(dataField.keys))")
                        
                        // Log the first few keys from each main section to compare
                        if let outdoor = dataField["outdoor"] as? [String: Any] {
                            print("📊 Outdoor keys: \(Array(outdoor.keys))")
                        }
                        if let indoor = dataField["indoor"] as? [String: Any] {
                            print("📊 Indoor keys: \(Array(indoor.keys))")
                        }
                    } else {
                        print("📊 No 'data' field found or it's not a dictionary")
                        await MainActor.run {
                            errorMessage = "Invalid response structure for \(station.name): missing 'data' field"
                        }
                        return
                    }
                }
                
                // Now try our strict model parsing
                print("📊 [Station: \(station.name)] Attempting to parse with WeatherStationResponse model...")
                
                let decoder = JSONDecoder()
                let decodedResponse = try decoder.decode(WeatherStationResponse.self, from: data)
                
                await MainActor.run {
                    weatherData[station.macAddress] = decodedResponse.data
                    updateStationLastUpdated(station)
                    print("✅ [Station: \(station.name)] Successfully parsed and stored data")
                    
                    // Clear error if successful
                    if let currentError = errorMessage, currentError.contains(station.name) {
                        errorMessage = nil
                    }
                }
                
            } catch let jsonError {
                print("❌ [Station: \(station.name)] JSON parsing failed: \(jsonError)")
                
                // Let's see the raw response when parsing fails
                let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response"
                print("📄 [Station: \(station.name)] Raw response that failed to parse:")
                print("--- START RESPONSE ---")
                print(responseString.prefix(1000)) // First 1000 characters
                print("--- END RESPONSE ---")
                
                await MainActor.run {
                    errorMessage = "JSON parsing failed for \(station.name): \(jsonError.localizedDescription)"
                }
            }
            
        } catch {
            await MainActor.run {
                let detailedError = "Network Error for \(station.name): \(error.localizedDescription)"
                print("❌ \(detailedError)")
                errorMessage = detailedError
            }
        }
    }
    
    func fetchAllWeatherData() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil  // Clear previous errors
        }
        
        let activeStations = weatherStations.filter({ $0.isActive })
        print("📊 Fetching data for \(activeStations.count) active stations")
        
        // Process stations one by one with proper delays
        for (index, station) in activeStations.enumerated() {
            print("🔄 Processing station \(index + 1)/\(activeStations.count): \(station.name)")
            
            // Add delay before each request (except the first one)
            if index > 0 {
                print("⏳ Waiting 2 seconds before next request...")
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            }
            
            await fetchWeatherData(for: station)
        }
        
        await MainActor.run {
            isLoading = false
            print("✅ Finished processing all stations")
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
                            print("📍 Found station: \(device.name) (\(device.mac))")
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
    
    private func updateStationLastUpdated(_ station: WeatherStation) {
        if let index = weatherStations.firstIndex(where: { $0.id == station.id }) {
            weatherStations[index].lastUpdated = Date()
            saveWeatherStations()
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
}