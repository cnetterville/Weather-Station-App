//
//  Logger.swift
//  Weather Station App
//
//  Centralized logging system that automatically disables in Release builds
//

import Foundation

enum LogLevel: String {
    case debug = "🔍"
    case info = "ℹ️"
    case warning = "⚠️"
    case error = "🛑"
    case success = "✅"
    case network = "📡"
    case data = "📊"
    case ui = "🎨"
    case refresh = "🔄"
    case memory = "💾"
    case weather = "🌤️"
    case temperature = "🌡️"
    case indoor = "🏠"
    case sensor = "📟"
    case chart = "📈"
    case lightning = "⚡"
    case location = "📍"
    case timer = "⏱️"
    case camera = "📷"
}

class Logger {
    static let shared = Logger()
    
    // Automatically disabled in Release builds
    private var isLoggingEnabled: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
    
    // Optional: Runtime control for specific log levels
    private var enabledLevels: Set<LogLevel> = []
    
    private init() {
        #if DEBUG
        // In debug mode, enable all levels by default
        enabledLevels = Set(LogLevel.allCases)
        #endif
    }
    
    // MARK: - Main Logging Methods
    
    func log(_ message: String, level: LogLevel = .info, file: String = #file, function: String = #function, line: Int = #line) {
        guard isLoggingEnabled else { return }
        guard enabledLevels.contains(level) else { return }
        
        _ = (file as NSString).lastPathComponent
        let output = "\(level.rawValue) \(message)"
        
        print(output)
    }
    
    // MARK: - Convenience Methods
    
    func debug(_ message: String) {
        log(message, level: .debug)
    }
    
    func info(_ message: String) {
        log(message, level: .info)
    }
    
    func warning(_ message: String) {
        log(message, level: .warning)
    }
    
    func error(_ message: String) {
        log(message, level: .error)
    }
    
    func success(_ message: String) {
        log(message, level: .success)
    }
    
    func network(_ message: String) {
        log(message, level: .network)
    }
    
    func data(_ message: String) {
        log(message, level: .data)
    }
    
    func ui(_ message: String) {
        log(message, level: .ui)
    }
    
    func refresh(_ message: String) {
        log(message, level: .refresh)
    }
    
    func memory(_ message: String) {
        log(message, level: .memory)
    }
    
    func weather(_ message: String) {
        log(message, level: .weather)
    }
    
    func temperature(_ message: String) {
        log(message, level: .temperature)
    }
    
    func indoor(_ message: String) {
        log(message, level: .indoor)
    }
    
    func sensor(_ message: String) {
        log(message, level: .sensor)
    }
    
    func chart(_ message: String) {
        log(message, level: .chart)
    }
    
    func lightning(_ message: String) {
        log(message, level: .lightning)
    }
    
    func location(_ message: String) {
        log(message, level: .location)
    }
    
    func timer(_ message: String) {
        log(message, level: .timer)
    }
    
    func camera(_ message: String) {
        log(message, level: .camera)
    }
    
    // MARK: - Configuration
    
    func enable(level: LogLevel) {
        enabledLevels.insert(level)
    }
    
    func disable(level: LogLevel) {
        enabledLevels.remove(level)
    }
    
    func enableAll() {
        enabledLevels = Set(LogLevel.allCases)
    }
    
    func disableAll() {
        enabledLevels = []
    }
}

// MARK: - LogLevel CaseIterable

extension LogLevel: CaseIterable {}

// MARK: - Global Convenience Functions

/// Log a debug message (automatically disabled in Release)
func logDebug(_ message: String) {
    Logger.shared.debug(message)
}

/// Log an info message (automatically disabled in Release)
func logInfo(_ message: String) {
    Logger.shared.info(message)
}

/// Log a warning message (automatically disabled in Release)
func logWarning(_ message: String) {
    Logger.shared.warning(message)
}

/// Log an error message (automatically disabled in Release)
func logError(_ message: String) {
    Logger.shared.error(message)
}

/// Log a success message (automatically disabled in Release)
func logSuccess(_ message: String) {
    Logger.shared.success(message)
}

/// Log a network message (automatically disabled in Release)
func logNetwork(_ message: String) {
    Logger.shared.network(message)
}

/// Log a data message (automatically disabled in Release)
func logData(_ message: String) {
    Logger.shared.data(message)
}

/// Log a UI message (automatically disabled in Release)
func logUI(_ message: String) {
    Logger.shared.ui(message)
}

/// Log a refresh message (automatically disabled in Release)
func logRefresh(_ message: String) {
    Logger.shared.refresh(message)
}

/// Log a memory message (automatically disabled in Release)
func logMemory(_ message: String) {
    Logger.shared.memory(message)
}

/// Log a weather message (automatically disabled in Release)
func logWeather(_ message: String) {
    Logger.shared.weather(message)
}

/// Log a temperature message (automatically disabled in Release)
func logTemperature(_ message: String) {
    Logger.shared.temperature(message)
}

/// Log an indoor message (automatically disabled in Release)
func logIndoor(_ message: String) {
    Logger.shared.indoor(message)
}

/// Log a sensor message (automatically disabled in Release)
func logSensor(_ message: String) {
    Logger.shared.sensor(message)
}

/// Log a chart message (automatically disabled in Release)
func logChart(_ message: String) {
    Logger.shared.chart(message)
}

/// Log a lightning message (automatically disabled in Release)
func logLightning(_ message: String) {
    Logger.shared.lightning(message)
}

/// Log a location message (automatically disabled in Release)
func logLocation(_ message: String) {
    Logger.shared.location(message)
}

/// Log a timer message (automatically disabled in Release)
func logTimer(_ message: String) {
    Logger.shared.timer(message)
}

/// Log a camera message (automatically disabled in Release)
func logCamera(_ message: String) {
    Logger.shared.camera(message)
}
