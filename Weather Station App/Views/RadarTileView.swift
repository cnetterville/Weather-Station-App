//
//  RadarTileView.swift
//  Weather Station App
//
//  Created by Curtis Netterville on 10/25/25.
//

import SwiftUI
import WebKit

struct RadarTileView: View {
    let station: WeatherStation
    let onTitleChange: (String) -> Void
    
    @State private var webView: WKWebView?
    @State private var isLoading = true
    @State private var hasError = false
    @State private var autoRefreshTimer: Timer?
    @State private var countdownTimer: Timer?
    @State private var loadingTimeoutTimer: Timer?
    @State private var lastRefreshTime = Date()
    @State private var nextRefreshTime = Date()
    @State private var radarRefreshInterval: TimeInterval = 600
    @State private var countdownTrigger = 0
    @State private var initialLoadDelayTask: Task<Void, Never>?
    @State private var hasInitiallyLoaded = false
    @State private var loadAttempts = 0
    @State private var currentStationId: String = ""
    
    // Calculate a unique delay for this station's radar based on MAC address
    private var initialLoadDelay: TimeInterval {
        let hash = abs(station.macAddress.hashValue)
        return Double(hash % 5) * 2.0
    }
    
    private var radarHTML: String {
        guard let latitude = station.latitude,
              let longitude = station.longitude else {
            return generateWindyRadarHTML(lat: 39.83, lon: -98.58)
        }
        
        return generateWindyRadarHTML(lat: latitude, lon: longitude)
    }
    
    private func generateWindyRadarHTML(lat: Double, lon: Double) -> String {
        let zoom = 9
        let timestamp = Int(Date().timeIntervalSince1970)
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                body { 
                    margin: 0; 
                    padding: 0; 
                    background-color: #0f1419;
                    font-family: -apple-system, BlinkMacSystemFont, 'Segui UI', sans-serif;
                    height: 100vh;
                    overflow: hidden;
                }
                iframe {
                    width: 100%;
                    height: 100%;
                    border: none;
                    border-radius: 12px;
                }
            </style>
        </head>
        <body>
            <iframe 
                src="https://embed.windy.com/embed2.html?lat=\(lat)&lon=\(lon)&detailLat=\(lat)&detailLon=\(lon)&width=100%&height=100%&zoom=\(zoom)&level=surface&overlay=rain&product=ecmwf&menu=&message=&marker=&calendar=now&pressure=&type=map&location=coordinates&detail=&metricWind=mph&metricTemp=°F&radarRange=-1&timestamp=\(timestamp)"
                frameborder="0">
            </iframe>
        </body>
        </html>
        """
    }
    
    var body: some View {
        EditableWeatherCard(
            title: .constant(station.customLabels.radar),
            systemImage: "cloud.rain.fill",
            onTitleChange: onTitleChange
        ) {
            VStack(spacing: 8) {
                if hasError {
                    // Error state
                    VStack(spacing: 12) {
                        Image(systemName: "wifi.exclamationmark")
                            .font(.system(size: 32))
                            .foregroundColor(.orange)
                        
                        Text("Radar Unavailable")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        if station.latitude == nil || station.longitude == nil {
                            Text("Station coordinates required for radar")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        } else {
                            Text("Unable to load radar data")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        Button("Try Again") {
                            hasError = false
                            isLoading = true
                            loadRadar()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 280)
                } else {
                    // Radar content
                    ZStack {
                        // WebKit view for radar
                        RadarWebView(
                            htmlContent: radarHTML,
                            webView: $webView,
                            isLoading: $isLoading,
                            hasError: $hasError
                        )
                        .frame(height: 280)
                        .cornerRadius(12)
                        .id("radar-\(station.macAddress)")
                        
                        // Loading overlay
                        if isLoading {
                            Rectangle()
                                .fill(Color(NSColor.controlBackgroundColor))
                                .frame(height: 280)
                                .cornerRadius(12)
                                .overlay(
                                    VStack(spacing: 12) {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                        Text("Loading radar...")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                )
                        }
                    }
                    
                    // Clean control bar - just status and action buttons
                    HStack {
                        // Auto-refresh status
                        if !hasError && !isLoading {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 5, height: 5)
                                Text("Auto \(timeUntilNextRefresh())")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Button("Refresh") {
                            refreshRadar()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                        
                        Button("Open Full") {
                            openFullRadar()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.mini)
                    }
                    .padding(.top, 6)
                }
            }
        }
        .onAppear {
            radarRefreshInterval = UserDefaults.standard.radarRefreshInterval
            
            // Check if station has changed
            let stationChanged = currentStationId != station.macAddress
            if stationChanged {
                currentStationId = station.macAddress
                hasInitiallyLoaded = false
                loadAttempts = 0
                print("Station changed to: \(station.name)")
            }
            
            // Only start initial load if not already loaded for this station
            if !hasInitiallyLoaded {
                initialLoadDelayTask = Task {
                    do {
                        try await Task.sleep(nanoseconds: UInt64(initialLoadDelay * 1_000_000_000))
                        guard !Task.isCancelled else { return }
                        
                        await MainActor.run {
                            loadRadar()
                            hasInitiallyLoaded = true
                            startAutoRefreshTimer()
                            startCountdownTimer()
                        }
                    } catch {
                        return
                    }
                }
            }
            
            // Listen for settings changes
            NotificationCenter.default.addObserver(
                forName: .radarSettingsChanged,
                object: nil,
                queue: .main
            ) { notification in
                if let newInterval = notification.object as? TimeInterval {
                    radarRefreshInterval = newInterval
                    nextRefreshTime = lastRefreshTime.addingTimeInterval(radarRefreshInterval)
                    
                    stopAutoRefreshTimer()
                    startAutoRefreshTimer()
                }
            }
        }
        .onDisappear {
            initialLoadDelayTask?.cancel()
            initialLoadDelayTask = nil
            
            stopAutoRefreshTimer()
            stopCountdownTimer()
            stopLoadingTimeout()
            NotificationCenter.default.removeObserver(self, name: .radarSettingsChanged, object: nil)
        }
    }
    
    private func loadRadar() {
        guard station.latitude != nil && station.longitude != nil else {
            hasError = true
            isLoading = false
            return
        }
        
        if hasInitiallyLoaded {
            isLoading = true
        }
        
        hasError = false
        lastRefreshTime = Date()
        nextRefreshTime = Date().addingTimeInterval(radarRefreshInterval)
        loadAttempts += 1
        
        // Start a simple timeout
        startLoadingTimeout()
    }
    
    private func refreshRadar() {
        isLoading = true
        hasError = false
        lastRefreshTime = Date()
        nextRefreshTime = Date().addingTimeInterval(radarRefreshInterval)
        loadAttempts = 0
        
        startLoadingTimeout()
        
        // Force reload by recreating the WebView
        let newHTML = radarHTML
        webView?.loadHTMLString(newHTML, baseURL: URL(string: "https://embed.windy.com"))
        
        stopAutoRefreshTimer()
        startAutoRefreshTimer()
    }
    
    private func startLoadingTimeout() {
        stopLoadingTimeout()
        
        loadingTimeoutTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { _ in
            DispatchQueue.main.async {
                if isLoading {
                    print("Radar loading timeout - clearing loading state")
                    isLoading = false
                }
            }
        }
    }
    
    private func stopLoadingTimeout() {
        loadingTimeoutTimer?.invalidate()
        loadingTimeoutTimer = nil
    }
    
    private func startAutoRefreshTimer() {
        stopAutoRefreshTimer() // Ensure no duplicate timers
        
        autoRefreshTimer = Timer.scheduledTimer(withTimeInterval: radarRefreshInterval, repeats: true) { _ in
            DispatchQueue.main.async {
                if !hasError {
                    refreshRadar()
                }
            }
        }
    }
    
    private func stopAutoRefreshTimer() {
        autoRefreshTimer?.invalidate()
        autoRefreshTimer = nil
    }
    
    private func startCountdownTimer() {
        stopCountdownTimer() // Ensure no duplicate timers
        
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            DispatchQueue.main.async {
                // Trigger UI update by changing state
                countdownTrigger += 1
            }
        }
    }
    
    private func stopCountdownTimer() {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }
    
    private func timeUntilNextRefresh() -> String {
        let _ = countdownTrigger // Reference the trigger to force UI updates
        let timeRemaining = nextRefreshTime.timeIntervalSince(Date())
        
        if timeRemaining <= 0 {
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
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func openFullRadar() {
        guard let latitude = station.latitude, let longitude = station.longitude else {
            // Open default location if no coordinates
            let defaultURL = "https://www.windy.com/?radar,39.83,-98.58,6"
            
            if let url = URL(string: defaultURL) {
                NSWorkspace.shared.open(url)
            }
            return
        }
        
        let fullURL = "https://www.windy.com/?radar,\(latitude),\(longitude),9"
        
        if let url = URL(string: fullURL) {
            NSWorkspace.shared.open(url)
        }
    }
}

struct RadarWebView: NSViewRepresentable {
    let htmlContent: String
    @Binding var webView: WKWebView?
    @Binding var isLoading: Bool
    @Binding var hasError: Bool
    
    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsMagnification = false
        
        DispatchQueue.main.async {
            self.webView = webView
        }
        
        webView.loadHTMLString(htmlContent, baseURL: URL(string: "https://embed.windy.com"))
        
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        // Don't reload constantly - let the .id() modifier handle station changes
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: RadarWebView
        
        init(_ parent: RadarWebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = true
                self.parent.hasError = false
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Give iframe time to load, then clear loading state
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                self.parent.isLoading = false
                self.parent.hasError = false
            }
            print("Radar WebView didFinish navigation - iframe should load in 3 seconds")
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.hasError = true
            }
            print("Radar WebView failed to load: \(error.localizedDescription)")
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.hasError = true
            }
            print("Radar WebView failed provisional navigation: \(error.localizedDescription)")
        }
    }
}

#Preview {
    RadarTileView(
        station: WeatherStation(
            name: "Test Station", 
            macAddress: "00:00:00:00:00:00"
        )
    ) { _ in }
}