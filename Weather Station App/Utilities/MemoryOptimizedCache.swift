//
//  MemoryOptimizedCache.swift
//  Weather Station App
//
//  Created by Assistant on 12/19/24.
//

import Foundation

/// Memory-optimized LRU cache with automatic memory pressure handling
actor MemoryOptimizedCache<Key: Hashable, Value> {
    private struct CacheItem {
        let value: Value
        let accessTime: Date
        let memoryFootprint: Int
    }
    
    private var storage: [Key: CacheItem] = [:]
    private var accessOrder: [Key] = []
    private var currentMemoryUsage: Int = 0
    private let maxMemoryLimit: Int
    private let maxItemCount: Int
    private let memoryCalculator: (Value) -> Int
    
    init(
        maxMemoryLimit: Int = 50 * 1024 * 1024, // 50MB default
        maxItemCount: Int = 1000,
        memoryCalculator: @escaping (Value) -> Int
    ) {
        self.maxMemoryLimit = maxMemoryLimit
        self.maxItemCount = maxItemCount
        self.memoryCalculator = memoryCalculator
    }
    
    /// Store value in cache with automatic memory management
    func store(_ value: Value, forKey key: Key) {
        let memoryFootprint = memoryCalculator(value)
        let item = CacheItem(
            value: value,
            accessTime: Date(),
            memoryFootprint: memoryFootprint
        )
        
        // Remove existing item if present
        if let existingItem = storage[key] {
            currentMemoryUsage -= existingItem.memoryFootprint
            if let index = accessOrder.firstIndex(of: key) {
                accessOrder.remove(at: index)
            }
        }
        
        // Store new item
        storage[key] = item
        accessOrder.append(key)
        currentMemoryUsage += memoryFootprint
        
        // Cleanup if necessary
        Task {
            await performCleanupIfNeeded()
        }
    }
    
    /// Retrieve value from cache
    func value(forKey key: Key) -> Value? {
        guard let item = storage[key] else { return nil }
        
        // Update access order for LRU
        if let index = accessOrder.firstIndex(of: key) {
            accessOrder.remove(at: index)
        }
        accessOrder.append(key)
        
        // Update access time
        let updatedItem = CacheItem(
            value: item.value,
            accessTime: Date(),
            memoryFootprint: item.memoryFootprint
        )
        storage[key] = updatedItem
        
        return item.value
    }
    
    /// Remove specific key
    func removeValue(forKey key: Key) {
        guard let item = storage[key] else { return }
        
        storage.removeValue(forKey: key)
        currentMemoryUsage -= item.memoryFootprint
        
        if let index = accessOrder.firstIndex(of: key) {
            accessOrder.remove(at: index)
        }
    }
    
    /// Clear all cached items
    func removeAll() {
        storage.removeAll()
        accessOrder.removeAll()
        currentMemoryUsage = 0
    }
    
    /// Get current memory statistics
    func getMemoryStats() -> (itemCount: Int, memoryUsage: Int, memoryLimit: Int) {
        return (storage.count, currentMemoryUsage, maxMemoryLimit)
    }
    
    /// Perform memory pressure cleanup
    func handleMemoryPressure(level: Int) async {
        let cleanupRatio: Double
        switch level {
        case 1: cleanupRatio = 0.2  // Remove 20% least recently used
        case 2: cleanupRatio = 0.5  // Remove 50%
        case 3: cleanupRatio = 0.8  // Remove 80%
        default: return
        }
        
        let itemsToRemove = Int(Double(storage.count) * cleanupRatio)
        await removeOldestItems(count: itemsToRemove)
        
        print("🧹 Cache cleanup: removed \(itemsToRemove) items due to memory pressure level \(level)")
    }
    
    private func performCleanupIfNeeded() async {
        // Check if we exceed memory limits
        while currentMemoryUsage > maxMemoryLimit || storage.count > maxItemCount {
            await removeOldestItem()
        }
    }
    
    private func removeOldestItem() async {
        guard let oldestKey = accessOrder.first else { return }
        removeValue(forKey: oldestKey)
    }
    
    private func removeOldestItems(count: Int) async {
        let keysToRemove = Array(accessOrder.prefix(count))
        for key in keysToRemove {
            removeValue(forKey: key)
        }
    }
}

/// Specialized cache for chart data points
actor ChartDataCache {
    static let shared = ChartDataCache()
    
    private let cache = MemoryOptimizedCache<String, [ChartDataPoint]>(
        maxMemoryLimit: 20 * 1024 * 1024, // 20MB for chart data
        maxItemCount: 100
    ) { chartDataPoints in
        // Estimate memory footprint: each ChartDataPoint has Date (8 bytes) + Double (8 bytes) + overhead
        return chartDataPoints.count * 32
    }
    
    private init() {}
    
    func storeChartData(_ data: [ChartDataPoint], forKey key: String) async {
        await cache.store(data, forKey: key)
    }
    
    func getChartData(forKey key: String) async -> [ChartDataPoint]? {
        await cache.value(forKey: key)
    }
    
    func handleMemoryPressure(level: Int) async {
        await cache.handleMemoryPressure(level: level)
    }
    
    func getMemoryStats() async -> (itemCount: Int, memoryUsage: Int, memoryLimit: Int) {
        await cache.getMemoryStats()
    }
    
    func removeAll() async {
        await cache.removeAll()
    }
}

/// Cache for computed daily statistics to avoid recalculation
actor DailyStatsCache {
    static let shared = DailyStatsCache()
    
    private struct StatsKey: Hashable {
        let stationId: String
        let dataType: String
        let date: String
    }
    
    private let temperatureStatsCache = MemoryOptimizedCache<StatsKey, DailyTemperatureStats>(
        maxMemoryLimit: 5 * 1024 * 1024, // 5MB
        maxItemCount: 200
    ) { _ in 200 } // Approximate size of DailyTemperatureStats
    
    private let humidityStatsCache = MemoryOptimizedCache<StatsKey, DailyHumidityStats>(
        maxMemoryLimit: 5 * 1024 * 1024, // 5MB  
        maxItemCount: 200
    ) { _ in 200 } // Approximate size of DailyHumidityStats
    
    private init() {}
    
    func storeTemperatureStats(_ stats: DailyTemperatureStats, stationId: String, dataType: String) async {
        let key = StatsKey(stationId: stationId, dataType: dataType, date: todayDateString())
        await temperatureStatsCache.store(stats, forKey: key)
    }
    
    func getTemperatureStats(stationId: String, dataType: String) async -> DailyTemperatureStats? {
        let key = StatsKey(stationId: stationId, dataType: dataType, date: todayDateString())
        return await temperatureStatsCache.value(forKey: key)
    }
    
    func storeHumidityStats(_ stats: DailyHumidityStats, stationId: String, dataType: String) async {
        let key = StatsKey(stationId: stationId, dataType: dataType, date: todayDateString())
        await humidityStatsCache.store(stats, forKey: key)
    }
    
    func getHumidityStats(stationId: String, dataType: String) async -> DailyHumidityStats? {
        let key = StatsKey(stationId: stationId, dataType: dataType, date: todayDateString())
        return await humidityStatsCache.value(forKey: key)
    }
    
    func handleMemoryPressure(level: Int) async {
        await temperatureStatsCache.handleMemoryPressure(level: level)
        await humidityStatsCache.handleMemoryPressure(level: level)
    }
    
    func removeAll() async {
        await temperatureStatsCache.removeAll()
        await humidityStatsCache.removeAll()
    }
    
    private func todayDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

/// Rolling window data structure for efficient memory usage with large datasets
struct RollingDataWindow<T> {
    private var data: [T]
    private let maxSize: Int
    private var writeIndex: Int = 0
    private var isFull: Bool = false
    
    init(maxSize: Int) {
        self.maxSize = maxSize
        self.data = []
        data.reserveCapacity(maxSize)
    }
    
    mutating func append(_ item: T) {
        if isFull {
            // Overwrite oldest data
            data[writeIndex] = item
        } else {
            data.append(item)
            if data.count == maxSize {
                isFull = true
            }
        }
        
        writeIndex = (writeIndex + 1) % maxSize
    }
    
    func getAllData() -> [T] {
        guard isFull else { return data }
        
        // Return data in chronological order when buffer is full
        let firstPart = Array(data[writeIndex...])
        let secondPart = Array(data[..<writeIndex])
        return firstPart + secondPart
    }
    
    var count: Int {
        return data.count
    }
    
    var isEmpty: Bool {
        return data.isEmpty
    }
    
    mutating func clear() {
        data.removeAll(keepingCapacity: true)
        writeIndex = 0
        isFull = false
    }
}