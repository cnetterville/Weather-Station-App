//
//  CameraTileView.swift
//  Weather Station App
//
//  Created by Curtis Netterville on 10/25/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct CameraTileView: View {
    let station: WeatherStation
    let onTitleChange: (String) -> Void
    
    @StateObject private var weatherService = WeatherStationService.shared
    @State private var cameraImageURL: String?
    @State private var isLoadingImage = false
    @State private var lastUpdated: Date?
    @State private var imageTimestamp: String?
    @State private var showingFullScreen = false
    @State private var refreshTimer: Timer?
    
    var body: some View {
        EditableWeatherCard(
            title: .constant(station.customLabels.camera),
            systemImage: "camera.fill",
            onTitleChange: onTitleChange
        ) {
            VStack(spacing: 12) {
                if isLoadingImage {
                    VStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading camera image...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(height: 120)
                } else if let imageURL = cameraImageURL {
                    // Camera Image
                    AsyncImage(url: URL(string: imageURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 120)
                            .clipped()
                            .cornerRadius(8)
                            .onTapGesture {
                                showingFullScreen = true
                            }
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 120)
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
                    
                    // Image info
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Latest Image")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if let lastUpdated = lastUpdated {
                                Text(lastUpdated, style: .time)
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                        }
                        
                        Spacer()
                        
                        Button("Refresh") {
                            refreshCameraImage()
                            resetRefreshTimer()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                        .disabled(isLoadingImage)
                        
                        Button("View Full") {
                            showingFullScreen = true
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.mini)
                    }
                } else {
                    // No camera image available
                    VStack(spacing: 8) {
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
                    .frame(height: 120)
                }
            }
        }
        .sheet(isPresented: $showingFullScreen) {
            if let imageURL = cameraImageURL {
                FullScreenCameraView(
                    imageURL: imageURL, 
                    stationName: station.name
                )
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
    
    private func refreshCameraImage() {
        isLoadingImage = true
        
        Task {
            let imageURL = await weatherService.fetchCameraImage(for: station)
            
            await MainActor.run {
                isLoadingImage = false
                cameraImageURL = imageURL
                if imageURL != nil {
                    lastUpdated = Date()
                    // For now, use current timestamp. Could be enhanced to extract from camera API response
                    imageTimestamp = formatCurrentTimestamp()
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
    
    private func formatCurrentTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: Date())
    }
}

struct FullScreenCameraView: View {
    let imageURL: String
    let stationName: String
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Black background
            Color.black
                .ignoresSafeArea()
            
            // Main content
            VStack {
                // Navigation bar
                HStack {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text("Camera - \(stationName)")
                        .foregroundColor(.white)
                        .font(.headline)
                    
                    Spacer()
                    
                    Button("Save Image") {
                        saveImage()
                    }
                    .foregroundColor(.blue)
                }
                .padding()
                
                // Image content
                AsyncImage(url: URL(string: imageURL)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            
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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    private func saveImage() {
        // Save image functionality
        guard let url = URL(string: imageURL) else { return }
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let nsImage = NSImage(data: data) {
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