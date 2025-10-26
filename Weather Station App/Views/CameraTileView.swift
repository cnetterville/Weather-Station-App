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
                    stationName: station.name,
                    imageTimestamp: imageTimestamp
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
    let imageTimestamp: String?
    
    @Environment(\.dismiss) private var dismiss
    @State private var imageSize: CGSize = .zero
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    Color.black.ignoresSafeArea()
                    
                    ScrollView([.horizontal, .vertical]) {
                        AsyncImage(url: URL(string: imageURL)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: geometry.size.width - 40, maxHeight: geometry.size.height - 120) // Account for navigation and padding
                                .background(
                                    GeometryReader { imageGeometry in
                                        Color.clear.onAppear {
                                            imageSize = imageGeometry.size
                                        }
                                    }
                                )
                        } placeholder: {
                            VStack(spacing: 16) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.5)
                                
                                Text("Loading camera image...")
                                    .foregroundColor(.white)
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    .scrollIndicators(.hidden)
                    
                    // Image info overlay
                    VStack {
                        Spacer()
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(stationName)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.black.opacity(0.5))
                                    .cornerRadius(4)
                                
                                Text(imageTimestamp ?? formatCurrentTimestamp())
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.black.opacity(0.5))
                                    .cornerRadius(4)
                            }
                            Spacer()
                        }
                        .padding()
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
        .frame(minWidth: 600, minHeight: 400) // Reasonable minimum size for macOS
        .background(Color.black)
    }
    
    private func formatCurrentTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: Date())
    }
    
    private func saveImage() {
        // Implementation to save image to Photos library
        // Would need to request photo library permissions first
        print("Save image functionality would be implemented here")
    }
}

#Preview {
    CameraTileView(station: WeatherStation(name: "Test Camera", macAddress: "00:00:00:00:00:00")) { _ in }
}