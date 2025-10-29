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
    @State private var lastRefreshTime = Date()
    @State private var nextRefreshTime = Date()
    @State private var radarRefreshInterval: TimeInterval = 600 // Default 10 minutes
    @State private var countdownTrigger = 0 // Force UI updates
    @State private var initialLoadDelayTask: Task<Void, Never>? // Track initial load task
    @State private var hasInitiallyLoaded = false // Track if we've done the initial load
    
    // Calculate a unique delay for this station's radar based on MAC address
    private var initialLoadDelay: TimeInterval {
        // Use the station's MAC address to create a consistent but unique delay
        let hash = abs(station.macAddress.hashValue)
        // Create delays between 0-10 seconds, spaced by 2-second intervals
        return Double(hash % 5) * 2.0
    }
    
    private var radarHTML: String {
        guard let latitude = station.latitude,
              let longitude = station.longitude else {
            // Default coordinates (center of US)
            return generateRadarHTML(lat: 39.83, lon: -98.58)
        }
        
        return generateRadarHTML(lat: latitude, lon: longitude)
    }
    
    private func generateRadarHTML(lat: Double, lon: Double) -> String {
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
                    background-color: #f0f0f0;
                    font-family: -apple-system, BlinkMacSystemFont, 'Segui UI', sans-serif;
                    height: 100vh;
                    overflow: hidden;
                }
            </style>
        </head>
        <body>
            <div style="display:block!important;position:relative!important;width:100%!important;margin:auto!important;padding:0!important;border:0!important">
                <div style="display:block!important;position:relative!important;width:100%!important;height:0!important;box-sizing:content-box!important;margin:0!important;border:0!important;padding:0 0 61.794%!important;left:0!important;top:0!important;right:0!important;bottom:0!important">
                    <iframe 
                        src="https://embed.ventusky.com/?p=\(lat);\(lon);7&l=radar&t=\(Int(Date().timeIntervalSince1970))" 
                        style="display:block!important;position:absolute!important;left:0!important;top:0!important;width:100%!important;height:100%!important;margin:0!important;padding:0!important;border:0!important;border-radius:8px!important;right:auto!important;bottom:auto!important" 
                        loading="lazy">
                    </iframe>
                </div>
            </div>
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
                    .frame(height: 160) // Reduced height to eliminate white space
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
                        .frame(height: 160) // Reduced height to eliminate white space
                        .cornerRadius(8)
                        
                        // Loading overlay
                        if isLoading {
                            Rectangle()
                                .fill(Color(NSColor.controlBackgroundColor))
                                .frame(height: 160)
                                .cornerRadius(8)
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
                        
                        // Auto-refresh status overlay - positioned in top-right corner
                        if !hasError && !isLoading {
                            VStack {
                                HStack {
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 2) {
                                        HStack(spacing: 4) {
                                            Circle()
                                                .fill(Color.green)
                                                .frame(width: 5, height: 5)
                                            Text("Auto")
                                                .font(.caption2)
                                                .fontWeight(.medium)
                                        }
                                        Text("\(timeUntilNextRefresh())")
                                            .font(.caption2)
                                            .fontWeight(.medium)
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Color.black.opacity(0.7))
                                    .cornerRadius(6)
                                    .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                                }
                                .padding(.trailing, 8)
                                .padding(.top, 30) // Adjusted for new layout
                                
                                Spacer()
                            }
                        }
                    }
                    
                    // Control bar
                    HStack {
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
                    .padding(.top, 4)
                }
            }
        }
        .onAppear {
            radarRefreshInterval = UserDefaults.standard.radarRefreshInterval
            
            // Start initial load with staggered delay to prevent all radars loading simultaneously
            initialLoadDelayTask = Task {
                do {
                    try await Task.sleep(nanoseconds: UInt64(initialLoadDelay * 1_000_000_000))
                    
                    // Check if view is still active before loading
                    guard !Task.isCancelled else { return }
                    
                    await MainActor.run {
                        loadRadar()
                        hasInitiallyLoaded = true
                        startAutoRefreshTimer()
                        startCountdownTimer()
                    }
                } catch {
                    // Task was cancelled, no need to load
                    return
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
                    
                    // Restart timer with new interval
                    stopAutoRefreshTimer()
                    startAutoRefreshTimer()
                }
            }
        }
        .onDisappear {
            // Cancel any pending initial load task
            initialLoadDelayTask?.cancel()
            initialLoadDelayTask = nil
            
            stopAutoRefreshTimer()
            stopCountdownTimer()
            NotificationCenter.default.removeObserver(self, name: .radarSettingsChanged, object: nil)
        }
    }
    
    private func loadRadar() {
        guard station.latitude != nil && station.longitude != nil else {
            hasError = true
            isLoading = false
            return
        }
        
        // Only set loading state if this isn't the initial delayed load
        if hasInitiallyLoaded {
            isLoading = true
        }
        
        hasError = false
        lastRefreshTime = Date()
        nextRefreshTime = Date().addingTimeInterval(radarRefreshInterval)
        
        // WebView will handle the actual loading through the delegate
    }
    
    private func refreshRadar() {
        isLoading = true
        hasError = false
        lastRefreshTime = Date()
        nextRefreshTime = Date().addingTimeInterval(radarRefreshInterval)
        
        // Regenerate HTML with new timestamp and reload
        let newHTML = radarHTML
        webView?.loadHTMLString(newHTML, baseURL: URL(string: "https://embed.ventusky.com"))
        
        // Reset the auto-refresh timer
        stopAutoRefreshTimer()
        startAutoRefreshTimer()
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
            if let url = URL(string: "https://www.ventusky.com/?p=39.83;-98.58;4&l=radar") {
                NSWorkspace.shared.open(url)
            }
            return
        }
        
        let fullURL = "https://www.ventusky.com/?p=\(latitude);\(longitude);8&l=radar"
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
        
        // Load the HTML content
        webView.loadHTMLString(htmlContent, baseURL: URL(string: "https://embed.ventusky.com"))
        
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        // Only reload if content has changed significantly
        // This prevents constant reloading
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
            DispatchQueue.main.async {
                // Small delay to ensure the iframe content has loaded
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.parent.isLoading = false
                    self.parent.hasError = false
                }
            }
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