//
//  CameraTileView.swift
//  Weather Station App
//
//  Created by Curtis Netterville on 10/25/25.
//

import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct CameraTileView: View {
    let station: WeatherStation
    let onTitleChange: (String) -> Void
    
    @StateObject private var weatherService = WeatherStationService.shared
    @State private var cameraImageURL: String?
    @State private var isLoadingImage = false
    @State private var photoTimestamp: Date?
    @State private var lastUpdated: Date?
    @State private var refreshTimer: Timer?
    
    var body: some View {
        EditableWeatherCard(
            title: .constant(station.customLabels.camera),
            systemImage: "camera.fill",
            onTitleChange: onTitleChange
        ) {
            VStack(spacing: 8) {
                if isLoadingImage {
                    VStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading camera image...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxHeight: .infinity)
                } else if let imageURL = cameraImageURL {
                    // Camera Image - flexible height
                    AsyncImage(url: URL(string: imageURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 240)
                            .clipped()
                            .cornerRadius(8)
                            .onTapGesture {
                                openFullScreenWindow(imageURL: imageURL)
                            }
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 240)
                            .cornerRadius(8)
                            .overlay(
                                VStack {
                                    Image(systemName: "photo")
                                        .font(.system(size: 24))
                                        .foregroundColor(.gray)
                                    Text("Loading...")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            )
                    }
                    
                    // Timestamp info
                    VStack(alignment: .trailing, spacing: 4) {
                        if let photoTime = photoTimestamp {
                            HStack(spacing: 4) {
                                Spacer()
                                Text("Photo:")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text(formatTimestamp(photoTime))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if let updated = lastUpdated {
                            HStack(spacing: 4) {
                                Spacer()
                                Text("Updated:")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text(formatTimestamp(updated))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.top, 4)
                    
                    // Action buttons
                    HStack(spacing: 8) {
                        Button("Refresh") {
                            refreshCameraImage()
                            resetRefreshTimer()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                        .disabled(isLoadingImage)
                        
                        Spacer()
                        
                        Button("View Full") {
                            openFullScreenWindow(imageURL: imageURL)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.mini)
                    }
                    .padding(.top, 4)
                } else {
                    // No camera available - centered content
                    VStack(spacing: 12) {
                        Image(systemName: "camera")
                            .font(.system(size: 32))
                            .foregroundColor(.secondary)
                        Text("Camera Not Available")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("No camera data found for this device")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Try Again") {
                            refreshCameraImage()
                            resetRefreshTimer()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .onAppear {
            refreshCameraImage()
            startRefreshTimer()
        }
        .onDisappear {
            stopRefreshTimer()
        }
    }
    
    private func openFullScreenWindow(imageURL: String) {
        let hostingController = NSHostingController(rootView: FullScreenCameraView(
            imageURL: imageURL,
            stationName: station.name,
            photoTimestamp: photoTimestamp,
            lastUpdated: lastUpdated
        ))
        
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Camera - \(station.name)"
        window.styleMask = [.titled, .closable, .resizable, .fullSizeContentView]
        window.backgroundColor = .black
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        
        // Make it large and centered
        if let screen = NSScreen.main {
            let size = NSSize(width: screen.frame.width * 0.6, height: screen.frame.height * 0.6)
            window.setContentSize(size)
            window.center()
        }
        
        window.makeKeyAndOrderFront(nil)
    }
    
    private func refreshCameraImage() {
        isLoadingImage = true
        
        Task {
            let result = await weatherService.fetchCameraImage(for: station)
            
            await MainActor.run {
                isLoadingImage = false
                if let result = result {
                    cameraImageURL = result.imageURL
                    photoTimestamp = result.photoTime
                    lastUpdated = result.updatedTime
                } else {
                    cameraImageURL = nil
                    photoTimestamp = nil
                    lastUpdated = nil
                }
            }
        }
    }
    
    private func startRefreshTimer() {
        stopRefreshTimer() // Stop any existing timer
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
            refreshCameraImage()
        }
    }
    
    private func stopRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    private func resetRefreshTimer() {
        startRefreshTimer() // This will stop the existing timer and start a new one
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        formatter.timeZone = station.timeZone
        return formatter.string(from: date)
    }
}

struct FullScreenCameraView: View {
    let imageURL: String
    let stationName: String
    let photoTimestamp: Date?
    let lastUpdated: Date?
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Black background
            Color.black
                .ignoresSafeArea(.all)
            
            // Image content - full screen
            AsyncImage(url: URL(string: imageURL)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .ignoresSafeArea(.all)
                        
                case .failure(_):
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(.white)
                        
                        Text("Failed to load image")
                            .foregroundColor(.white)
                            .font(.headline)
                    }
                    
                case .empty:
                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                        
                        Text("Loading camera image...")
                            .foregroundColor(.white)
                            .font(.headline)
                    }
                    
                @unknown default:
                    EmptyView()
                }
            }
            
            // Overlay navigation bar
            VStack {
                HStack {
                    Button("Done") {
                        NSApplication.shared.keyWindow?.close()
                    }
                    .foregroundColor(.white)
                    .font(.system(size: 17, weight: .medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(8)
                    
                    Spacer()
                    
                    VStack(spacing: 4) {
                        Text("Camera - \(stationName)")
                            .foregroundColor(.white)
                            .font(.headline)
                        
                        if let photoTime = photoTimestamp {
                            Text("Photo: \(formatTimestamp(photoTime))")
                                .foregroundColor(.white.opacity(0.8))
                                .font(.caption)
                        }
                        
                        if let updated = lastUpdated {
                            Text("Updated: \(formatTimestamp(updated))")
                                .foregroundColor(.white.opacity(0.8))
                                .font(.caption)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(8)
                    
                    Spacer()
                    
                    Button("Save Image") {
                        saveImage()
                    }
                    .foregroundColor(.blue)
                    .font(.system(size: 17, weight: .medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(8)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                Spacer()
            }
        }
    }
    
    private func saveImage() {
        // Save image functionality
        guard let url = URL(string: imageURL) else { return }
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if NSImage(data: data) != nil {
                    let savePanel = NSSavePanel()
                    savePanel.allowedContentTypes = [UTType.jpeg, UTType.png]
                    savePanel.nameFieldStringValue = "\(stationName)_camera_\(DateFormatter.filename.string(from: Date()))"
                    
                    let response = await savePanel.begin()
                    if response == .OK, let saveURL = savePanel.url {
                        try data.write(to: saveURL)
                    }
                }
            } catch {
                print("Failed to save image: \(error)")
            }
        }
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Extensions
extension DateFormatter {
    static let filename: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter
    }()
}

#Preview {
    CameraTileView(station: WeatherStation(name: "Test Camera", macAddress: "00:00:00:00:00:00")) { _ in }
}