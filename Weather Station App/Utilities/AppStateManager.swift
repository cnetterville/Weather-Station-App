//
//  AppStateManager.swift
//  Weather Station App
//
//  Created by Assistant on 12/19/24.
//

import SwiftUI
import AppKit
import Combine

/// Manages app visibility state and coordinates refresh behavior between main app and menubar
class AppStateManager: ObservableObject {
    static let shared = AppStateManager()
    
    @Published var isMainAppVisible: Bool = true
    @Published var isAppActive: Bool = true
    
    // Timer for main app refresh (when app is visible)
    private var mainAppRefreshTimer: Timer?
    private var mainAppRefreshInterval: TimeInterval = 120 // 2 minutes default - matches data freshness
    
    // Settings
    @Published var mainAppRefreshEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(mainAppRefreshEnabled, forKey: "MainAppRefreshEnabled")
            updateRefreshState()
        }
    }
    
    private let weatherService = WeatherStationService.shared
    // Remove direct MenuBarManager reference to avoid circular dependency
    
    private init() {
        loadSettings()
        setupAppStateMonitoring()
        updateRefreshState()
    }
    
    deinit {
        stopMainAppRefresh()
        NotificationCenter.default.removeObserver(self)
    }
    
    private func loadSettings() {
        mainAppRefreshEnabled = UserDefaults.standard.object(forKey: "MainAppRefreshEnabled") as? Bool ?? true
        mainAppRefreshInterval = UserDefaults.standard.object(forKey: "MainAppRefreshInterval") as? TimeInterval ?? 120
    }
    
    private func setupAppStateMonitoring() {
        // Monitor when app becomes active/inactive
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidResignActive),
            name: NSApplication.didResignActiveNotification,
            object: nil
        )
        
        // Monitor when app is hidden/shown
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidHide),
            name: NSApplication.didHideNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidUnhide),
            name: NSApplication.didUnhideNotification,
            object: nil
        )
        
        // Monitor window visibility changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidBecomeKey),
            name: NSWindow.didBecomeKeyNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidResignKey),
            name: NSWindow.didResignKeyNotification,
            object: nil
        )
        
        // Start monitoring window visibility periodically
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.checkMainWindowVisibility()
            }
        }
        
        logDebug("AppStateManager: Monitoring app state changes")
    }
    
    @objc private func appDidBecomeActive() {
        logSuccess("App became active")
        isAppActive = true
        checkMainWindowVisibility()
        updateRefreshState()
    }
    
    @objc private func appDidResignActive() {
        logWarning("App resigned active")
        isAppActive = false
        // Don't immediately update refresh state - wait to see if windows are still visible
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.checkMainWindowVisibility()
            self.updateRefreshState()
        }
    }
    
    @objc private func appDidHide() {
        logError("App was hidden")
        isMainAppVisible = false
        updateRefreshState()
    }
    
    @objc private func appDidUnhide() {
        logSuccess("App was unhidden")
        isMainAppVisible = true
        updateRefreshState()
    }
    
    @objc private func windowDidBecomeKey() {
        checkMainWindowVisibility()
        updateRefreshState()
    }
    
    @objc private func windowDidResignKey() {
        // Delay check to see if another main window becomes key
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.checkMainWindowVisibility()
            self.updateRefreshState()
        }
    }
    
    private func checkMainWindowVisibility() {
        let hasVisibleMainWindow = NSApp.windows.contains { window in
            !window.className.contains("StatusBar") &&
            !window.className.contains("Item") &&
            window.isVisible &&
            window.contentView != nil &&
            window.frame.width > 500 &&
            !window.isMiniaturized
        }
        
        let wasVisible = isMainAppVisible
        
        // Defer the @Published property update to avoid "Publishing changes from within view updates" warning
        Task { @MainActor in
            self.isMainAppVisible = hasVisibleMainWindow
            
            if wasVisible != self.isMainAppVisible {
                logUI("Main app visibility changed: \(wasVisible) → \(self.isMainAppVisible)")
            }
        }
    }
    
    /// Update refresh behavior based on current app state
    private func updateRefreshState() {
        logRefresh("AppStateManager: Updating refresh state")
        logRefresh("   - Main app visible: \(isMainAppVisible)")
        logRefresh("   - App active: \(isAppActive)")
        logRefresh("   - Main refresh enabled: \(mainAppRefreshEnabled)")
        
        if isMainAppVisible && mainAppRefreshEnabled {
            // Main app is visible - use main app refresh (always refresh)
            startMainAppRefresh()
            
            // Post notification for MenuBarManager to stop its background refresh
            NotificationCenter.default.post(name: .mainAppVisible, object: nil)
            
        } else {
            // Main app is not visible - stop main app refresh
            stopMainAppRefresh()
            
            // Post notification for MenuBarManager to start its background refresh if needed
            NotificationCenter.default.post(name: .mainAppHidden, object: nil)
        }
    }
    
    /// Start the main app refresh timer - this runs when the main app window is visible
    private func startMainAppRefresh() {
        stopMainAppRefresh() // Stop any existing timer
        
        guard mainAppRefreshEnabled && !weatherService.weatherStations.isEmpty else {
            logRefresh("Main app refresh not started - disabled or no stations")
            return
        }
        
        mainAppRefreshTimer = Timer.scheduledTimer(withTimeInterval: mainAppRefreshInterval, repeats: true) { [weak self] timer in
            guard let self = self else {
                logError("AppStateManager deallocated, stopping main app refresh timer")
                timer.invalidate()
                return
            }
            
            logRefresh("Main app refresh timer fired at \(Date())")
            
            // Always refresh when main app is visible (ignore idle state)
            if !self.weatherService.isLoading {
                Task { @MainActor in
                    logRefresh("Starting main app refresh (always refresh when visible)")
                    await self.weatherService.fetchAllWeatherData(forceRefresh: false)
                    logRefresh("Main app refresh completed at \(Date())")
                }
            } else {
                logWarning("Skipping main app refresh - previous refresh still in progress")
            }
        }
        
        let minutes = Int(mainAppRefreshInterval / 60)
        logRefresh("Main app refresh started: every \(minutes) minute\(minutes == 1 ? "" : "s") (always active when visible)")
        
        // Do an immediate refresh if data is stale
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            let hasStaleData = self.weatherService.weatherStations.contains { station in
                !self.weatherService.isDataFresh(for: station) && station.isActive
            }
            
            if hasStaleData {
                logRefresh("Running immediate main app refresh for stale data")
                Task {
                    await self.weatherService.fetchAllWeatherData(forceRefresh: false)
                }
            }
        }
    }
    
    /// Stop the main app refresh timer
    private func stopMainAppRefresh() {
        mainAppRefreshTimer?.invalidate()
        mainAppRefreshTimer = nil
        logRefresh("Main app refresh stopped")
    }
    
    /// Set the main app refresh interval
    func setMainAppRefreshInterval(_ interval: TimeInterval) {
        mainAppRefreshInterval = interval
        UserDefaults.standard.set(interval, forKey: "MainAppRefreshInterval")
        
        if isMainAppVisible && mainAppRefreshEnabled {
            startMainAppRefresh() // Restart with new interval
        }
    }
    
    /// Force a refresh regardless of current state
    func forceRefresh() {
        logRefresh("AppStateManager: Force refresh requested")
        Task {
            await weatherService.fetchAllWeatherData(forceRefresh: true)
        }
    }
    
    /// Get current refresh status for display purposes
    func getRefreshStatus() -> (isMainAppRefreshing: Bool, isMenuBarRefreshing: Bool, refreshMode: String) {
        let isMainRefreshing = mainAppRefreshTimer?.isValid == true
        
        let mode: String
        if isMainAppVisible {
            mode = "Main App (Always Active)"
        } else {
            mode = "MenuBar Only"
        }
        
        return (isMainRefreshing, false, mode) // We can't directly access MenuBarManager
    }
}

// Add new notification names
extension Notification.Name {
    static let mainAppVisible = Notification.Name("mainAppVisible")
    static let mainAppHidden = Notification.Name("mainAppHidden")
}