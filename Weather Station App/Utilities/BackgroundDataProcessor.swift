//
//  BackgroundDataProcessor.swift
//  Weather Station App
//
//  Created by Assistant on 12/19/24.
//

import Foundation

/// Priority levels for background processing tasks
enum ProcessingPriority: Int, Comparable {
    case critical = 4    // Real-time weather data
    case high = 3       // Daily statistics
    case normal = 2     // Chart data processing
    case low = 1        // Background cleanup
    
    static func < (lhs: ProcessingPriority, rhs: ProcessingPriority) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
    
    var qualityOfService: QualityOfService {
        switch self {
        case .critical: return .userInteractive
        case .high: return .userInitiated
        case .normal: return .utility
        case .low: return .background
        }
    }
}

/// Memory-aware background processor with task prioritization
actor BackgroundDataProcessor {
    static let shared = BackgroundDataProcessor()
    
    private let processingQueue = DispatchQueue(label: "weather.background.processing", qos: .utility, attributes: .concurrent)
    private let taskSemaphore: AsyncSemaphore
    private var isMemoryConstrained = false
    private var memoryPressureLevel = 0
    
    // Task tracking for memory management
    private var runningTasks: Set<String> = []
    private var taskPriorities: [String: ProcessingPriority] = [:]
    
    private init() {
        // Limit concurrent background tasks based on system capabilities
        let maxConcurrentTasks = ProcessInfo.processInfo.activeProcessorCount
        self.taskSemaphore = AsyncSemaphore(value: maxConcurrentTasks)
    }
    
    /// Process daily statistics calculation in the background
    func processDailyStats<T>(
        stationId: String,
        weatherData: WeatherStationData,
        historicalData: HistoricalWeatherData?,
        station: WeatherStation,
        calculator: @escaping () -> T?,
        priority: ProcessingPriority = .high
    ) async -> T? {
        // Check memory constraints
        guard shouldProcessTask(priority: priority) else {
            print("⚠️ Skipping daily stats processing due to memory constraints")
            return nil
        }
        
        let taskId = "dailyStats_\(stationId)_\(UUID())"
        await registerTask(taskId, priority: priority)
        
        defer {
            Task {
                await self.unregisterTask(taskId)
            }
        }
        
        await taskSemaphore.wait()
        defer {
            Task {
                await taskSemaphore.signal()
            }
        }
        
        return await withTaskGroup(of: T?.self) { group in
            group.addTask {
                // Perform calculation off main thread
                await Task.detached(priority: priority.taskPriority) {
                    return calculator()
                }.value
            }
            
            return await group.first { _ in true } ?? nil
        }
    }
    
    /// Process chart data conversion in the background
    func processChartData(
        stationId: String,
        measurement: HistoricalMeasurement?,
        priority: ProcessingPriority = .normal
    ) async -> [ChartDataPoint] {
        guard let measurement = measurement else { return [] }
        
        // Check cache first
        let cacheKey = generateChartCacheKey(stationId: stationId, measurement: measurement)
        if let cachedData = await ChartDataCache.shared.getChartData(forKey: cacheKey) {
            return cachedData
        }
        
        // Check memory constraints
        guard shouldProcessTask(priority: priority) else {
            print("⚠️ Returning limited chart data due to memory constraints")
            return limitChartDataForMemoryPressure(measurement)
        }
        
        let taskId = "chartData_\(stationId)_\(UUID())"
        await registerTask(taskId, priority: priority)
        
        defer {
            Task {
                await self.unregisterTask(taskId)
            }
        }
        
        await taskSemaphore.wait()
        defer {
            Task {
                await taskSemaphore.signal()
            }
        }
        
        // Process data in background
        let chartData = await Task.detached(priority: priority.taskPriority) {
            var dataPoints: [ChartDataPoint] = []
            dataPoints.reserveCapacity(measurement.list.count)
            
            for (timestampString, valueString) in measurement.list {
                if let timestamp = Double(timestampString),
                   let value = Double(valueString) {
                    let date = Date(timeIntervalSince1970: timestamp)
                    dataPoints.append(ChartDataPoint(timestamp: date, value: value))
                }
            }
            
            return dataPoints.sorted { $0.timestamp < $1.timestamp }
        }.value
        
        // Cache the result
        await ChartDataCache.shared.storeChartData(chartData, forKey: cacheKey)
        
        return chartData
    }
    
    /// Update memory pressure level and adjust processing accordingly
    func updateMemoryPressure(level: Int, isConstrained: Bool) async {
        memoryPressureLevel = level
        isMemoryConstrained = isConstrained
        
        // Cancel low-priority tasks under severe memory pressure
        if level >= 3 {
            await cancelLowPriorityTasks()
        }
        
        // Notify caches to perform cleanup
        await ChartDataCache.shared.handleMemoryPressure(level: level)
        await DailyStatsCache.shared.handleMemoryPressure(level: level)
        
        print("🧠 Background processor updated: memory level \(level), constrained: \(isConstrained)")
    }
    
    /// Get current processing statistics
    func getProcessingStats() async -> (runningTasks: Int, memoryLevel: Int, isConstrained: Bool) {
        return (runningTasks.count, memoryPressureLevel, isMemoryConstrained)
    }
    
    // MARK: - Private Methods
    
    private func shouldProcessTask(priority: ProcessingPriority) -> Bool {
        // Always allow critical tasks
        if priority == .critical {
            return true
        }
        
        // Under severe memory pressure, only allow high priority and above
        if memoryPressureLevel >= 3 && priority.rawValue < ProcessingPriority.high.rawValue {
            return false
        }
        
        // Under moderate memory pressure, skip low priority tasks
        if memoryPressureLevel >= 2 && priority == .low {
            return false
        }
        
        return true
    }
    
    private func registerTask(_ taskId: String, priority: ProcessingPriority) async {
        runningTasks.insert(taskId)
        taskPriorities[taskId] = priority
    }
    
    private func unregisterTask(_ taskId: String) async {
        runningTasks.remove(taskId)
        taskPriorities.removeValue(forKey: taskId)
    }
    
    private func cancelLowPriorityTasks() async {
        let lowPriorityTasks = taskPriorities.compactMap { taskId, priority in
            priority == .low ? taskId : nil
        }
        
        for taskId in lowPriorityTasks {
            runningTasks.remove(taskId)
            taskPriorities.removeValue(forKey: taskId)
        }
        
        if !lowPriorityTasks.isEmpty {
            print("🚫 Cancelled \(lowPriorityTasks.count) low-priority tasks due to memory pressure")
        }
    }
    
    private func generateChartCacheKey(stationId: String, measurement: HistoricalMeasurement) -> String {
        // Create a key based on station ID and data characteristics
        let dataHash = measurement.list.keys.sorted().joined().hashValue
        return "\(stationId)_\(measurement.unit)_\(dataHash)_\(measurement.list.count)"
    }
    
    private func limitChartDataForMemoryPressure(_ measurement: HistoricalMeasurement) -> [ChartDataPoint] {
        // Return a reduced dataset under memory pressure
        let maxPoints = memoryPressureLevel >= 3 ? 50 : (memoryPressureLevel >= 2 ? 100 : 200)
        
        var dataPoints: [ChartDataPoint] = []
        let keys = Array(measurement.list.keys.prefix(maxPoints))
        
        for timestampString in keys {
            if let timestamp = Double(timestampString),
               let valueString = measurement.list[timestampString],
               let value = Double(valueString) {
                let date = Date(timeIntervalSince1970: timestamp)
                dataPoints.append(ChartDataPoint(timestamp: date, value: value))
            }
        }
        
        return dataPoints.sorted { $0.timestamp < $1.timestamp }
    }
}

// MARK: - Extensions

extension ProcessingPriority {
    var taskPriority: TaskPriority {
        switch self {
        case .critical: return .userInitiated
        case .high: return .utility
        case .normal: return .utility
        case .low: return .background
        }
    }
}