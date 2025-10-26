//
//  CameraTileView.swift
//  Weather Station App
//
//  Created by Curtis Netterville on 10/25/25.
//

import SwiftUI

struct CameraTileView: View {
    let station: WeatherStation
    let onTitleChange: (String) -> Void
    
    @StateObject private var weatherService = WeatherStationService.shared
    @State private var cameraImageURL: String?
    @State private var isLoadingImage = false
    @State private var lastUpdated: Date?
    @State private var imageTimestamp: String?
    @State private var showingFullScreen = false
    
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
    @State private var displaySize: CGSize = CGSize(width: 600, height: 400)
    @State private var hasCalculatedSize = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                AsyncImage(url: URL(string: imageURL)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .background(
                                GeometryReader { geometry in
                                    Color.clear
                                        .onAppear {
                                            if !hasCalculatedSize {
                                                updateDisplaySize(for: geometry.size)
                                                hasCalculatedSize = true
                                            }
                                        }
                                        .onChange(of: geometry.size) { _, newSize in
                                            updateDisplaySize(for: newSize)
                                        }
                                }
                            )
                            
                    case .failure(_):
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 48))
                                .foregroundColor(.white)
                            
                            Text("Failed to load image")
                                .foregroundColor(.white)
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        
                    case .empty:
                        VStack(spacing: 16) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)
                            
                            Text("Loading camera image...")
                                .foregroundColor(.white)
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        
                    @unknown default:
                        EmptyView()
                    }
                }
            }
            .navigationTitle("Camera - \(stationName)")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button("Save Image") {
                        saveImage()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .frame(width: displaySize.width, height: displaySize.height)
        .background(Color.black)
        .animation(.easeInOut(duration: 0.3), value: displaySize)
    }
    
    private func updateDisplaySize(for imageSize: CGSize) {
        // Only update if we have a meaningful image size
        guard imageSize.width > 50 && imageSize.height > 50 else { return }
        
        let navigationHeight: CGFloat = 100
        let padding: CGFloat = 40
        let maxWidth: CGFloat = NSScreen.main?.frame.width ?? 1200
        let maxHeight: CGFloat = NSScreen.main?.frame.height ?? 800
        let minWidth: CGFloat = 500
        let minHeight: CGFloat = 350
        
        // Calculate proposed size with padding for UI elements
        let proposedWidth = min(max(imageSize.width + padding, minWidth), maxWidth * 0.9)
        let proposedHeight = min(max(imageSize.height + navigationHeight, minHeight), maxHeight * 0.9)
        
        let newSize = CGSize(width: proposedWidth, height: proposedHeight)
        
        // Only update if the size changed significantly
        if abs(newSize.width - displaySize.width) > 20 || abs(newSize.height - displaySize.height) > 20 {
            displaySize = newSize
        }
    }
    
    private func saveImage() {
        print("Save image functionality would be implemented here")
    }
}

#Preview {
    CameraTileView(station: WeatherStation(name: "Test Camera", macAddress: "00:00:00:00:00:00")) { _ in }
}