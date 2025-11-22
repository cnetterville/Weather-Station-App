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
    @State private var loadingTimeoutTimer: Timer?
    @State private var lastRefreshTime = Date()
    @State private var initialLoadDelayTask: Task<Void, Never>?
    @State private var hasInitiallyLoaded = false
    @State private var loadAttempts = 0
    @State private var currentStationId: String = ""
    @State private var isRefreshing = false
    @State private var notificationObserver: NSObjectProtocol?
    
    @StateObject private var radarRefreshManager = RadarRefreshManager.shared
    @State private var refreshTrigger = 0
    
    // Access to all stations for marking on map
    @ObservedObject private var weatherService = WeatherStationService.shared
    
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
        
        // Collect all stations with coordinates for creating markers
        let stationsWithCoords = weatherService.weatherStations.compactMap { station -> (name: String, lat: Double, lon: Double, isCurrent: Bool)? in
            guard let stationLat = station.latitude,
                  let stationLon = station.longitude else {
                return nil
            }
            return (
                name: station.name,
                lat: stationLat,
                lon: stationLon,
                isCurrent: station.macAddress == self.station.macAddress
            )
        }
        
        // Create marker overlay HTML
        let markersHTML = stationsWithCoords.enumerated().map { index, station in
            let color = station.isCurrent ? "#3b82f6" : "#10b981" // Blue for current, green for others
            let size = station.isCurrent ? "10" : "7"
            let zIndex = station.isCurrent ? "10002" : "10001"
            
            return """
                <div class="station-marker" 
                     id="marker-\(index)"
                     data-lat="\(station.lat)" 
                     data-lon="\(station.lon)"
                     data-name="\(station.name)"
                     style="
                         width: \(size)px; 
                         height: \(size)px; 
                         background: \(color);
                         z-index: \(zIndex);
                     ">
                </div>
            """
        }.joined(separator: "\n            ")
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                * {
                    margin: 0;
                    padding: 0;
                    box-sizing: border-box;
                }
                
                body { 
                    margin: 0; 
                    padding: 0; 
                    background-color: #0f1419;
                    font-family: -apple-system, BlinkMacSystemFont, 'Segui UI', sans-serif;
                    height: 100vh;
                    overflow: hidden;
                    position: relative;
                }
                
                #iframe-container {
                    position: relative;
                    width: 100%;
                    height: 100%;
                }
                
                iframe {
                    position: absolute;
                    top: 0;
                    left: 0;
                    width: 100%;
                    height: 100%;
                    border: none;
                    border-radius: 12px;
                }
                
                #marker-overlay {
                    position: absolute;
                    top: 0;
                    left: 0;
                    width: 100%;
                    height: 100%;
                    pointer-events: none;
                    z-index: 10000;
                }
                
                .station-marker {
                    position: absolute;
                    border-radius: 50%;
                    border: 2px solid white;
                    box-shadow: 0 2px 6px rgba(0,0,0,0.5), 0 0 0 1px rgba(0,0,0,0.2);
                    pointer-events: none;
                    transform: translate(-50%, -50%);
                    transition: none;
                }
            </style>
            <script>
                let loadingComplete = false;
                let mapCenter = { lat: \(lat), lon: \(lon) };
                let mapZoom = \(zoom);
                let containerWidth = 0;
                let containerHeight = 0;
                let markersVisible = true;
                
                // Mercator projection helpers
                function latToY(lat) {
                    const latRad = lat * Math.PI / 180;
                    return Math.log(Math.tan(Math.PI / 4 + latRad / 2));
                }
                
                function lonToX(lon) {
                    return lon * Math.PI / 180;
                }
                
                function latLonToPixel(lat, lon) {
                    const scale = 256 * Math.pow(2, mapZoom) / (2 * Math.PI);
                    
                    const centerX = lonToX(mapCenter.lon) * scale;
                    const centerY = latToY(mapCenter.lat) * scale;
                    
                    const pointX = lonToX(lon) * scale;
                    const pointY = latToY(lat) * scale;
                    
                    return {
                        x: containerWidth / 2 + (pointX - centerX),
                        y: containerHeight / 2 + (centerY - pointY)
                    };
                }
                
                function hideMarkers() {
                    if (markersVisible) {
                        const overlay = document.getElementById('marker-overlay');
                        if (overlay) {
                            overlay.style.opacity = '0';
                            overlay.style.transition = 'opacity 0.3s ease-out';
                            markersVisible = false;
                            console.log('Markers hidden due to map interaction');
                        }
                    }
                }
                
                function showMarkers() {
                    if (!markersVisible) {
                        const overlay = document.getElementById('marker-overlay');
                        if (overlay) {
                            overlay.style.opacity = '1';
                            overlay.style.transition = 'opacity 0.3s ease-in';
                            markersVisible = true;
                            console.log('Markers shown');
                        }
                    }
                }
                
                function updateMarkerPositions() {
                    const markers = document.querySelectorAll('.station-marker');
                    markers.forEach(marker => {
                        const lat = parseFloat(marker.getAttribute('data-lat'));
                        const lon = parseFloat(marker.getAttribute('data-lon'));
                        
                        const pos = latLonToPixel(lat, lon);
                        marker.style.left = pos.x + 'px';
                        marker.style.top = pos.y + 'px';
                    });
                }
                
                function updateContainerSize() {
                    const container = document.getElementById('iframe-container');
                    if (container) {
                        containerWidth = container.offsetWidth;
                        containerHeight = container.offsetHeight;
                        updateMarkerPositions();
                    }
                }
                
                function setupMapInteractionDetection() {
                    const iframe = document.querySelector('iframe');
                    if (!iframe) return;
                    
                    let interactionTimeout;
                    
                    // Detect when mouse enters iframe (potential interaction)
                    iframe.addEventListener('mouseenter', function() {
                        // Give a small delay before hiding in case it's just passing through
                        interactionTimeout = setTimeout(hideMarkers, 500);
                    });
                    
                    // Detect when mouse leaves iframe
                    iframe.addEventListener('mouseleave', function() {
                        clearTimeout(interactionTimeout);
                        // Don't show markers again automatically
                        // They'll only show on refresh
                    });
                    
                    // Detect mouse wheel (zoom) over iframe
                    iframe.addEventListener('wheel', function() {
                        hideMarkers();
                    }, { passive: true });
                }
                
                function onIframeLoad() {
                    loadingComplete = true;
                    
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.radarLoaded) {
                        window.webkit.messageHandlers.radarLoaded.postMessage('loaded');
                    }
                    console.log('Radar iframe loaded');
                    
                    updateContainerSize();
                    showMarkers();
                    
                    // Setup interaction detection
                    setupMapInteractionDetection();
                    
                    // Listen for messages from Windy iframe about map movements (if available)
                    window.addEventListener('message', function(event) {
                        if (event.data && event.data.type === 'mapMove') {
                            hideMarkers();
                        }
                    });
                }
                
                function refreshRadarIframe() {
                    const iframe = document.querySelector('iframe');
                    if (iframe) {
                        const currentSrc = iframe.src;
                        const newTimestamp = Math.floor(Date.now() / 1000);
                        const newSrc = currentSrc.replace(/timestamp=\\d+/, 'timestamp=' + newTimestamp);
                        console.log('Refreshing iframe with new timestamp:', newTimestamp);
                        iframe.src = newSrc;
                        
                        setTimeout(function() {
                            updateContainerSize();
                            showMarkers();
                        }, 1000);
                    }
                }
                
                // Update on window resize
                window.addEventListener('resize', updateContainerSize);
                
                // Initial positioning after short delay
                setTimeout(updateContainerSize, 500);
                
                setTimeout(function() {
                    if (!loadingComplete) {
                        console.log('Radar loading timeout - forcing completion');
                        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.radarLoaded) {
                            window.webkit.messageHandlers.radarLoaded.postMessage('timeout');
                        }
                    }
                }, 8000);
            </script>
        </head>
        <body>
            <div id="iframe-container">
                <iframe 
                    src="https://embed.windy.com/embed2.html?lat=\(lat)&lon=\(lon)&detailLat=\(lat)&detailLon=\(lon)&width=100%&height=100%&zoom=\(zoom)&level=surface&overlay=radar&product=ecmwf&menu=&message=&marker=&calendar=now&pressure=&type=map&location=coordinates&detail=&metricWind=mph&metricTemp=°F&radarRange=-1&timestamp=\(timestamp)"
                    frameborder="0"
                    onload="onIframeLoad()">
                </iframe>
                <div id="marker-overlay">
                    \(markersHTML)
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
                    ZStack {
                        RadarWebView(
                            htmlContent: radarHTML,
                            webView: $webView,
                            isLoading: $isLoading,
                            hasError: $hasError
                        )
                        .frame(height: 280)
                        .cornerRadius(12)
                        .id("radar-\(station.macAddress)")
                        
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
                    
                    HStack {
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
            let stationChanged = currentStationId != station.macAddress
            if stationChanged {
                currentStationId = station.macAddress
                hasInitiallyLoaded = false
                loadAttempts = 0
                print("Station changed to: \(station.name)")
            }
            
            if !hasInitiallyLoaded {
                initialLoadDelayTask = Task {
                    do {
                        try await Task.sleep(nanoseconds: UInt64(initialLoadDelay * 1_000_000_000))
                        guard !Task.isCancelled else { return }
                        
                        await MainActor.run {
                            loadRadar()
                            hasInitiallyLoaded = true
                            radarRefreshManager.startTracking(stationId: station.macAddress)
                        }
                    } catch {
                        return
                    }
                }
            } else {
                radarRefreshManager.startTracking(stationId: station.macAddress)
            }
            
            if let observer = notificationObserver {
                NotificationCenter.default.removeObserver(observer)
                notificationObserver = nil
            }
            
            notificationObserver = NotificationCenter.default.addObserver(
                forName: .radarRefreshTriggered,
                object: nil,
                queue: .main
            ) { notification in
                if let triggeredStationId = notification.object as? String,
                   triggeredStationId == station.macAddress {
                    autoRefreshRadar()
                }
            }
        }
        .onDisappear {
            initialLoadDelayTask?.cancel()
            initialLoadDelayTask = nil
            
            stopLoadingTimeout()
            radarRefreshManager.stopTracking(stationId: station.macAddress)
            
            if let observer = notificationObserver {
                NotificationCenter.default.removeObserver(observer)
                notificationObserver = nil
            }
        }
        .onChange(of: radarRefreshManager.getRefreshState(for: station.macAddress)?.timeRemaining) { 
            refreshTrigger += 1
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
        loadAttempts += 1
        
        startLoadingTimeout()
    }
    
    private func refreshRadar() {
        guard !isRefreshing else { return }
        isRefreshing = true
        
        print("🔄 Manual radar refresh for \(station.name)")
        isLoading = true
        hasError = false
        lastRefreshTime = Date()
        loadAttempts = 0
        
        startLoadingTimeout()
        
        let newHTML = radarHTML
        webView?.loadHTMLString(newHTML, baseURL: URL(string: "https://embed.windy.com"))
        
        radarRefreshManager.triggerRefresh(for: station.macAddress)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isRefreshing = false
        }
    }
    
    private func autoRefreshRadar() {
        guard !isRefreshing && !isLoading else { 
            print("🔄 Skipping auto-refresh - already refreshing or loading")
            return 
        }
        
        print("🔄 Auto radar refresh for \(station.name) - lightweight iframe refresh")
        
        webView?.evaluateJavaScript("refreshRadarIframe()") { result, error in
            if let error = error {
                print("⚠️ Auto-refresh JavaScript error: \(error.localizedDescription)")
            } else {
                print("✅ Auto-refresh iframe updated successfully")
            }
        }
        
        lastRefreshTime = Date()
    }
    
    private func startLoadingTimeout() {
        stopLoadingTimeout()
        
        loadingTimeoutTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: false) { _ in
            DispatchQueue.main.async {
                if self.isLoading {
                    print("⚠️ Radar loading timeout after 8s - forcing clear")
                    self.isLoading = false
                }
            }
        }
    }
    
    private func stopLoadingTimeout() {
        loadingTimeoutTimer?.invalidate()
        loadingTimeoutTimer = nil
    }
    
    private func timeUntilNextRefresh() -> String {
        let _ = refreshTrigger
        return radarRefreshManager.getTimeRemainingString(for: station.macAddress)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func openFullRadar() {
        guard let latitude = station.latitude, let longitude = station.longitude else {
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
        
        configuration.userContentController.add(context.coordinator, name: "radarLoaded")
        
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
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
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
            print("Radar WebView didFinish navigation - waiting for iframe load signal...")
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
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "radarLoaded" {
                DispatchQueue.main.async {
                    self.parent.isLoading = false
                    self.parent.hasError = false
                    print("✅ Radar iframe load confirmed by JavaScript")
                }
            }
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