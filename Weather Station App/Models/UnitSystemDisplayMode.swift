//
//  UnitSystemDisplayMode.swift
//  Weather Station App
//
//  Created by Curtis Netterville on 10/26/25.
//

import Foundation

enum UnitSystemDisplayMode: String, CaseIterable, Codable {
    case metric = "metric"
    case imperial = "imperial"
    case both = "both"
    
    var displayName: String {
        switch self {
        case .metric:
            return "Metric (°C, km/h, mm)"
        case .imperial:
            return "Imperial (°F, mph, in)"
        case .both:
            return "Both (°F / °C, mph / km/h)"
        }
    }
    
    var shortName: String {
        switch self {
        case .metric:
            return "Metric"
        case .imperial:
            return "Imperial"
        case .both:
            return "Both"
        }
    }
}

// UserDefaults extension for unit system preference
extension UserDefaults {
    var unitSystemDisplayMode: UnitSystemDisplayMode {
        get {
            if let rawValue = string(forKey: "UnitSystemDisplayMode"),
               let mode = UnitSystemDisplayMode(rawValue: rawValue) {
                return mode
            }
            return .both // Default to showing both
        }
        set {
            set(newValue.rawValue, forKey: "UnitSystemDisplayMode")
        }
    }
    
    var radarRefreshInterval: TimeInterval {
        get {
            let interval = double(forKey: "RadarRefreshInterval")
            return interval > 0 ? interval : 600.0 // Default to 10 minutes
        }
        set {
            set(newValue, forKey: "RadarRefreshInterval")
        }
    }
}