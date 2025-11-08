//
//  LaunchAtLoginHelper.swift
//  Weather Station App
//
//  Created by Curtis Netterville on 10/25/25.
//

import Foundation
import ServiceManagement
import Combine

@MainActor
class LaunchAtLoginHelper: ObservableObject {
    static let shared = LaunchAtLoginHelper()
    
    @Published var isEnabled: Bool {
        didSet {
            if oldValue != isEnabled {
                setLaunchAtLogin(isEnabled)
            }
        }
    }
    
    private init() {
        self.isEnabled = Self.checkLaunchAtLoginStatus()
    }
    
    private static func checkLaunchAtLoginStatus() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        } else {
            // Fallback for older macOS versions
            return UserDefaults.standard.bool(forKey: "launchAtLogin")
        }
    }
    
    private func setLaunchAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    if SMAppService.mainApp.status == .enabled {
                        logSuccess("Launch at login already enabled")
                    } else {
                        try SMAppService.mainApp.register()
                        logSuccess("Launch at login enabled")
                    }
                } else {
                    if SMAppService.mainApp.status == .enabled {
                        try SMAppService.mainApp.unregister()
                        logSuccess("Launch at login disabled")
                    }
                }
                UserDefaults.standard.set(enabled, forKey: "launchAtLogin")
            } catch {
                logError("Failed to set launch at login: \(error.localizedDescription)")
                // Revert the change if it failed
                DispatchQueue.main.async {
                    self.isEnabled = !enabled
                }
            }
        } else {
            // Fallback for older macOS versions
            UserDefaults.standard.set(enabled, forKey: "launchAtLogin")
            logWarning("Launch at login setting saved, but requires macOS 13.0+ for full functionality")
        }
    }
    
    func refreshStatus() {
        let currentStatus = Self.checkLaunchAtLoginStatus()
        if currentStatus != isEnabled {
            isEnabled = currentStatus
        }
    }
}