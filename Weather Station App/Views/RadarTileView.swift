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
    @State private var showSatelliteOverlay = false // Start with radar only
    @State private var useWindyRadar = true // Default to Windy instead of Ventusky
    
    // Calculate a unique delay for this station's radar based on MAC address
    private var initialLoadDelay: TimeInterval {
        let hash = abs(station.macAddress.hashValue)
        return Double(hash % 5) * 2.0
    }
    
    private var radarHTML: String {
        guard let latitude = station.latitude,
              let longitude = station.longitude else {
            return useWindyRadar ?
                generateWindyRadarHTML(lat: 39.83, lon: -98.58) :
                generateVentuskyRadarHTML(lat: 39.83, lon: -98.58)
        }
        
        return useWindyRadar ?
            generateWindyRadarHTML(lat: latitude, lon: longitude) :
            generateVentuskyRadarHTML(lat: latitude, lon: longitude)
    }
    
    private func generateWindyRadarHTML(lat: Double, lon: Double) -> String {
        let zoom = 8
        let overlay = showSatelliteOverlay ? "radar,satellite" : "radar"
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
                    border-radius: 8px;
                }
            </style>
        </head>
        <body>
            <iframe 
                src="https://embed.windy.com/embed2.html?lat=\(lat)&lon=\(lon)&detailLat=\(lat)&detailLon=\(lon)&width=100%&height=100%&zoom=\(zoom)&level=surface&overlay=\(overlay)&product=ecmwf&menu=&message=&marker=&calendar=now&pressure=&type=map&location=coordinates&detail=&metricWind=mph&metricTemp=°F&radarRange=-1&timestamp=\(timestamp)"
                frameborder="0">
            </iframe>
        </body>
        </html>
        """
    }
    
    private func generateVentuskyRadarHTML(lat: Double, lon: Double) -> String {
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
            <script>
                // Simple timeout to clear loading state
                setTimeout(function() {
                    console.log('Radar iframe should be loaded by now');
                }, 5000);
            </script>
        </body>
        </html>
        """
    }
    
    // Alternative method with satellite overlay option
    private func generateWindyRadarWithSatelliteHTML(lat: Double, lon: Double, showSatellite: Bool = true) -> String {
        let zoom = 8
        let baseLayer = showSatellite ? "satellite" : "wind"
        let overlay = "radar"
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
                    background-color: #1a1a2e;
                    font-family: -apple-system, BlinkMacSystemFont, 'Segui UI', sans-serif;
                    height: 100vh;
                    overflow: hidden;
                }
                iframe {
                    width: 100%;
                    height: 100%;
                    border: none;
                    border-radius: 8px;
                }
            </style>
        </head>
        <body>
            <iframe 
                src="https://embed.windy.com/embed2.html?lat=\(lat)&lon=\(lon)&detailLat=\(lat)&detailLon=\(lon)&width=100%&height=100%&zoom=\(zoom)&level=surface&overlay=\(overlay)&product=ecmwf&menu=&message=true&marker=dot&calendar=now&pressure=&type=map&location=coordinates&detail=&metricWind=mph&metricTemp=°F&radarRange=-1&timestamp=\(timestamp)&layer=\(baseLayer)"
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
                    .frame(height: 160)
                } else {
                    // Radar content
                    ZStack {
                        // WebKit view for radar - only use station ID to force recreation on station change
                        RadarWebView(
                            htmlContent: radarHTML,
                            webView: $webView,
                            isLoading: $isLoading,
                            hasError: $hasError
                        )
                        .frame(height: 160)
                        .cornerRadius(8)
                        .id("radar-\(station.macAddress)")
                        
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
                        
                        // Auto-refresh status overlay
                        if !hasError && !isLoading {
                            VStack {
                                Spacer()
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
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
                                    
                                    Spacer()
                                }
                                .padding(.leading, 8)
                                .padding(.bottom, 8)
                            }
                        }
                    }
                    
                    // Control bar
                    VStack(spacing: 4) {
                        // First row - Provider and satellite toggle
                        HStack {
                            // Provider toggle
                            Picker("Radar Source", selection: $useWindyRadar) {
                                Text("Ventusky").tag(false)
                                Text("Windy").tag(true)
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .controlSize(.mini)
                            
                            if useWindyRadar {
                                Toggle("Satellite", isOn: $showSatelliteOverlay)
                                    .controlSize(.mini)
                                    .toggleStyle(.checkbox)
                            }
                            
                            Spacer()
                        }
                        
                        // Second row - Action buttons
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
                    }
                    .padding(.top, 4)
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
        .onChange(of: useWindyRadar) { _, _ in
            refreshRadar()
        }
        .onChange(of: showSatelliteOverlay) { _, _ in
            if useWindyRadar {
                refreshRadar()
            }
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
        webView?.loadHTMLString(newHTML, baseURL: URL(string: "https://embed.ventusky.com"))
        
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
            // Open default location if no coordinates - default to Windy
            let defaultURL = useWindyRadar ? 
                "https://www.windy.com/?radar,39.83,-98.58,5" :
                "https://www.ventusky.com/?p=39.83;-98.58;4&l=radar"
            
            if let url = URL(string: defaultURL) {
                NSWorkspace.shared.open(url)
            }
            return
        }
        
        let fullURL: String
        if useWindyRadar {
            let layers = showSatelliteOverlay ? "radar,satellite" : "radar"
            fullURL = "https://www.windy.com/?\(layers),\(latitude),\(longitude),8"
        } else {
            fullURL = "https://www.ventusky.com/?p=\(latitude);\(longitude);8&l=radar"
        }
        
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
        
        webView.loadHTMLString(htmlContent, baseURL: URL(string: "https://embed.ventusky.com"))
        
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