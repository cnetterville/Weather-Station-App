//
//  RadarRefreshManager.swift
//  Weather Station App
//
//  Created by Curtis Netterville on 10/25/25.
//

import Foundation
import Combine

/// Persistent radar refresh manager that continues working regardless of app state or memory pressure
/// Uses DispatchSourceTimer for reliability and won't be suspended by system optimizations
class RadarRefreshManager: ObservableObject {
    static let shared = RadarRefreshManager()
    
    // Published state for UI binding
    @Published private var refreshStates: [String: RadarRefreshState] = [:]
    
    // Internal timer management
    private var timers: [String: DispatchSourceTimer] = [:]
    private var countdownTimers: [String: DispatchSourceTimer] = [:]
    private let timerQueue = DispatchQueue(label: "radar.refresh.timers", qos: .userInitiated)
    private let stateQueue = DispatchQueue(label: "radar.refresh.state", attributes: .concurrent)
    
    // Settings
    @Published var defaultRefreshInterval: TimeInterval = 600 { // 10 minutes default
        didSet {
            UserDefaults.standard.radarRefreshInterval = defaultRefreshInterval
            // Update all active timers with new interval
            updateAllTimerIntervals()
        }
    }
    
    private init() {
        defaultRefreshInterval = UserDefaults.standard.radarRefreshInterval
        
        // Listen for settings changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSettingsChange),
            name: .radarSettingsChanged,
            object: nil
        )
        
        logRefresh("RadarRefreshManager initialized with \(Int(defaultRefreshInterval))s interval")
    }
    
    deinit {
        stopAllTimers()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Public API
    
    /// Start tracking radar refresh for a station
    func startTracking(stationId: String, customInterval: TimeInterval? = nil) {
        let interval = customInterval ?? defaultRefreshInterval
        
        stateQueue.async(flags: .barrier) {
            // Initialize state if needed
            if self.refreshStates[stationId] == nil {
                let initialState = RadarRefreshState(
                    stationId: stationId,
                    refreshInterval: interval,
                    nextRefreshTime: Date().addingTimeInterval(interval),
                    timeRemaining: interval,
                    isRefreshing: false
                )
                
                DispatchQueue.main.async {
                    self.refreshStates[stationId] = initialState
                }
            }
            
            // Start persistent timers
            self.startPersistentTimer(for: stationId, interval: interval)
            self.startCountdownTimer(for: stationId)
        }
        
        logRefresh("Started radar tracking for station: \(stationId) (interval: \(Int(interval))s)")
    }
    
    /// Stop tracking radar refresh for a station
    func stopTracking(stationId: String) {
        stateQueue.async(flags: .barrier) {
            self.stopTimer(for: stationId)
            self.stopCountdownTimer(for: stationId)
            
            DispatchQueue.main.async {
                self.refreshStates.removeValue(forKey: stationId)
            }
        }
        
        logRefresh("Stopped radar tracking for station: \(stationId)")
    }
    
    /// Trigger immediate refresh and reset timer
    func triggerRefresh(for stationId: String) {
        stateQueue.async(flags: .barrier) {
            let interval = self.refreshStates[stationId]?.refreshInterval ?? self.defaultRefreshInterval
            let nextRefreshTime = Date().addingTimeInterval(interval)
            
            DispatchQueue.main.async {
                if var state = self.refreshStates[stationId] {
                    state.isRefreshing = true
                    state.nextRefreshTime = nextRefreshTime
                    state.timeRemaining = interval
                    self.refreshStates[stationId] = state
                    
                    // Post notification for UI to refresh
                    NotificationCenter.default.post(name: .radarRefreshTriggered, object: stationId)
                    
                    // Clear refreshing state after a delay (simulating refresh completion)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        if var currentState = self.refreshStates[stationId] {
                            currentState.isRefreshing = false
                            self.refreshStates[stationId] = currentState
                        }
                    }
                }
            }
            
            // Restart timer with fresh interval
            self.stopTimer(for: stationId)
            self.startPersistentTimer(for: stationId, interval: interval)
        }
        
        logRefresh("Manual refresh triggered for station: \(stationId)")
    }
    
    /// Get current refresh state for a station
    func getRefreshState(for stationId: String) -> RadarRefreshState? {
        return refreshStates[stationId]
    }
    
    /// Get time remaining string for display
    func getTimeRemainingString(for stationId: String) -> String {
        guard let state = refreshStates[stationId] else { return "600s" }
        
        if state.isRefreshing {
            return "refreshing..."
        }
        
        let timeRemaining = max(0, state.timeRemaining)
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
    
    // MARK: - Private Implementation
    
    private func startPersistentTimer(for stationId: String, interval: TimeInterval) {
        // Create persistent timer using DispatchSourceTimer
        let timer = DispatchSource.makeTimerSource(queue: timerQueue)
        timer.schedule(deadline: .now() + interval, repeating: interval)
        
        timer.setEventHandler { [weak self] in
            self?.handleTimerFire(stationId: stationId)
        }
        
        timer.resume()
        timers[stationId] = timer
        
        logTimer("Started persistent timer for \(stationId): \(Int(interval))s interval")
    }
    
    private func startCountdownTimer(for stationId: String) {
        // Create countdown timer that updates every second
        let countdownTimer = DispatchSource.makeTimerSource(queue: timerQueue)
        countdownTimer.schedule(deadline: .now() + 1.0, repeating: 1.0)
        
        countdownTimer.setEventHandler { [weak self] in
            self?.updateTimeRemaining(for: stationId)
        }
        
        countdownTimer.resume()
        countdownTimers[stationId] = countdownTimer
        
        logTimer("Started countdown timer for \(stationId)")
    }
    
    private func stopTimer(for stationId: String) {
        if let timer = timers[stationId] {
            timer.cancel()
            timers.removeValue(forKey: stationId)
            logTimer("Stopped timer for \(stationId)")
        }
    }
    
    private func stopCountdownTimer(for stationId: String) {
        if let timer = countdownTimers[stationId] {
            timer.cancel()
            countdownTimers.removeValue(forKey: stationId)
            logTimer("Stopped countdown timer for \(stationId)")
        }
    }
    
    private func stopAllTimers() {
        for (stationId, timer) in timers {
            timer.cancel()
            logTimer("Cancelled timer for \(stationId)")
        }
        timers.removeAll()
        
        for (stationId, timer) in countdownTimers {
            timer.cancel()
            logTimer("Cancelled countdown timer for \(stationId)")
        }
        countdownTimers.removeAll()
    }
    
    private func handleTimerFire(stationId: String) {
        let nextRefreshTime = Date().addingTimeInterval(defaultRefreshInterval)
        
        DispatchQueue.main.async {
            if var state = self.refreshStates[stationId] {
                state.isRefreshing = true
                state.nextRefreshTime = nextRefreshTime
                state.timeRemaining = self.defaultRefreshInterval
                self.refreshStates[stationId] = state
                
                // Post notification for UI to refresh
                NotificationCenter.default.post(name: .radarRefreshTriggered, object: stationId)
                
                // Clear refreshing state after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    if var currentState = self.refreshStates[stationId] {
                        currentState.isRefreshing = false
                        self.refreshStates[stationId] = currentState
                    }
                }
            }
        }
        
        logRefresh("Auto-refresh fired for station: \(stationId)")
    }
    
    private func updateTimeRemaining(for stationId: String) {
        DispatchQueue.main.async {
            if var state = self.refreshStates[stationId] {
                let newTimeRemaining = state.nextRefreshTime.timeIntervalSince(Date())
                
                // If time has passed, reset to full interval (safety check)
                if newTimeRemaining <= 0 && !state.isRefreshing {
                    state.nextRefreshTime = Date().addingTimeInterval(state.refreshInterval)
                    state.timeRemaining = state.refreshInterval
                } else {
                    state.timeRemaining = max(0, newTimeRemaining)
                }
                
                self.refreshStates[stationId] = state
            }
        }
    }
    
    private func updateAllTimerIntervals() {
        stateQueue.async(flags: .barrier) {
            for stationId in self.timers.keys {
                // Stop existing timer
                self.stopTimer(for: stationId)
                
                // Start new timer with updated interval
                self.startPersistentTimer(for: stationId, interval: self.defaultRefreshInterval)
                
                // Update state
                DispatchQueue.main.async {
                    if var state = self.refreshStates[stationId] {
                        state.refreshInterval = self.defaultRefreshInterval
                        state.nextRefreshTime = Date().addingTimeInterval(self.defaultRefreshInterval)
                        state.timeRemaining = self.defaultRefreshInterval
                        self.refreshStates[stationId] = state
                    }
                }
            }
        }
        
        logRefresh("Updated all timer intervals to \(Int(defaultRefreshInterval))s")
    }
    
    @objc private func handleSettingsChange(notification: Notification) {
        if let newInterval = notification.object as? TimeInterval {
            defaultRefreshInterval = newInterval
        }
    }
}

// MARK: - Support Types

struct RadarRefreshState {
    let stationId: String
    var refreshInterval: TimeInterval
    var nextRefreshTime: Date
    var timeRemaining: TimeInterval
    var isRefreshing: Bool
    
    var statusText: String {
        if isRefreshing {
            return "refreshing..."
        }
        
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let radarRefreshTriggered = Notification.Name("radarRefreshTriggered")
    // NOTE: radarSettingsChanged is already defined in MenuBarManager.swift
}